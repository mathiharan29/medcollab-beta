import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Smooth Light ⇄ Dark switch.
///
/// Many widgets read [AppColors] tokens directly, which cannot animate, and
/// a theme lerp resized text half-way through. So the theme now switches in
/// a single frame, and this controller hides that frame behind a snapshot of
/// the old screen that fades out (the way Telegram/WhatsApp switch).
class ThemeSwitchController {
  ThemeSwitchController._();
  static final instance = ThemeSwitchController._();

  final GlobalKey boundaryKey = GlobalKey(debugLabel: 'theme-switch-boundary');
  final ValueNotifier<ui.Image?> snapshot = ValueNotifier<ui.Image?>(null);

  /// Captures the current screen. Returns quietly when there is nothing to
  /// capture (tests, first frame) — the switch then just happens instantly.
  Future<void> capture() async {
    try {
      final ctx = boundaryKey.currentContext;
      final boundary = ctx?.findRenderObject();
      if (boundary is! RenderRepaintBoundary || !boundary.attached) return;
      if (boundary.debugNeedsPaint) return;
      final ratio = MediaQuery.maybeDevicePixelRatioOf(ctx!) ?? 1.0;
      // Half resolution is plenty for a 250 ms fade and keeps capture fast.
      final image = await boundary
          .toImage(pixelRatio: (ratio / 2).clamp(1.0, 2.0))
          .timeout(const Duration(milliseconds: 250));
      snapshot.value?.dispose();
      snapshot.value = image;
    } catch (_) {
      // Snapshot is cosmetic only.
    }
  }

  void clear() {
    final old = snapshot.value;
    snapshot.value = null;
    old?.dispose();
  }
}

/// Wraps the app: a repaint boundary for capture + the fading snapshot.
class ThemeSwitchTransition extends StatefulWidget {
  const ThemeSwitchTransition({required this.child, super.key});

  final Widget child;

  @override
  State<ThemeSwitchTransition> createState() => _ThemeSwitchTransitionState();
}

class _ThemeSwitchTransitionState extends State<ThemeSwitchTransition>
    with SingleTickerProviderStateMixin {
  final _controller = ThemeSwitchController.instance;
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void initState() {
    super.initState();
    _controller.snapshot.addListener(_onSnapshot);
    _fade.addStatusListener((s) {
      if (s == AnimationStatus.completed) _controller.clear();
    });
  }

  void _onSnapshot() {
    if (_controller.snapshot.value == null) return;
    // Hold the old frame fully opaque for two frames while the whole tree
    // rebuilds with the new colours, then fade it away.
    _fade.value = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fade.forward(from: 0);
      });
    });
  }

  @override
  void dispose() {
    _controller.snapshot.removeListener(_onSnapshot);
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.passthrough,
      children: [
        RepaintBoundary(key: _controller.boundaryKey, child: widget.child),
        ValueListenableBuilder<ui.Image?>(
          valueListenable: _controller.snapshot,
          builder: (context, image, _) {
            if (image == null) return const SizedBox.shrink();
            return Positioned.fill(
              child: IgnorePointer(
                child: FadeTransition(
                  opacity: ReverseAnimation(
                    CurvedAnimation(parent: _fade, curve: Curves.easeOut),
                  ),
                  child: RawImage(image: image, fit: BoxFit.fill),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
