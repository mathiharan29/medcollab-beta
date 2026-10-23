import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/presence/presence_cubit.dart';
import 'package:medcollab_app/core/router/dm_navigation.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/core/utils/phone_utils.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/peer_profile_card.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_avatar.dart';

/// Slack-style add-people flow for a Needl / group DM.
Future<void> showAddNeedlPeopleSheet(
  BuildContext context, {
  required ChannelModel channel,
  required List<UserModel> existingMembers,
}) async {
  final selected = <String, UserModel>{};
  var history = 'all';
  var busy = false;
  String? error;
  String? searchError;
  var query = '';
  var results = <UserModel>[];
  var suggestions = <UserModel>[];
  var loadingSuggestions = true;
  var searching = false;
  var searchSeq = 0;
  var sheetOpen = true;
  Timer? debounce;
  StateSetter? modalSetState;

  final existingIds = existingMembers.map((m) => m.id).toSet();
  final selfId = context.read<AuthBloc>().state.user?.id ?? '';

  void refreshModal(VoidCallback fn) {
    if (!sheetOpen) return;
    final setter = modalSetState;
    if (setter == null) {
      fn();
    } else {
      setter(fn);
    }
  }

  // Preload known colleagues from existing DMs / Needls (same source as
  // StartDmPage) so the list isn't empty before typing.
  unawaited(() async {
    try {
      final dms = await AppDependencies.instance.channelRepository.getMyDMs();
      final byId = <String, UserModel>{};
      for (final dm in dms) {
        final people = <UserModel>[
          if (dm.peer != null) dm.peer!,
          ...dm.members,
        ];
        for (final u in people) {
          if (u.id.isEmpty || u.id == selfId || existingIds.contains(u.id)) {
            continue;
          }
          byId.putIfAbsent(u.id, () => u);
        }
      }
      refreshModal(() {
        suggestions = byId.values.toList()
          ..sort(
            (a, b) => a.displayName
                .toLowerCase()
                .compareTo(b.displayName.toLowerCase()),
          );
        loadingSuggestions = false;
      });
    } catch (_) {
      refreshModal(() => loadingSuggestions = false);
    }
  }());

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surfaceCard,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setModal) {
          modalSetState = setModal;
          bool isPhoneQuery(String raw) {
            final digits = raw.replaceAll(RegExp(r'\D'), '');
            if (digits.length < 10) return false;
            final local =
                digits.length > 10 ? digits.substring(digits.length - 10) : digits;
            return PhoneUtils.validateLocalNumber(local) == null;
          }

          String phoneE164(String raw) {
            final digits = raw.replaceAll(RegExp(r'\D'), '');
            final local =
                digits.length > 10 ? digits.substring(digits.length - 10) : digits;
            return PhoneUtils.toE164(local);
          }

          Future<void> search(String raw) async {
            query = raw.trim();
            final seq = ++searchSeq;
            if (query.isEmpty) {
              // Back to suggestions from existing DMs.
              refreshModal(() {
                results = const [];
                searching = false;
                searchError = null;
              });
              return;
            }
            refreshModal(() {
              searching = true;
              searchError = null;
            });
            try {
              if (isPhoneQuery(query)) {
                final lookup = await AppDependencies.instance.userRepository
                    .lookupByPhone(phoneE164(query));
                if (seq != searchSeq) return;
                final user = lookup.user;
                refreshModal(() {
                  results = user.id.isNotEmpty &&
                          user.id != selfId &&
                          !existingIds.contains(user.id)
                      ? [user]
                      : const [];
                  searching = false;
                });
                return;
              }
              final users = await AppDependencies.instance.memberRepository
                  .searchMembers(query: query);
              if (seq != searchSeq) return;
              final lower = query.toLowerCase();
              // Known colleagues matching locally first, then server results.
              final merged = <String, UserModel>{
                for (final u in suggestions)
                  if (u.displayName.toLowerCase().contains(lower)) u.id: u,
              };
              for (final u in users) {
                if (u.id.isEmpty ||
                    u.id == selfId ||
                    existingIds.contains(u.id)) {
                  continue;
                }
                merged.putIfAbsent(u.id, () => u);
              }
              refreshModal(() {
                results = merged.values.toList();
                searching = false;
              });
            } catch (e) {
              if (seq != searchSeq) return;
              refreshModal(() {
                results = const [];
                searching = false;
                searchError = e is AppException
                    ? e.message
                    : isPhoneQuery(query)
                        ? 'Could not look up this number'
                        : 'Could not search colleagues. Try again.';
              });
            }
          }

          void onQueryChanged(String raw) {
            debounce?.cancel();
            // Reflect typing immediately (suggestions <-> results) while the
            // debounced request is pending.
            final trimmed = raw.trim();
            if (trimmed.isEmpty) {
              search(raw);
              return;
            }
            debounce = Timer(
              const Duration(milliseconds: 200),
              () => search(raw),
            );
          }

          final showSuggestions = query.isEmpty;
          final listUsers = showSuggestions ? suggestions : results;

          Future<void> submit() async {
            if (selected.isEmpty || busy) return;
            setModal(() {
              busy = true;
              error = null;
            });
            try {
              final next = await AppDependencies.instance.channelRepository
                  .expandDm(
                channelId: channel.id,
                userIds: selected.keys.toList(),
                history: history,
              );
              if (!sheetContext.mounted) return;
              Navigator.pop(sheetContext);
              openDmChat(
                sheetContext,
                channelId: next.id,
                channel: next,
                replace: true,
              );
            } on AppException catch (e) {
              setModal(() {
                busy = false;
                error = e.message;
              });
            } catch (_) {
              setModal(() {
                busy = false;
                error = 'Could not add people';
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add people to Needl',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Name or mobile number',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: onQueryChanged,
                  ),
                  if (searching)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Include chat history',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  RadioListTile<String>(
                    dense: true,
                    value: 'all',
                    groupValue: history,
                    title: const Text('Entire history'),
                    subtitle: const Text('New Needl with full past thread'),
                    onChanged: (v) => setModal(() => history = v ?? 'all'),
                  ),
                  RadioListTile<String>(
                    dense: true,
                    value: 'today',
                    groupValue: history,
                    title: const Text('From today'),
                    subtitle: const Text('New Needl with today’s messages only'),
                    onChanged: (v) => setModal(() => history = v ?? 'today'),
                  ),
                  RadioListTile<String>(
                    dense: true,
                    value: 'none',
                    groupValue: history,
                    title: const Text('No history'),
                    subtitle: const Text('Fresh Needl with everyone included'),
                    onChanged: (v) => setModal(() => history = v ?? 'none'),
                  ),
                  if (selected.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: selected.values
                          .map(
                            (u) => InputChip(
                              avatar: AppAvatar(
                                name: u.displayName,
                                imageUrl: u.avatarUrl,
                                size: 22,
                              ),
                              label: Text(
                                u.displayName,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: AppColors.surfaceInput,
                              deleteIconColor: AppColors.textSecondary,
                              side: const BorderSide(
                                color: AppColors.borderDefault,
                              ),
                              onDeleted: () => setModal(() {
                                selected.remove(u.id);
                              }),
                            ),
                          )
                          .toList(),
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error!,
                        style: const TextStyle(color: AppColors.statusError),
                      ),
                    ),
                  if (searchError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        searchError!,
                        style: const TextStyle(color: AppColors.statusError),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (showSuggestions && suggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Your Vocle colleagues',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Expanded(
                    child: listUsers.isEmpty
                        ? Center(
                            child: Text(
                              showSuggestions
                                  ? (loadingSuggestions
                                      ? 'Loading your colleagues…'
                                      : 'Search by name or 10-digit mobile number')
                                  : (searching || searchError != null
                                      ? ''
                                      : 'No colleagues found'),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          )
                        : ListView.builder(
                      itemCount: listUsers.length,
                      itemBuilder: (context, index) {
                        final user = listUsers[index];
                        final isOn = selected.containsKey(user.id);
                        return CheckboxListTile(
                          value: isOn,
                          secondary: AppAvatar(
                            name: user.displayName,
                            imageUrl: user.avatarUrl,
                          ),
                          title: Text(user.displayName),
                          onChanged: (_) => setModal(() {
                            if (isOn) {
                              selected.remove(user.id);
                            } else {
                              selected[user.id] = user;
                            }
                          }),
                        );
                      },
                    ),
                  ),
                  FilledButton(
                    onPressed: busy || selected.isEmpty ? null : submit,
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add to Needl'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  sheetOpen = false;
  debounce?.cancel();
}

/// Lists everyone in a Needl (group DM).
Future<void> showNeedlMembersSheet(
  BuildContext context, {
  required List<UserModel> members,
  required String title,
}) async {
  final selfId = context.read<AuthBloc>().state.user?.id ?? '';
  final sorted = List<UserModel>.of(members)
    ..sort((a, b) {
      if (a.id == selfId) return -1;
      if (b.id == selfId) return 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surfaceCard,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'People in this Needl',
                      style: AppTextStyles.cardTitle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$title · ${sorted.length} people',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: MediaQuery.sizeOf(sheetContext).height * 0.55,
                child: ListView.separated(
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = sorted[index];
                    final isSelf = user.id == selfId;
                    final online = context
                            .watch<PresenceCubit>()
                            .state[user.id]
                            ?.isOnline ??
                        false;
                    return ListTile(
                      leading: AppAvatar(
                        name: user.displayName,
                        imageUrl: user.avatarUrl,
                        showPresence: true,
                        isOnline: online,
                      ),
                      title: Text(
                        isSelf ? '${user.displayName} (you)' : user.displayName,
                      ),
                      subtitle: Text(
                        [
                          if (user.role.label.isNotEmpty) user.role.label,
                          if (user.speciality?.isNotEmpty == true)
                            user.speciality!,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: isSelf
                          ? null
                          : () async {
                              Navigator.pop(sheetContext);
                              try {
                                final fresh = await AppDependencies
                                    .instance.memberRepository
                                    .getUserById(user.id);
                                if (!context.mounted) return;
                                await showPeerProfileCard(context, user: fresh);
                              } catch (_) {
                                if (!context.mounted) return;
                                await showPeerProfileCard(context, user: user);
                              }
                            },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showRenameNeedlDialog(
  BuildContext context, {
  required String channelId,
  required String currentName,
}) async {
  final controller = TextEditingController(text: currentName);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Rename Needl'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 80,
        decoration: const InputDecoration(
          hintText: 'e.g. Bed 12 / ICU night',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (name == null || !context.mounted) return;
  try {
    await AppDependencies.instance.channelRepository
        .renameChannel(channelId, name);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Needl renamed')),
    );
  } on AppException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)),
    );
  }
}
