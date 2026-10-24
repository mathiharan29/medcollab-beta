import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/router/dm_navigation.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/search/data/repositories/search_repository.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_empty_state.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_search_bar.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_skeleton.dart';
import 'package:medcollab_app/shared/presentation/widgets/clinical_card.dart';

/// Global search with a stable text field (results update without rebuilding the field).
class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _loading = ValueNotifier<bool>(false);
  final _results = ValueNotifier<GlobalSearchResult?>(null);
  final _query = ValueNotifier<String>('');
  final _error = ValueNotifier<String?>(null);
  Timer? _debounce;
  int _requestId = 0;
  String? _openingDoctorId;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _loading.dispose();
    _results.dispose();
    _query.dispose();
    _error.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    final trimmed = query.trim();
    _query.value = trimmed;
    _debounce?.cancel();

    if (trimmed.isEmpty) {
      _requestId++; // drop any in-flight response
      _loading.value = false;
      _results.value = null;
      _error.value = null;
      return;
    }

    // Short pause so we don't fire on every keystroke, but still feel instant.
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      final id = ++_requestId;
      _loading.value = true;
      _error.value = null;
      try {
        final result = await AppDependencies.instance.searchRepository
            .search(query: trimmed);
        if (!mounted || id != _requestId) return;
        _results.value = result;
        _error.value = null;
      } catch (_) {
        if (!mounted || id != _requestId) return;
        _error.value = 'Could not search. Check your connection and try again.';
      } finally {
        if (mounted && id == _requestId) {
          _loading.value = false;
        }
      }
    });
  }

  Future<void> _openDoctor(UserModel doctor) async {
    if (_openingDoctorId != null) return;
    setState(() => _openingDoctorId = doctor.id);
    try {
      final channel = await AppDependencies.instance.channelRepository
          .createOrGetDM(doctor.id);
      if (!mounted) return;
      openDmChat(
        context,
        channelId: channel.id,
        channel: channel,
        replace: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _openingDoctorId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not start conversation — you can only message known colleagues',
          ),
        ),
      );
    }
  }

  void _openChannelHit({required String channelId, String? spaceId}) async {
    if (spaceId == null || spaceId.isEmpty) {
      try {
        final detail = await AppDependencies.instance.channelRepository
            .getChannelById(channelId);
        if (!mounted) return;
        openDmChat(
          context,
          channelId: channelId,
          channel: detail.channel,
          replace: true,
        );
      } catch (_) {
        if (!mounted) return;
        openDmChat(context, channelId: channelId, replace: true);
      }
    } else {
      context.push(AppRoutes.channelPath(spaceId, channelId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selfId = context.read<AuthBloc>().state.user?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppSearchBar(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              hintText: 'Messages, doctors, handoffs, channels…',
              onChanged: _onQueryChanged,
              onClear: () => _onQueryChanged(''),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _loading,
            builder: (context, loading, _) {
              return SizedBox(
                height: 2,
                child: loading
                    ? const LinearProgressIndicator(minHeight: 2)
                    : const SizedBox.shrink(),
              );
            },
          ),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: _query,
              builder: (context, query, _) {
                return ValueListenableBuilder<String?>(
                  valueListenable: _error,
                  builder: (context, error, _) {
                return ValueListenableBuilder<GlobalSearchResult?>(
                  valueListenable: _results,
                  builder: (context, results, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _loading,
                      builder: (context, loading, _) {
                        if (query.isEmpty) {
                          return AppEmptyState(
                            compact: true,
                            icon: Icons.search,
                            title: 'Search your workspace',
                            subtitle:
                                'Find messages, colleagues, channels, handoffs, '
                                'and attachments across your groups.',
                          );
                        }

                        if (error != null && !loading) {
                          return AppEmptyState(
                            compact: true,
                            icon: Icons.error_outline,
                            title: 'Could not search',
                            subtitle: error,
                          );
                        }

                        if (results == null && loading) {
                          return const Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: AppListSkeleton(itemCount: 6),
                          );
                        }

                        if (results == null || results.isEmpty) {
                          return AppEmptyState(
                            compact: true,
                            icon: Icons.search_off_outlined,
                            title: 'No results',
                            subtitle:
                                'Try a shorter term, a colleague name, or a '
                                'channel like #general.',
                          );
                        }

                        final doctors = results.doctors
                            .where((d) => d.id.isNotEmpty && d.id != selfId)
                            .toList();

                        return ListView(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          children: [
                            if (results.messages.isNotEmpty) ...[
                              const _SectionTitle('Messages'),
                              ...results.messages.map(
                                (m) => _ResultTile(
                                  title: m.text.isNotEmpty ? m.text : 'Message',
                                  subtitle: [
                                    m.sender?.displayName,
                                    m.channelName,
                                  ]
                                      .whereType<String>()
                                      .where((s) => s.isNotEmpty)
                                      .join(' · '),
                                  onTap: () => _openChannelHit(
                                    channelId: m.channelId,
                                    spaceId: m.spaceId,
                                  ),
                                ),
                              ),
                            ],
                            if (doctors.isNotEmpty) ...[
                              const _SectionTitle('Doctors'),
                              ...doctors.map(
                                (d) => _ResultTile(
                                  title: d.displayName,
                                  subtitle: [
                                    d.role.label,
                                    d.speciality,
                                  ]
                                      .whereType<String>()
                                      .where((s) => s.isNotEmpty)
                                      .join(' · '),
                                  onTap: () => _openDoctor(d),
                                ),
                              ),
                            ],
                            if (results.channels.isNotEmpty) ...[
                              const _SectionTitle('Channels'),
                              ...results.channels.map(
                                (c) => _ResultTile(
                                  title: c.name.startsWith('#')
                                      ? c.name
                                      : '#${c.name}',
                                  subtitle: c.spaceName?.isNotEmpty == true
                                      ? c.spaceName!
                                      : (c.spaceId == null
                                          ? 'Direct'
                                          : 'Group channel'),
                                  onTap: () => _openChannelHit(
                                    channelId: c.id,
                                    spaceId: c.spaceId,
                                  ),
                                ),
                              ),
                            ],
                            if (results.handoffs.isNotEmpty) ...[
                              const _SectionTitle('Handoffs'),
                              ...results.handoffs.map(
                                (h) => _ResultTile(
                                  title: h.title,
                                  subtitle: [
                                    h.spaceName,
                                    if (h.fromName != null && h.toName != null)
                                      '${h.fromName} → ${h.toName}',
                                    h.status,
                                  ]
                                      .whereType<String>()
                                      .where((s) => s.isNotEmpty)
                                      .join(' · '),
                                  onTap: () {
                                    if (h.spaceId.isEmpty) return;
                                    context.push(
                                      AppRoutes.spaceHandoffDetailPath(
                                        h.spaceId,
                                        h.id,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            if (results.attachments.isNotEmpty) ...[
                              const _SectionTitle('Attachments'),
                              ...results.attachments.map(
                                (a) => _ResultTile(
                                  title: a.fileName ??
                                      (a.text.isEmpty ? 'Attachment' : a.text),
                                  subtitle: [
                                    a.sender?.displayName,
                                    a.channelName,
                                  ]
                                      .whereType<String>()
                                      .where((s) => s.isNotEmpty)
                                      .join(' · '),
                                  onTap: () => _openChannelHit(
                                    channelId: a.channelId,
                                    spaceId: a.spaceId,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  },
                );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs, top: AppSpacing.sm),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        button: true,
        label: '$title. $subtitle',
        child: ClinicalCard(
          onTap: onTap,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            if (subtitle.isNotEmpty)
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      ),
    );
  }
}
