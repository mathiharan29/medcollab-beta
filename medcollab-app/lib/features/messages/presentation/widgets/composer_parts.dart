import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';

/// One set of measurements for every chat input bar (text composer, thread
/// reply, voice recording) so icons line up the way they do in WhatsApp /
/// Telegram (beta 11-14, issue 4). Previously attach 26 px in a 44 box,
/// emoji 22 px in a ~40 box and send 44 px nudged up 2 px — visibly uneven.
abstract final class ComposerMetrics {
  /// Pill height with one line of text; also every button's size.
  static const double bar = 48;
  static const double icon = 24;
  static const double gap = 6;
  static const EdgeInsets outer = EdgeInsets.fromLTRB(6, 4, 6, 6);
  static const double textSize = 16;
  static const double textHeight = 1.375; // 22 px line → 13 + 22 + 13 = 48
}

/// Rounded input pill + a separate round action button on the right.
class ComposerShell extends StatelessWidget {
  const ComposerShell({
    required this.pill,
    required this.action,
    super.key,
  });

  final Widget pill;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: ComposerMetrics.outer,
        child: Row(
          // Multi-line text grows upwards; buttons stay on the bottom line.
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              // DecoratedBox, not Container: a Container pads its child by
              // the border width, which put the icons 0.5 px off the send
              // button's line and made the pill 49 px.
              child: ConstrainedBox(
                key: const Key('composer-pill'),
                constraints:
                    const BoxConstraints(minHeight: ComposerMetrics.bar),
                child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(ComposerMetrics.bar / 2),
                  border: Border.all(color: AppColors.borderDefault, width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: AppColors.isDark ? 0.25 : 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: pill,
                ),
              ),
            ),
            const SizedBox(width: ComposerMetrics.gap),
            action,
          ],
        ),
      ),
    );
  }
}

/// Icon inside the pill (emoji, attach, camera, cancel): 48×48 target,
/// 24 px icon, one colour.
class ComposerIconButton extends StatelessWidget {
  const ComposerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.turns = 0,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  /// Rotation in turns (WhatsApp's paperclip is tilted −45°).
  final double turns;

  @override
  Widget build(BuildContext context) {
    Widget glyph = Icon(
      icon,
      size: ComposerMetrics.icon,
      color: color ?? AppColors.textSecondary,
    );
    if (turns != 0) glyph = RotationTransition(turns: AlwaysStoppedAnimation(turns), child: glyph);
    return SizedBox.square(
      dimension: ComposerMetrics.bar,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: ComposerMetrics.bar,
          height: ComposerMetrics.bar,
        ),
        icon: glyph,
      ),
    );
  }
}

/// Round brand button right of the pill: mic / send / send voice note.
class ComposerRoundButton extends StatelessWidget {
  const ComposerRoundButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.busy = false,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Tooltip(
        message: semanticLabel,
        child: Material(
          key: const Key('composer-action'),
          color: AppColors.tealDark.withValues(alpha: busy ? 0.5 : 1),
          shape: const CircleBorder(),
          elevation: 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: busy ? null : onTap,
            child: SizedBox.square(
              dimension: ComposerMetrics.bar,
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 120),
                      transitionBuilder: (c, a) =>
                          ScaleTransition(scale: a, child: c),
                      child: Icon(
                        icon,
                        key: ValueKey(icon),
                        size: ComposerMetrics.icon,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
