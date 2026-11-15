// REQ 9: "Add attachment" on a handoff patient picks and uploads a real file
// (not a fake "Attachment N" paperclip chip), shows its name, saves it with
// the patient, supports removal, failure and a 5-file cap.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_patient_model.dart';
import 'package:medcollab_app/features/handoffs/presentation/widgets/handoff_widgets.dart';
import 'package:medcollab_app/features/handoffs/presentation/widgets/patient_editor_sheet.dart';
import 'package:medcollab_app/features/media/data/services/media_picker_service.dart';

const _patient = HandoffPatientModel(bedNumber: '7', clinicalAlias: '62M chest pain');

PickedAttachment _picked(String name, [String mime = 'image/jpeg']) =>
    PickedAttachment(bytes: Uint8List.fromList([1, 2, 3]), fileName: name, mimeType: mime);

class _Host {
  HandoffPatientModel? result;
  int pickCalls = 0;
  int uploadCalls = 0;
  final queue = <PickedAttachment?>[];
  bool failUpload = false;
  Completer<void>? holdUpload;

  Widget app({HandoffPatientModel initial = _patient}) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showModalBottomSheet<HandoffPatientModel>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => PatientEditorSheet(
                    initial: initial,
                    pickAttachment: (_) async {
                      pickCalls++;
                      return queue.isEmpty ? null : queue.removeAt(0);
                    },
                    uploadAttachment: (p) async {
                      uploadCalls++;
                      if (holdUpload != null) await holdUpload!.future;
                      if (failUpload) throw Exception('network');
                      return HandoffAttachment(
                        url: 'https://files.test/${p.fileName}',
                        fileName: p.fileName,
                        mimeType: p.mimeType,
                      );
                    },
                  ),
                );
              },
              child: const Text('OPEN'),
            ),
          ),
        ),
      );
}

Future<void> _open(WidgetTester tester, _Host host) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host.app());
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
}

Future<void> _tapAdd(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Add attachment'));
  await tester.tap(find.text('Add attachment'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('adds a real uploaded file with its name, saved with patient',
      (tester) async {
    final host = _Host()..queue.add(_picked('ecg_bed7.jpg'));
    await _open(tester, host);

    await _tapAdd(tester);
    expect(host.pickCalls, 1);
    expect(host.uploadCalls, 1);
    expect(find.text('ecg_bed7.jpg'), findsOneWidget);
    expect(find.textContaining('Attachment 1'), findsNothing,
        reason: 'no fake placeholder chips');
    expect(find.byType(InputChip), findsOneWidget,
        reason: 'exactly one chip per real file, not an extra paperclip');
    expect(find.text('Attachments (1/5)'), findsOneWidget);

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(host.result!.attachments.single.fileName, 'ecg_bed7.jpg');
    expect(host.result!.attachments.single.url, 'https://files.test/ecg_bed7.jpg');
  });

  testWidgets('cancelled pick adds nothing; failed upload shows message',
      (tester) async {
    final host = _Host()..queue.add(null);
    await _open(tester, host);
    await _tapAdd(tester);
    expect(host.uploadCalls, 0);
    expect(find.byType(InputChip), findsNothing);

    host
      ..queue.add(_picked('lab.pdf', 'application/pdf'))
      ..failUpload = true;
    await _tapAdd(tester);
    expect(find.text('Upload failed. Try again.'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('remove works; Save blocked while uploading; cap of 5',
      (tester) async {
    final host = _Host();
    await _open(tester, host);
    for (var i = 1; i <= 5; i++) {
      host.queue.add(_picked('f$i.jpg'));
      await _tapAdd(tester);
    }
    expect(find.byType(InputChip), findsNWidgets(5));
    expect(find.text('Add attachment'), findsNothing, reason: 'cap reached');

    await tester.tap(find.byTooltip('Remove attachment').first);
    await tester.pumpAndSettle();
    expect(find.byType(InputChip), findsNWidgets(4));

    host
      ..holdUpload = Completer<void>()
      ..queue.add(_picked('slow.jpg'));
    await tester.ensureVisible(find.text('Add attachment'));
    await tester.tap(find.text('Add attachment'));
    await tester.pump();
    expect(find.text('Uploading…'), findsOneWidget);
    final save = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
    expect(save.onPressed, isNull, reason: 'cannot save mid-upload');
    host.holdUpload!.complete();
    await tester.pumpAndSettle();
    expect(find.text('slow.jpg'), findsOneWidget);
  });

  test('attachments round-trip through JSON', () {
    final json = {
      'bedNumber': '7',
      'clinicalAlias': 'x',
      'attachments': [
        {'url': 'https://a/1.jpg', 'fileName': '1.jpg', 'mimeType': 'image/jpeg'},
        {'url': ''}, // dropped
      ],
    };
    final p = HandoffPatientModel.fromJson(json);
    expect(p.attachments, hasLength(1));
    expect(p.toJson()['attachments'], [
      {'url': 'https://a/1.jpg', 'fileName': '1.jpg', 'mimeType': 'image/jpeg'},
    ]);
  });

  testWidgets('patient card shows attachments with readable names',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: HandoffPatientCard(
          patient: HandoffPatientModel(
            bedNumber: '7',
            clinicalAlias: 'x',
            attachments: [HandoffAttachment(url: 'https://a/ecg.jpg', fileName: 'ecg.jpg', mimeType: 'image/jpeg')],
          ),
        ),
      ),
    ));
    expect(find.text('Attachments'), findsOneWidget);
    expect(find.text('ecg.jpg'), findsOneWidget);
  });
}
