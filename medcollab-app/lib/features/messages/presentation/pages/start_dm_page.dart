import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/router/dm_navigation.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';
import 'package:medcollab_app/core/utils/phone_utils.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/contacts/contact_sync_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:medcollab_app/features/messages/data/models/user_lookup_result.dart';
import 'package:medcollab_app/features/messages/presentation/utils/start_conversation.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/message_request_prompt.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/peer_profile_card.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_avatar.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_empty_state.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_search_bar.dart';
import 'package:medcollab_app/shared/presentation/widgets/clinical_card.dart';
import 'package:medcollab_app/shared/presentation/widgets/error_banner.dart';

/// Search doctors by name or phone; message requests for strangers.
class StartDmPage extends StatefulWidget {
  const StartDmPage({super.key});

  @override
  State<StartDmPage> createState() => _StartDmPageState();
}

class _StartDmPageState extends State<StartDmPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<UserModel> _nameResults = const [];
  UserLookupResult? _phoneLookup;
  bool _searching = false;
  String? _error;
  String? _busyUserId;
  String? _busyRequestId;
  final Set<String> _multiSelectIds = {};
  final Map<String, UserModel> _multiSelectUsers = {};
  List<UserModel> _suggestions = const [];
  bool _loadingSuggestions = false;
  List<ContactMatch>? _contactMatches;
  bool _syncingContacts = false;
  String? _contactsNote;

  static const _debounceDuration = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSuggestions();
      _resumeContactSync();
    });
  }

  /// Already opted in before → refresh quietly (no permission prompt).
  Future<void> _resumeContactSync() async {
    try {
      final service = AppDependencies.instance.contactSyncService;
      final cached = service.lastMatches;
      if (cached != null && mounted) {
        setState(() => _contactMatches = cached);
      }
      if (await service.hasOptedIn) await _syncContacts();
    } catch (_) {
      // Contacts are optional; search and suggestions still work.
    }
  }

  /// REQ 5: which of my phone contacts are doctors on Vocle?
  Future<void> _syncContacts() async {
    if (_syncingContacts || !mounted) return;
    setState(() {
      _syncingContacts = true;
      _contactsNote = null;
    });
    final result = await AppDependencies.instance.contactSyncService.sync();
    if (!mounted) return;
    setState(() {
      _syncingContacts = false;
      switch (result.status) {
        case ContactSyncStatus.ok:
          _contactMatches = result.matches;
          _contactsNote = result.matches.isEmpty
              ? 'None of your contacts are on Vocle yet — invite them.'
              : null;
        case ContactSyncStatus.permissionDenied:
          _contactsNote =
              'Contacts permission is off. Allow it in Settings to find colleagues.';
        case ContactSyncStatus.failed:
          _contactsNote = 'Could not check contacts. Try again.';
      }
    });
  }

  Future<void> _inviteToVocle() async {
    await Share.share(
      'I use Vocle for clinical chat and handoffs. Join me: '
      'https://medcollab.up.railway.app',
    );
  }

  Widget _contactsSection() {
    final matches = _contactMatches;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Contacts on Vocle',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
              if (matches != null)
                TextButton.icon(
                  onPressed: _syncingContacts ? null : _syncContacts,
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Refresh'),
                ),
            ],
          ),
          if (_syncingContacts) const LinearProgressIndicator(minHeight: 2),
          if (matches == null && !_syncingContacts)
            ClinicalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'See which of your phone contacts are on Vocle. Only '
                    'numbers are checked and they are not stored.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _syncContacts,
                    icon: const Icon(Icons.contacts_outlined),
                    label: const Text('Find contacts on Vocle'),
                  ),
                ],
              ),
            ),
          if (matches != null)
            for (final m in matches) _userResultTile(m.user, contactName: m.contactName),
          if (_contactsNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _contactsNote!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _inviteToVocle,
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Invite a colleague to Vocle'),
            ),
          ),
        ],
      ),
    );
  }

  /// People from your existing DMs / Needls (contacts are a separate,
  /// opt-in section — see [_syncContacts]).
  Future<void> _loadSuggestions() async {
    if (!mounted) return;
    final selfId = context.read<AuthBloc>().state.user?.id ?? '';
    setState(() => _loadingSuggestions = true);
    try {
      final dms = await AppDependencies.instance.channelRepository.getMyDMs();
      final byId = <String, UserModel>{};
      for (final dm in dms) {
        final people = <UserModel>[
          if (dm.peer != null) dm.peer!,
          ...dm.members,
        ];
        for (final u in people) {
          if (u.id == selfId || u.id.isEmpty) continue;
          byId.putIfAbsent(u.id, () => u);
        }
      }
      if (!mounted) return;
      setState(() {
        _suggestions = byId.values.toList();
        _loadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSuggestions = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool _isPhoneQuery(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return false;
    final local = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    return PhoneUtils.validateLocalNumber(local) == null;
  }

  String _phoneE164(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final local = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    return PhoneUtils.toE164(local);
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _nameResults = const [];
        _phoneLookup = null;
        _searching = false;
        _error = null;
      });
      return;
    }

    if (_isPhoneQuery(trimmed)) {
      _debounce = Timer(_debounceDuration, () => _lookupPhone(trimmed));
      return;
    }

    if (trimmed.length < 2) {
      setState(() {
        _nameResults = const [];
        _phoneLookup = null;
        _searching = false;
        _error = null;
      });
      return;
    }

    final selfUser = context.read<AuthBloc>().state.user;
    final selfId = selfUser?.id ?? '';
    _debounce = Timer(_debounceDuration, () async {
      if (!mounted) return;
      setState(() {
        _searching = true;
        _error = null;
        _phoneLookup = null;
      });
      try {
        final users = await AppDependencies.instance.memberRepository
            .searchMembers(query: trimmed);
        if (!mounted) return;
        final lower = trimmed.toLowerCase();
        final includeSelf = selfUser != null &&
            (selfUser.displayName.toLowerCase().contains(lower) ||
                (selfUser.name?.toLowerCase().contains(lower) ?? false));
        final others = users.where((u) => u.id != selfId).toList();
        setState(() {
          _nameResults = [
            if (includeSelf) selfUser,
            ...others,
          ];
          _searching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _searching = false;
          _error = 'Could not search colleagues';
        });
      }
    });
  }

  Future<void> _lookupPhone(String raw) async {
    if (!mounted) return;
    setState(() {
      _searching = true;
      _error = null;
      _nameResults = const [];
      _busyUserId = null;
      _busyRequestId = null;
    });
    try {
      final result = await AppDependencies.instance.userRepository
          .lookupByPhone(_phoneE164(raw));
      if (!mounted) return;
      setState(() {
        _phoneLookup = result;
        _searching = false;
        _error = null;
      });
    } on NotFoundException catch (e) {
      if (!mounted) return;
      setState(() {
        _phoneLookup = null;
        _searching = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phoneLookup = null;
        _searching = false;
        _error = e is AppException
            ? e.message
            : 'Could not look up this number';
      });
    }
  }

  Future<void> _startDm(UserModel user) async {
    if (_busyUserId != null) return;
    setState(() => _busyUserId = user.id);
    // REQ 11: one flow — open, or request / accept when not connected yet.
    final outcome = await startConversation(
      context,
      userId: user.id,
      peerName: user.displayName,
      replaceRoute: true,
    );
    if (!mounted || outcome == StartConversationOutcome.opened) return;
    setState(() => _busyUserId = null);
    if (outcome == StartConversationOutcome.requestSent) {
      await _refreshResults();
    }
  }

  /// Re-run whatever the doctor searched for — by number or by name (F2:
  /// a name search used to be re-run as a phone lookup and failed with
  /// "Enter a valid mobile number").
  Future<void> _refreshResults() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    if (_isPhoneQuery(query)) {
      await _lookupPhone(query);
    } else {
      _onQueryChanged(query);
    }
  }

  Future<void> _createGroupDm() async {
    if (_multiSelectIds.isEmpty) return;
    final ids = _multiSelectIds.toList();
    // Needl = 2+ other people. A single selection is always a 1:1 DM.
    if (ids.length == 1) {
      final user = _multiSelectUsers[ids.first];
      if (user != null) {
        await _startDm(user);
      }
      return;
    }
    setState(() => _busyUserId = 'group');
    try {
      final channel = await AppDependencies.instance.channelRepository
          .createGroupDm(ids);
      if (!mounted) return;
      // Guard against stale 1:1 responses if the API ever falls through.
      if (!channel.isGroupDm && channel.members.length <= 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Needl needs at least 2 other people. Select more colleagues.',
            ),
          ),
        );
        return;
      }
      openDmChat(
        context,
        channelId: channel.id,
        channel: channel,
        replace: true,
      );
    } on ForbiddenException {
      // Someone selected hasn't accepted a request from you yet: offer to
      // send requests instead of a dead end (Needl consent rule).
      if (!mounted) return;
      setState(() => _busyUserId = null);
      await _offerNeedlRequests(ids);
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create Needl')),
      );
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  /// Needl members must already chat with you (or share a group). For the
  /// ones who don't, send message requests in one go; once they accept, the
  /// Needl can be created.
  Future<void> _offerNeedlRequests(List<String> ids) async {
    final deps = AppDependencies.instance;
    final pendingNames = <String>[];
    final needRequest = <UserModel>[];
    // Check everyone at once (was one by one: ~2 s for a few people).
    final relations = await Future.wait(
      ids.map((id) => deps.userRepository
          .getRelationship(id)
          .then<UserLookupResult?>((r) => r)
          .catchError((Object _) => null)),
    );
    for (var i = 0; i < ids.length; i++) {
      final id = ids[i];
      try {
        final rel = relations[i];
        if (rel == null) continue;
        if (rel.canMessage || rel.sharesGroup) continue;
        final name = _multiSelectUsers[id]?.displayName ?? rel.user.displayName;
        if (rel.pendingRequest != null) {
          pendingNames.add(name);
        } else if (rel.canRequest) {
          needRequest.add(_multiSelectUsers[id] ?? rel.user);
        }
      } catch (_) {
        // Skip; the summary below still explains the rest.
      }
    }
    if (!mounted) return;
    if (needRequest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pendingNames.isEmpty
                ? 'Could not create the Needl. Try again.'
                : 'Waiting for ${pendingNames.join(', ')} to accept your '
                    'request — then create the Needl.',
          ),
        ),
      );
      return;
    }
    final names = needRequest.map((u) => u.displayName).join(', ');
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send message requests?'),
        content: Text(
          '$names ${needRequest.length == 1 ? 'needs' : 'need'} to accept a '
          'request before joining a Needl with you.'
          '${pendingNames.isEmpty ? '' : '\n\nAlready waiting: ${pendingNames.join(', ')}.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              needRequest.length == 1 ? 'Send request' : 'Send requests',
            ),
          ),
        ],
      ),
    );
    if (send != true || !mounted) return;
    final results = await Future.wait(needRequest.map((u) => deps
        .messageRequestRepository
        .sendRequest(toUserId: u.id, introMessage: 'Adding you to a Needl')
        .then((_) => true)
        .catchError((Object _) => false)));
    final sent = results.where((ok) => ok).length;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent == needRequest.length
              ? 'Requests sent — create the Needl once they accept'
              : 'Sent $sent of ${needRequest.length} requests',
        ),
      ),
    );
  }

  void _toggleMulti(UserModel user) {
    setState(() {
      if (_multiSelectIds.contains(user.id)) {
        _multiSelectIds.remove(user.id);
        _multiSelectUsers.remove(user.id);
      } else {
        _multiSelectIds.add(user.id);
        _multiSelectUsers[user.id] = user;
      }
    });
  }

  Future<void> _startDmOrRequest(UserModel user) async {
    await _startDm(user);
  }

  Future<void> _sendRequest(UserModel user) async {
    if (_busyUserId != null && _busyUserId != user.id) return;

    final intro = await showMessageRequestIntroDialog(
      context,
      title: 'Send message request',
      explanation: 'They will see your name and this note. Chat opens only '
          'after they accept — no Seen until then.',
      hintText: 'Optional — e.g. ICU R2 from AIIMS, need a consult',
    );
    if (intro == null || !mounted) return;

    setState(() => _busyUserId = user.id);
    try {
      await AppDependencies.instance.messageRequestRepository.sendRequest(
        toUserId: user.id,
        introMessage: intro.isEmpty ? null : intro,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request sent — waiting for them to accept'),
        ),
      );
      await _refreshResults();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  Future<void> _acceptRequest(String requestId, UserModel user) async {
    if (_busyRequestId != null) return;
    setState(() => _busyRequestId = requestId);
    try {
      final result = await AppDependencies.instance.messageRequestRepository
          .acceptRequest(requestId);
      if (!mounted) return;
      final channel = result.channel ??
          await AppDependencies.instance.channelRepository
              .createOrGetDM(user.id);
      if (!mounted) return;
      openDmChat(
        context,
        channelId: channel.id,
        channel: channel,
        replace: true,
      );
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  Widget _userSubtitle(UserModel user) {
    return Text(
      [
        if (user.vocleUsername != null && user.vocleUsername!.isNotEmpty)
          '@${user.vocleUsername}',
        user.role.label,
        if (user.speciality != null && user.speciality!.isNotEmpty)
          user.speciality!,
        if (user.institution != null && user.institution!.isNotEmpty)
          user.institution!,
      ].join(' · '),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
    );
  }

  Widget _phoneLookupCard(UserLookupResult lookup) {
    final user = lookup.user;
    final pending = lookup.pendingRequest;
    // Only treat as busy when a concrete id matches — `null == null` would
    // hide the Send request CTA for every non-pending lookup (FR-REQ-06).
    final busy = _busyUserId == user.id ||
        (pending != null &&
            _busyRequestId != null &&
            _busyRequestId == pending.id);

    Widget action;
    late final String helper;
    if (lookup.isSelf || lookup.relationship == 'self') {
      action = FilledButton(
        onPressed: busy ? null : () => _startDm(user),
        child: const Text('Open notes to self'),
      );
      helper =
          'Save personal reminders, differentials, or draft notes only you can see.';
    } else if (lookup.canMessage) {
      action = FilledButton(
        onPressed: busy ? null : () => _startDm(user),
        child: const Text('Message'),
      );
      helper = 'You already have a chat (or an accepted request) with them.';
    } else if (pending?.isReceived == true) {
      action = Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => _busyRequestId = pending!.id);
                      try {
                        await AppDependencies.instance.messageRequestRepository
                            .declineRequest(pending!.id);
                        if (!mounted) return;
                        await _lookupPhone(_searchController.text.trim());
                      } finally {
                        if (mounted) setState(() => _busyRequestId = null);
                      }
                    },
              child: const Text('Decline'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: busy
                  ? null
                  : () => _acceptRequest(pending!.id, user),
              child: const Text('Accept & chat'),
            ),
          ),
        ],
      );
      helper = 'Accept to open a private chat. Seen receipts start after this.';
    } else if (pending?.isSent == true) {
      action = const OutlinedButton(
        onPressed: null,
        child: Text('Request pending'),
      );
      helper = 'Waiting for them to accept. No chat or Seen until then.';
    } else if (lookup.canRequest || lookup.acceptsMessageRequests) {
      action = FilledButton(
        onPressed: busy ? null : () => _sendRequest(user),
        child: const Text('Send request'),
      );
      helper = lookup.sharesGroup
          ? 'You share a group, but chat still needs their approval first.'
          : 'Send a request — the chat opens when they accept.';
    } else {
      action = const OutlinedButton(
        onPressed: null,
        child: Text('Not available'),
      );
      helper = 'Messaging is not available with this doctor.';
    }

    return ClinicalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => showPeerProfileCard(context, user: user),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                AppAvatar(name: user.displayName, imageUrl: user.avatarUrl),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      _userSubtitle(user),
                      Text(
                        'Tap for profile',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.tealDark,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.info_outline, color: AppColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            helper,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
          if (pending?.introMessage?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              '"${pending!.introMessage}"',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          if (busy)
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            action,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = _searchController.text.trim();
    final showEmpty = trimmed.isEmpty ||
        (!_searching &&
            _phoneLookup == null &&
            _nameResults.isEmpty &&
            _error == null);
    // Empty query: contacts on Vocle + people you chat with (REQ 5).
    final showSuggestions = trimmed.isEmpty && !_searching;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _multiSelectIds.length >= 2
              ? 'Create Needl'
              : _multiSelectIds.isEmpty
                  ? 'Start a DM'
                  : '${_multiSelectIds.length} selected',
        ),
        backgroundColor: AppColors.background,
        actions: [
          if (_multiSelectIds.isNotEmpty)
            TextButton(
              onPressed: _busyUserId != null ? null : _createGroupDm,
              child: Text(_multiSelectIds.length >= 2 ? 'Create Needl' : 'Message'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_multiSelectIds.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              color: AppColors.surfaceCard,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _multiSelectUsers.values.map((u) {
                  final label = u.displayName.trim().isEmpty
                      ? 'Doctor'
                      : u.displayName.trim();
                  return InputChip(
                    avatar: AppAvatar(
                      name: label,
                      imageUrl: u.avatarUrl,
                      size: 24,
                    ),
                    label: Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    deleteIconColor: AppColors.textSecondary,
                    onDeleted: () => _toggleMulti(u),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppSearchBar(
              controller: _searchController,
              hintText: 'Search doctors by name, @username or number',
              onChanged: _onQueryChanged,
              onClear: () => _onQueryChanged(''),
            ),
          ),
          if (_searching) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: ErrorBanner(message: _error!),
            ),
          Expanded(
            child: showSuggestions
                ? ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      _contactsSection(),
                      if (_suggestions.isNotEmpty) ...[
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text(
                            'People you chat with',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ),
                        ..._suggestions.map(_userResultTile),
                      ] else if (_loadingSuggestions)
                        const Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else
                        Text(
                          'Search any doctor on Vocle by name, @username or '
                          'mobile number. The chat opens when they accept '
                          'your request.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                        ),
                    ],
                  )
                : showEmpty
                    ? AppEmptyState(
                        icon: Icons.person_search_outlined,
                        title: trimmed.isEmpty
                            ? 'Find a colleague'
                            : 'No results',
                        subtitle: trimmed.isEmpty
                            ? (_loadingSuggestions
                                ? 'Loading your Vocle colleagues...'
                                : 'Search Vocle colleagues by name or enter a '
                                    '10-digit mobile number. Outside your '
                                    'network, they must accept a request '
                                    'before chat opens.')
                            : _isPhoneQuery(trimmed)
                                ? 'This number is not on Vocle yet, or the '
                                    'doctor has not completed setup.'
                                : 'Try a full name, or search by mobile number.',
                      )
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        children: [
                          if (_phoneLookup != null)
                            _phoneLookupCard(_phoneLookup!)
                          else
                            ..._nameResults.map(_userResultTile),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  /// Search / suggestion row. While any colleague is selected, the primary
  /// tap toggles the checkbox; the chat icon always opens a 1:1 DM.
  Widget _userResultTile(UserModel user, {String? contactName}) {
    final busy = _busyUserId == user.id;
    final selected = _multiSelectIds.contains(user.id);
    final multiMode = _multiSelectIds.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ClinicalCard(
        onTap: busy
            ? null
            : multiMode
                ? () => _toggleMulti(user)
                : () => showPeerProfileCard(context, user: user),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (_) => _toggleMulti(user),
            ),
            AppAvatar(
              name: user.displayName,
              imageUrl: user.avatarUrl,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  _userSubtitle(user),
                  if (contactName != null &&
                      contactName.trim().isNotEmpty &&
                      contactName.trim() != user.displayName)
                    Text(
                      'In your contacts as $contactName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.tealDark,
                          ),
                    ),
                  Text(
                    selected
                        ? 'Selected for Needl'
                        : multiMode
                            ? 'Tap to add to Needl'
                            : 'Tap profile \u00b7 Message needs approval if new',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (!multiMode)
              IconButton(
                tooltip: 'Start 1:1 DM',
                onPressed: () => _startDmOrRequest(user),
                icon: const Icon(Icons.chat_outlined),
              ),
          ],
        ),
      ),
    );
  }
}
