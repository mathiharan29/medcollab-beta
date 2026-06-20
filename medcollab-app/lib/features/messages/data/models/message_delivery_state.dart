/// Client-side delivery tracking (not persisted on server).
enum MessageDeliveryState {
  sending,
  sent,
  failed,
}

extension MessageDeliveryStateX on MessageDeliveryState {
  String get label => switch (this) {
        MessageDeliveryState.sending => 'Sending…',
        MessageDeliveryState.sent => 'Sent',
        MessageDeliveryState.failed => 'Failed',
      };
}
