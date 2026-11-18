import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chat themes — Vocle's own clinical look (beta feedback: "unique,
/// medical, not WhatsApp"). Three curated themes, each tuned for BOTH light
/// and dark (the old Mint / Sky / Sand / Blush were dropped: they clashed in
/// dark mode). Saved ids of removed themes fall back to [clinical].
enum ChatWallpaper {
  /// Cool case-sheet canvas with faint ECG traces.
  clinical('doodle', 'Clinical', Color(0xFFEDF2F5), Color(0xFF0D1317),
      Color(0xFF0D1B3E), Color(0xFF0F4C5C)),

  /// Theatre-scrubs green, no pattern.
  scrubs('scrubs', 'Scrubs', Color(0xFFE4F0EC), Color(0xFF0D1A18),
      Color(0xFF0F5E54), Color(0xFF125A50)),

  /// Quiet neutral, no pattern.
  plain('plain', 'Plain', Color(0xFFF4F6F8), Color(0xFF0F1113),
      Color(0xFF0D1B3E), Color(0xFF0F4C5C));

  const ChatWallpaper(this.id, this.label, this.light, this.dark,
      this.bubbleLight, this.bubbleDark);

  /// Kept as the original ids so saved choices survive the update.
  static const ChatWallpaper doodle = ChatWallpaper.clinical;

  final String id;
  final String label;
  final Color light;
  final Color dark;
  final Color bubbleLight;
  final Color bubbleDark;

  Color get color => AppColors.isDark ? dark : light;
  Color get mineBubble => AppColors.isDark ? bubbleDark : bubbleLight;
  bool get hasDoodle => this == ChatWallpaper.clinical;

  static ChatWallpaper fromId(String? id) => ChatWallpaper.values
      .firstWhere((w) => w.id == id, orElse: () => ChatWallpaper.clinical);
}
/// Saved themes: one for all chats plus optional per-chat overrides.
class ChatWallpaperStore {
  ChatWallpaperStore._();
  static final ChatWallpaperStore instance = ChatWallpaperStore._();

  static const _key = 'chat_wallpaper_v1';
  static const _perChatKey = 'chat_theme_per_chat_v1';

  /// Theme for all chats.
  final ValueNotifier<ChatWallpaper> current =
      ValueNotifier(ChatWallpaper.clinical);

  /// channelId → theme id. Notifies on any change.
  final ValueNotifier<Map<String, String>> perChat = ValueNotifier(const {});
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      current.value = ChatWallpaper.fromId(prefs.getString(_key));
      final raw = prefs.getString(_perChatKey);
      if (raw != null) {
        perChat.value = Map<String, String>.from(jsonDecode(raw) as Map);
      }
    } catch (_) {
      // Keep defaults.
    }
  }

  ChatWallpaper resolve(String? channelId) {
    final id = channelId == null ? null : perChat.value[channelId];
    return id == null ? current.value : ChatWallpaper.fromId(id);
  }

  bool hasOverride(String? channelId) =>
      channelId != null && perChat.value.containsKey(channelId);

  /// Saves for all chats (clearing this chat's own theme, if any).
  Future<void> set(ChatWallpaper wallpaper, {String? clearChatId}) async {
    current.value = wallpaper;
    if (clearChatId != null && perChat.value.containsKey(clearChatId)) {
      perChat.value = Map.of(perChat.value)..remove(clearChatId);
    }
    await _persist();
  }

  /// Saves for one chat only.
  Future<void> setForChat(String channelId, ChatWallpaper wallpaper) async {
    perChat.value = Map.of(perChat.value)..[channelId] = wallpaper.id;
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, current.value.id);
      await prefs.setString(_perChatKey, jsonEncode(perChat.value));
    } catch (_) {
      // Applied for this session even if it could not be saved.
    }
  }

  @visibleForTesting
  void resetForTest() {
    _loaded = false;
    current.value = ChatWallpaper.clinical;
    perChat.value = const {};
  }
}

/// Gives bubbles inside a chat the theme's own-bubble colour.
class ChatThemeScope extends InheritedWidget {
  const ChatThemeScope({required this.theme, required super.child, super.key});

  final ChatWallpaper theme;

  static Color? mineBubbleOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ChatThemeScope>()
      ?.theme
      .mineBubble;

  @override
  bool updateShouldNotify(ChatThemeScope old) => old.theme != theme;
}

/// Paints the chat's theme behind its messages and themes the bubbles.
class ChatWallpaperBackground extends StatefulWidget {
  const ChatWallpaperBackground({required this.child, this.channelId, super.key});

  final Widget child;
  final String? channelId;

  @override
  State<ChatWallpaperBackground> createState() =>
      _ChatWallpaperBackgroundState();
}

class _ChatWallpaperBackgroundState extends State<ChatWallpaperBackground> {
  final _store = ChatWallpaperStore.instance;

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_store.current, _store.perChat]),
      builder: (context, child) {
        final theme = _store.resolve(widget.channelId);
        return ChatThemeScope(
          theme: theme,
          child: DecoratedBox(
            decoration: BoxDecoration(color: theme.color),
            child: theme.hasDoodle
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      RepaintBoundary(
                        child: CustomPaint(
                          painter: ChatDoodlePainter(dark: AppColors.isDark),
                        ),
                      ),
                      child!,
                    ],
                  )
                : child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Vocle's chat canvas: faint ECG traces across the page with a few
/// clinical crosses — a monitor strip, not a messenger doodle.
class ChatDoodlePainter extends CustomPainter {
  const ChatDoodlePainter({required this.dark});

  final bool dark;
  static const double _band = 132;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = dark ? const Color(0xFF2DD4BF) : const Color(0xFF0D1B3E);
    final trace = Paint()
      ..color = ink.withValues(alpha: dark ? 0.07 : 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final mark = Paint()
      ..color = ink.withValues(alpha: dark ? 0.06 : 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    var row = 0;
    for (double y = 40; y < size.height + _band; y += _band, row++) {
      // One PQRST complex every 180 px, shifted per row so it never looks tiled.
      final path = Path()..moveTo(0, y);
      final phase = (row * 67) % 180;
      for (double x = -phase.toDouble(); x < size.width + 180; x += 180) {
        path
          ..lineTo(x + 40, y)
          ..quadraticBezierTo(x + 48, y - 6, x + 56, y) // P
          ..lineTo(x + 66, y)
          ..lineTo(x + 70, y + 5) // Q
          ..lineTo(x + 76, y - 26) // R
          ..lineTo(x + 82, y + 10) // S
          ..lineTo(x + 86, y)
          ..lineTo(x + 100, y)
          ..quadraticBezierTo(x + 112, y - 10, x + 124, y) // T
          ..lineTo(x + 180, y);
      }
      canvas.drawPath(path, trace);
      // A small cross between traces, alternating sides.
      final cx = row.isEven ? size.width * 0.18 : size.width * 0.78;
      final cy = y + _band / 2;
      _cross(canvas, mark, Offset(cx, cy));
    }
  }

  void _cross(Canvas c, Paint p, Offset o) {
    const a = 3.5, b = 9.0;
    c.drawPath(
      Path()
        ..moveTo(o.dx - a, o.dy - b)
        ..lineTo(o.dx + a, o.dy - b)
        ..lineTo(o.dx + a, o.dy - a)
        ..lineTo(o.dx + b, o.dy - a)
        ..lineTo(o.dx + b, o.dy + a)
        ..lineTo(o.dx + a, o.dy + a)
        ..lineTo(o.dx + a, o.dy + b)
        ..lineTo(o.dx - a, o.dy + b)
        ..lineTo(o.dx - a, o.dy + a)
        ..lineTo(o.dx - b, o.dy + a)
        ..lineTo(o.dx - b, o.dy - a)
        ..lineTo(o.dx - a, o.dy - a)
        ..close(),
      p,
    );
  }

  @override
  bool shouldRepaint(ChatDoodlePainter old) => old.dark != dark;
}
/// "Chat theme": preview, then Save — for this chat only or all chats.
/// Nothing changes until Save is tapped.
class ChatWallpaperPage extends StatefulWidget {
  const ChatWallpaperPage({this.channelId, this.chatName, super.key});

  /// Set when opened from a chat: offers "This chat" / "All chats".
  final String? channelId;
  final String? chatName;

  static Future<void> open(
    BuildContext context, {
    String? channelId,
    String? chatName,
  }) =>
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) =>
              ChatWallpaperPage(channelId: channelId, chatName: chatName),
        ),
      );

  @override
  State<ChatWallpaperPage> createState() => _ChatWallpaperPageState();
}

class _ChatWallpaperPageState extends State<ChatWallpaperPage> {
  final _store = ChatWallpaperStore.instance;
  late ChatWallpaper _selected;
  late bool _thisChatOnly;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _selected = _store.resolve(widget.channelId);
    _thisChatOnly = _store.hasOverride(widget.channelId);
    _store.load().then((_) {
      if (!mounted) return;
      setState(() {
        _selected = _store.resolve(widget.channelId);
        _thisChatOnly = _store.hasOverride(widget.channelId);
        _ready = true;
      });
    });
  }

  Future<void> _save() async {
    final id = widget.channelId;
    if (id != null && _thisChatOnly) {
      await _store.setForChat(id, _selected);
    } else {
      await _store.set(_selected, clearChatId: id);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          id != null && _thisChatOnly
              ? 'Theme saved for this chat'
              : 'Theme saved for all chats',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final fromChat = widget.channelId != null;
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(title: const Text('Chat theme')),
      body: Column(
        children: [
          // Live preview of the selection (not applied until Save).
          Container(
            height: 190,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _selected.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_selected.hasDoodle)
                  CustomPaint(painter: ChatDoodlePainter(dark: AppColors.isDark)),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _previewBubble('Bed 7 K+ 6.1 — repeat at 2am?', false),
                      const SizedBox(height: 8),
                      _previewBubble('On it. Calcium given.', true),
                    ],
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 14,
                  child: Text(
                    'Preview',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
              children: [
                for (final w in ChatWallpaper.values)
                  _ThemeTile(
                    theme: w,
                    selected: w == _selected,
                    onTap: () => setState(() => _selected = w),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (fromChat)
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: true,
                          label: Text(
                            widget.chatName == null
                                ? 'This chat'
                                : 'This chat only',
                          ),
                          icon: const Icon(Icons.chat_bubble_outline),
                        ),
                        const ButtonSegment(
                          value: false,
                          label: Text('All chats'),
                          icon: Icon(Icons.forum_outlined),
                        ),
                      ],
                      selected: {_thisChatOnly},
                      onSelectionChanged: (s) =>
                          setState(() => _thisChatOnly = s.first),
                    ),
                  if (fromChat) const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _ready ? _save : null,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewBubble(String text, bool mine) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: mine ? _selected.mineBubble : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: mine ? Colors.white : AppColors.textPrimary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final ChatWallpaper theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${theme.label} theme',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: theme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppColors.tealPrimary
                        : AppColors.borderDefault,
                    width: selected ? 2.5 : 1,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (theme.hasDoodle)
                      CustomPaint(
                        painter: ChatDoodlePainter(dark: AppColors.isDark),
                      ),
                    Center(
                      child: Container(
                        width: 34,
                        height: 18,
                        decoration: BoxDecoration(
                          color: theme.mineBubble,
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                    if (selected)
                      const Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(Icons.check_circle,
                            color: AppColors.tealPrimary, size: 18),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(theme.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
