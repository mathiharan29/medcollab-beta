import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_model.dart';
import 'package:medcollab_app/features/handoffs/presentation/widgets/handoff_card.dart';

const _sender = UserModel(id: 'doctor-synthetic-a', name: 'Doctor A');
const _receiver = UserModel(id: 'doctor-synthetic-b', name: 'Doctor B');

HandoffModel _handoff(String id, DateTime day, HandoffStatus status) =>
    HandoffModel(
      id: id,
      spaceId: 'space-synthetic',
      channelId: 'channel-synthetic',
      fromUser: _sender,
      toUser: _receiver,
      shiftDate: day,
      shiftType: ShiftType.morning,
      status: status,
    );

void main() {
  testWidgets('FR-HOF-12: local-day labels preserve server status [NEEDS_DECISION Q12]',
      (tester) async {
    final started = DateTime.now();
    final today = DateTime(started.year, started.month, started.day);
    final dates = <String, DateTime>{
      'yesterday': today.subtract(const Duration(days: 1)),
      'today': today,
      'tomorrow': today.add(const Duration(days: 1)),
    };
    final handoffs = <HandoffModel>[
      for (final entry in dates.entries)
        _handoff('${entry.key}-submitted', entry.value, HandoffStatus.submitted),
      for (final entry in dates.entries)
        _handoff('${entry.key}-acknowledged', entry.value,
            HandoffStatus.acknowledged),
    ];
    expect(handoffs, hasLength(6));
    for (final handoff in handoffs) {
      final originalStatus = handoff.status;
      final originalDate = handoff.shiftDate;
      final label = handoff.lifecycleLabel;
      expect(label, isNotEmpty);
      expect(handoff.status, originalStatus,
          reason: 'Reading a client label cannot transition backend status');
      expect(handoff.shiftDate, originalDate);
      if (handoff.id.startsWith('yesterday')) {
        expect(handoff.isShiftPast, isTrue);
      } else {
        expect(handoff.isShiftPast, isFalse);
      }
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: HandoffCard(
        handoff: handoff, onTap: () {},
      ))));
      final displayed = label == 'Completed' ? 'Done' : label;
      expect(find.text(displayed), findsOneWidget,
          reason: 'The card must present the lifecycle calculated by its model');
      expect(handoff.status, originalStatus);
      expect(handoff.shiftDate, originalDate);
    }
    expect(DateTime.now().day, started.day,
        reason: 'Direct DateTime.now() source requires a run within one local day');
  });
}
