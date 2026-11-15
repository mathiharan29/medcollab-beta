// Issue 4 (beta 11-14): composer icons were uneven (26 / 22 / 20 px glyphs
// in 44 / ~40 / 44 px boxes, send nudged up 2 px) and the placeholder read
// "Message… @ to mention". Guards the WhatsApp-style layout.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/theme/app_theme.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/composer_parts.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/message_widgets.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/voice_note.dart';

Widget _host(Widget child, {double textScale = 1}) => MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: child)),
      ),
    );

void main() {
  late TextEditingController c;
  setUp(() => c = TextEditingController());

  Widget composer({String hint = 'Message'}) => MessageComposer(
        controller: c,
        hintText: hint,
        onSend: (_) {},
        onPickGallery: () {},
        onPickCamera: () {},
        onPickDocument: () {},
        onRecordVoice: () {},
      );

  for (final scale in [1.0, 1.3]) {
    testWidgets('all controls are 48×48 on one bottom line (text ×$scale)',
        (t) async {
      await t.pumpWidget(_host(composer(), textScale: scale));
      final buttons = find.byType(ComposerIconButton);
      expect(buttons, findsNWidgets(3), reason: 'emoji, attach, camera');
      final action = find.byKey(const Key('composer-action'));
      final pill = t.getRect(find.byKey(const Key('composer-pill')));
      final rects = [
        for (final e in buttons.evaluate()) t.getRect(find.byWidget(e.widget)),
        t.getRect(action),
      ];
      for (final r in rects) {
        expect(r.size, const Size(48, 48));
        expect(r.bottom, closeTo(rects.first.bottom, 0.01), reason: 'same baseline');
      }
      expect(pill.height, scale == 1 ? 48 : greaterThanOrEqualTo(48));
      expect(t.getRect(action).left, greaterThan(pill.right),
          reason: 'send / mic is a separate circle outside the pill');
      for (final icon in t.widgetList<Icon>(find.descendant(
          of: find.byType(MessageComposer), matching: find.byType(Icon)))) {
        expect(icon.size, 24);
      }
    });
  }

  testWidgets('placeholder is a plain "Message"; camera hides while typing',
      (t) async {
    await t.pumpWidget(_host(composer()));
    expect(find.text('Message'), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byTooltip('Camera'), findsOneWidget);

    c.text = 'BP 90/60';
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.byTooltip('Camera'), findsNothing);
    final action = t.getRect(find.byKey(const Key('composer-action')));
    expect(action.size, const Size(48, 48), reason: 'mic ↔ send same size');
  });

  testWidgets('multi-line text grows the pill upward; buttons stay at bottom',
      (t) async {
    await t.pumpWidget(_host(composer()));
    final before = t.getRect(find.byKey(const Key('composer-action')));
    c.text = 'line 1\nline 2\nline 3';
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    final pill = t.getRect(find.byKey(const Key('composer-pill')));
    expect(pill.height, greaterThan(48));
    expect(t.getRect(find.byKey(const Key('composer-action'))).bottom,
        closeTo(before.bottom, 0.01));
  });

  testWidgets('recording bar has the exact same pill and button geometry',
      (t) async {
    await t.pumpWidget(_host(composer()));
    final pill = t.getRect(find.byKey(const Key('composer-pill')));
    final action = t.getRect(find.byKey(const Key('composer-action')));

    await t.pumpWidget(_host(VoiceRecordingBar(
      controller: VoiceRecorderController(),
      onCancel: () {},
      onSend: () {},
    )));
    await t.pump();
    expect(t.getRect(find.byKey(const Key('composer-pill'))), pill);
    expect(t.getRect(find.byKey(const Key('composer-action'))), action);
  });
}
