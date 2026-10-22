import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_patient_model.dart';
import 'package:medcollab_app/features/handoffs/presentation/widgets/patient_editor_sheet.dart';

void main() {
  testWidgets('FR-HOF-13: patient editor validates, cancels and saves selected patient',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const first = HandoffPatientModel(
      id: 'patient-synthetic-a', bedNumber: 'A-01',
      clinicalAlias: 'Synthetic Patient A',
      pendingTasks: ['Review CBC', 'Check ECG'],
    );
    const second = HandoffPatientModel(
      id: 'patient-synthetic-b', bedNumber: 'B-02',
      clinicalAlias: 'Synthetic Patient B',
      pendingTasks: ['Review imaging'],
    );
    final patients = ValueNotifier<List<HandoffPatientModel>>([first, second]);
    addTearDown(patients.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => Column(children: [
        FilledButton(
          onPressed: () async {
            final updated = await PatientEditorSheet.show(context,
                initial: patients.value.first);
            if (updated != null) {
              patients.value = [updated, patients.value[1]];
            }
          },
          child: const Text('Edit selected patient'),
        ),
        ValueListenableBuilder<List<HandoffPatientModel>>(
          valueListenable: patients,
          builder: (_, value, __) => Text(
            '${value[0].pendingTasks.join(', ')} | ${value[0].isFlagged} | '
            '${value[1].pendingTasks.join(', ')}',
          ),
        ),
      ]),
    ))));
    await tester.tap(find.text('Edit selected patient'));
    await tester.pumpAndSettle();
    expect(find.text('Edit patient'), findsOneWidget);
    final bed = find.widgetWithText(TextField, 'Bed number');
    final tasks = find.widgetWithText(TextField, 'Pending tasks');
    await tester.enterText(bed, '');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Bed number and clinical alias required'), findsOneWidget);
    expect(find.text('Edit patient'), findsOneWidget,
        reason: 'Validation must happen before the sheet submits');
    expect(patients.value, [first, second]);

    await tester.enterText(bed, 'A-01');
    await tester.enterText(tasks, 'Review CBC\nCheck potassium');
    await tester.tap(find.text('High priority'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(patients.value, [first, second],
        reason: 'Cancel must not update the draft patient list');

    await tester.tap(find.text('Edit selected patient'));
    await tester.pumpAndSettle();
    await tester.enterText(tasks, 'Review CBC\nCheck potassium');
    await tester.tap(find.text('High priority'));
    final attachmentControlVisible =
        find.textContaining('Attachment').evaluate().isNotEmpty ||
        find.byIcon(Icons.attach_file).evaluate().isNotEmpty;
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(patients.value.first.id, first.id);
    expect(patients.value.first.pendingTasks, ['Review CBC', 'Check potassium']);
    expect(patients.value.first.isFlagged, isTrue);
    expect(patients.value[1], second,
        reason: 'Saving one patient cannot mutate another patient');
    expect(attachmentControlVisible, isTrue,
        reason: 'Catalog requires adding and removing a patient attachment');
  });
}
