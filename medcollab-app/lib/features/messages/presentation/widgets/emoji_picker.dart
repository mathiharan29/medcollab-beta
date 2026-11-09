import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Emoji picker for the composer and reactions (REQ 12). No extra package:
/// a curated, tabbed set plus "Recent", which is remembered on the device.
class EmojiCatalog {
  static const categories = <(String, IconData, List<String>)>[
    ('Clinical', Icons.medical_services_outlined, [
      '👍', '🙏', '✅', '❌', '⚠️', '🚨', '🆘', '⏰', '📌', '📋', '📝', '📎',
      '💉', '🩺', '💊', '🩹', '🩸', '🧪', '🧬', '🦠', '🏥', '🚑', '🛏️', '♿',
      '🫀', '🫁', '🧠', '🦴', '🦷', '👁️', '🩻', '🌡️', '😷', '🤒', '🤕', '🤧',
      '➡️', '⬅️', '⬆️', '⬇️', '🔁', '❓', '❗', '💯', '🆗', '🆕', '🔴', '🟢',
    ]),
    ('Smileys', Icons.emoji_emotions_outlined, [
      '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '🙂', '😉', '😍',
      '🥰', '😘', '😋', '😎', '🤓', '🧐', '🤔', '🤨', '😐', '😑', '😶', '🙄',
      '😏', '😬', '😌', '😴', '🥱', '😪', '😮', '😯', '😲', '😳', '🥺', '😢',
      '😭', '😤', '😠', '😡', '🤯', '😱', '😨', '😰', '😥', '🤗', '🤭', '🫡',
    ]),
    ('Gestures', Icons.back_hand_outlined, [
      '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆', '👇',
      '☝️', '✋', '🤚', '🖐️', '🖖', '👋', '🤝', '👏', '🙌', '👐', '🤲', '🙏',
      '💪', '✍️', '🫶', '👀', '🧑‍⚕️', '👨‍⚕️', '👩‍⚕️', '🧑‍🔬', '🧑‍🎓', '🏃', '🚶', '🧘',
    ]),
    ('Symbols', Icons.favorite_border, [
      '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '💔', '❣️', '💕', '💞',
      '🔥', '⭐', '🌟', '✨', '⚡', '💥', '🎉', '🎊', '🏆', '🥇', '🎯', '📈',
      '📉', '📅', '🕐', '⌛', '☕', '🍵', '🍕', '🍔', '🌙', '☀️', '🌧️', '🔔',
    ]),
  ];

  static const _recentKey = 'emoji_recent_v1';

  static Future<List<String>> recent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_recentKey) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> remember(String emoji) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = [emoji, ...(prefs.getStringList(_recentKey) ?? const [])
          .where((e) => e != emoji)];
      await prefs.setStringList(_recentKey, list.take(24).toList());
    } catch (_) {}
  }
}

/// Bottom sheet; returns the chosen emoji or null.
Future<String?> showEmojiPickerSheet(BuildContext context) async {
  final recent = await EmojiCatalog.recent();
  if (!context.mounted) return null;
  final picked = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceCard,
    builder: (ctx) => _EmojiSheet(recent: recent),
  );
  if (picked != null) await EmojiCatalog.remember(picked);
  return picked;
}

class _EmojiSheet extends StatelessWidget {
  const _EmojiSheet({required this.recent});

  final List<String> recent;

  @override
  Widget build(BuildContext context) {
    final tabs = <(String, IconData, List<String>)>[
      if (recent.isNotEmpty) ('Recent', Icons.history, recent),
      ...EmojiCatalog.categories,
    ];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.45,
        child: DefaultTabController(
          length: tabs.length,
          child: Column(
            children: [
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.tealDark,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.tealDark,
                tabs: [
                  for (final t in tabs)
                    Tab(
                      icon: Icon(t.$2, size: 20, semanticLabel: t.$1),
                      height: 40,
                    ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final t in tabs)
                      GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 48,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                        itemCount: t.$3.length,
                        itemBuilder: (_, i) {
                          final e = t.$3[i];
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => Navigator.pop(context, e),
                            child: Center(
                              child: Text(e,
                                  style: const TextStyle(fontSize: 26)),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
