import 'dart:async';

import 'package:flutter/material.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/members/data/repositories/member_repository.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_avatar.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_search_bar.dart';

/// Seams for tests.
typedef SearchDoctors = Future<List<UserModel>> Function(String query);
typedef LoadSuggestions = Future<List<UserModel>> Function();
typedef SubmitAdd = Future<AddMembersResult> Function(List<String> userIds);

/// WhatsApp-style "Add participants" for group admins (REQ 2).
///
/// Suggests people you already chat with, searches every Vocle doctor by
/// name, @username or number, and adds the selection in one go. New members
/// see the group's whole history; the group sees "X added Y".
class AddMembersPage extends StatefulWidget {
  const AddMembersPage({
    required this.spaceId,
    required this.existingMemberIds,
    this.spaceName,
    this.search,
    this.suggestions,
    this.submit,
    super.key,
  });

  final String spaceId;
  final String? spaceName;
  final Set<String> existingMemberIds;
  final SearchDoctors? search;
  final LoadSuggestions? suggestions;
  final SubmitAdd? submit;

  /// Returns true when anyone was added.
  static Future<bool> open(
    BuildContext context, {
    required String spaceId,
    required Set<String> existingMemberIds,
    String? spaceName,
  }) async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AddMembersPage(
          spaceId: spaceId,
          spaceName: spaceName,
          existingMemberIds: existingMemberIds,
        ),
      ),
    );
    return added == true;
  }

  @override
  State<AddMembersPage> createState() => _AddMembersPageState();
}

class _AddMembersPageState extends State<AddMembersPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;
  List<UserModel> _results = const [];
  List<UserModel> _suggested = const [];
  final Map<String, UserModel> _selected = {};
  bool _searching = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<List<UserModel>> _defaultSuggestions() async {
    final dms = await AppDependencies.instance.channelRepository.getMyDMs();
    final byId = <String, UserModel>{};
    for (final dm in dms) {
      for (final u in [if (dm.peer != null) dm.peer!, ...dm.members]) {
        if (u.id.isNotEmpty) byId.putIfAbsent(u.id, () => u);
      }
    }
    return byId.values.toList();
  }

  Future<void> _loadSuggestions() async {
    try {
      final list = await (widget.suggestions ?? _defaultSuggestions)();
      if (!mounted) return;
      setState(() => _suggested = _eligible(list));
    } catch (_) {
      // Suggestions are optional; search still works.
    }
  }

  List<UserModel> _eligible(Iterable<UserModel> users) => users
      .where((u) => !widget.existingMemberIds.contains(u.id))
      .toList();

  void _onQuery(String raw) {
    _debounce?.cancel();
    final q = raw.trim();
    if (q.length < 2) {
      _requestId++;
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final id = ++_requestId;
      setState(() {
        _searching = true;
        _error = null;
      });
      try {
        final search = widget.search ??
            (query) => AppDependencies.instance.memberRepository
                .searchMembers(query: query);
        final users = await search(q);
        if (!mounted || id != _requestId) return;
        setState(() {
          _results = _eligible(users);
          _searching = false;
        });
      } on AppException catch (e) {
        if (!mounted || id != _requestId) return;
        setState(() {
          _searching = false;
          _error = e.message;
        });
      }
    });
  }

  void _toggle(UserModel user) {
    setState(() {
      if (_selected.remove(user.id) == null) _selected[user.id] = user;
    });
  }

  Future<void> _add() async {
    if (_selected.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final submit = widget.submit ??
          (ids) => AppDependencies.instance.memberRepository
              .addMembers(spaceId: widget.spaceId, userIds: ids);
      final result = await submit(_selected.keys.toList());
      if (!mounted) return;
      final parts = <String>[
        if (result.addedNames.isNotEmpty)
          'Added ${result.addedNames.join(', ')}',
        if (result.privacySkipped.isNotEmpty)
          '${result.privacySkipped.join(', ')} only accept group adds from '
              'people they know — share the invite link',
      ];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parts.join('. '))),
      );
      Navigator.of(context).pop(result.addedNames.isNotEmpty);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    final list = query.length >= 2 ? _results : _suggested;
    final count = _selected.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(count == 0 ? 'Add members' : '$count selected'),
        actions: [
          TextButton(
            onPressed: count == 0 || _saving ? null : _add,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Add'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: AppSearchBar(
              controller: _controller,
              hintText: 'Search doctors by name, @username or number',
              onChanged: _onQuery,
              onClear: () => _onQuery(''),
            ),
          ),
          if (_searching) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                _error!,
                style: TextStyle(color: AppColors.statusError),
              ),
            ),
          if (_selected.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final u in _selected.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        avatar: AppAvatar(
                          name: u.displayName,
                          imageUrl: u.avatarUrl,
                          size: 24,
                        ),
                        label: Text(u.displayName),
                        onDeleted: () => _toggle(u),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                query.length >= 2 ? 'Doctors on Vocle' : 'People you chat with',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        query.length >= 2 && !_searching
                            ? 'No one found who is not already in the group.'
                            : 'Search for a doctor to add. New members can '
                                'read the group\'s earlier messages.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final u = list[i];
                      final selected = _selected.containsKey(u.id);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: _saving ? null : (_) => _toggle(u),
                        secondary: AppAvatar(
                          name: u.displayName,
                          imageUrl: u.avatarUrl,
                        ),
                        title: Text(u.displayName),
                        subtitle: Text(
                          [
                            if (u.vocleUsername?.isNotEmpty == true)
                              '@${u.vocleUsername}',
                            if (u.speciality?.isNotEmpty == true) u.speciality!,
                            if (u.institution?.isNotEmpty == true)
                              u.institution!,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
