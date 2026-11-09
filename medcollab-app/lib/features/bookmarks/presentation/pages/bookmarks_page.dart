import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/storage/bookmark_service.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_empty_state.dart';
import 'package:medcollab_app/shared/presentation/widgets/clinical_card.dart';

class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  late Future<List<BookmarkItem>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = AppDependencies.instance.bookmarkService.getAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: FutureBuilder<List<BookmarkItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load bookmarks'),
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const AppEmptyState(
              icon: Icons.bookmark_outline,
              title: 'No bookmarks yet',
              subtitle: 'Save messages, threads, or handoffs for quick access.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final item = items[index];
              return ClinicalCard(
                onTap: () => _open(context, item),
                child: Row(
                  children: [
                    Icon(
                      _iconFor(item.type),
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            item.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove bookmark',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () async {
                        await AppDependencies.instance.bookmarkService
                            .remove(item.id);
                        setState(_reload);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconFor(BookmarkType type) => switch (type) {
        BookmarkType.message => Icons.chat_bubble_outline,
        BookmarkType.thread => Icons.forum_outlined,
        BookmarkType.handoff => Icons.assignment_outlined,
      };

  void _open(BuildContext context, BookmarkItem item) {
    if (item.type == BookmarkType.handoff &&
        item.handoffId != null &&
        item.spaceId != null) {
      context.push(
        AppRoutes.spaceHandoffDetailPath(item.spaceId!, item.handoffId!),
      );
    } else if (item.channelId != null && item.spaceId != null) {
      if (item.messageId != null && item.type == BookmarkType.thread) {
        context.push(
          AppRoutes.threadPath(
            item.spaceId!,
            item.channelId!,
            item.messageId!,
          ),
        );
      } else {
        context.push(
          AppRoutes.channelPath(item.spaceId!, item.channelId!),
        );
      }
    }
  }
}

/// Helper to bookmark from any screen.
Future<void> saveMessageBookmark({
  required String messageId,
  required String channelId,
  required String spaceId,
  required String title,
  required String subtitle,
  BookmarkType type = BookmarkType.message,
}) {
  return AppDependencies.instance.bookmarkService.save(
    BookmarkItem(
      id: 'msg-$messageId',
      type: type,
      title: title,
      subtitle: subtitle,
      savedAt: DateTime.now(),
      spaceId: spaceId,
      channelId: channelId,
      messageId: messageId,
    ),
  );
}
