import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/messages/data/models/message_delivery_state.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/data/models/message_read_receipt.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/message_widgets.dart';

void main() {
  testWidgets('FR-SOC-06 pending, failed, sent and read states respect receipt preference', (tester) async {
    final base = MessageModel(
      id: 'synthetic-message-1', channelId: 'synthetic-dm',
      sender: const UserModel(id: 'me', name: 'Me'),
      content: const MessageContent(text: 'Synthetic clinical note'),
      createdAt: DateTime.utc(2026, 10, 10, 9),
    );

    Future<void> show(MessageModel message, {bool readReceipts = true}) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child:
          MessageBubble(message: message, isMine: true, currentUserId: 'me',
              isDm: true, showReadReceipts: readReceipts)))));
      await tester.pump();
    }

    final read = base.copyWith(readBy: [
      const MessageReadReceipt(userId: 'peer', user: UserModel(id: 'peer', name: 'Ada')),
    ]);
    await show(read);
    expect(find.textContaining('Seen by Ada'), findsOneWidget);
    await show(read, readReceipts: false);
    expect(find.textContaining('Seen by'), findsNothing);

    final failed = base.copyWith(localOnly: true, deliveryState: MessageDeliveryState.failed);
    await show(failed);
    expect(find.text('Failed to send'), findsOneWidget);
    expect(find.textContaining('Seen by'), findsNothing);

    final sent = base.copyWith(deliveryState: MessageDeliveryState.sent);
    await show(sent);
    expect(find.text('Failed to send'), findsNothing);
    expect(find.textContaining('Delivered'), findsNothing,
        reason: 'A locally sent message does not prove peer delivery');

    final pending = base.copyWith(localOnly: true, deliveryState: MessageDeliveryState.sending);
    await show(pending);
    expect(find.text(MessageDeliveryState.sending.label), findsOneWidget,
        reason: 'An optimistic message needs a visible pending state');
  });
}
