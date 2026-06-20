part of 'channel_chat_cubit.dart';

class ChannelChatState extends Equatable {
  const ChannelChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.hasMore = false,
    this.error,
  });

  final List<MessageModel> messages;
  final bool isLoading;
  final bool isSending;
  final bool hasMore;
  final String? error;

  ChannelChatState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? isSending,
    bool? hasMore,
    String? error,
  }) {
    return ChannelChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }

  @override
  List<Object?> get props =>
      [messages, isLoading, isSending, hasMore, error];
}
