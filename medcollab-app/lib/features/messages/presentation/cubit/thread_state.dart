part of 'thread_cubit.dart';

class ThreadState extends Equatable {
  const ThreadState({
    this.rootMessage,
    this.replies = const [],
    this.isLoading = false,
    this.isSending = false,
    this.hasMore = false,
    this.error,
  });

  final MessageModel? rootMessage;
  final List<MessageModel> replies;
  final bool isLoading;
  final bool isSending;
  final bool hasMore;
  final String? error;

  ThreadState copyWith({
    MessageModel? rootMessage,
    List<MessageModel>? replies,
    bool? isLoading,
    bool? isSending,
    bool? hasMore,
    String? error,
  }) {
    return ThreadState(
      rootMessage: rootMessage ?? this.rootMessage,
      replies: replies ?? this.replies,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }

  @override
  List<Object?> get props =>
      [rootMessage, replies, isLoading, isSending, hasMore, error];
}
