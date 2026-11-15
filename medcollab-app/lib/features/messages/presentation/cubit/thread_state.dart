part of 'thread_cubit.dart';

class ThreadState extends Equatable {
  const ThreadState({
    this.rootMessage,
    this.replies = const [],
    this.isLoading = false,
    this.isSending = false,
    this.isUploading = false,
    this.hasMore = false,
    this.error,
    this.typingUserNames = const [],
    this.unavailable = false,
  });

  final MessageModel? rootMessage;
  final List<MessageModel> replies;
  final bool isLoading;
  final bool isSending;
  final bool isUploading;
  final bool hasMore;
  final String? error;
  final List<String> typingUserNames;

  /// Root not visible to this user (deleted for them, cleared, or gone):
  /// nothing cached about it may be shown.
  final bool unavailable;

  String get typingLabel {
    final names = typingUserNames;
    if (names.isEmpty) return '';
    if (names.length == 1) return '${names.first} is typing…';
    if (names.length == 2) return '${names[0]} and ${names[1]} are typing…';
    return '${names.length} people are typing…';
  }

  ThreadState copyWith({
    MessageModel? rootMessage,
    List<MessageModel>? replies,
    bool? isLoading,
    bool? isSending,
    bool? isUploading,
    bool? hasMore,
    String? error,
    List<String>? typingUserNames,
    bool? unavailable,
  }) {
    return ThreadState(
      rootMessage: rootMessage ?? this.rootMessage,
      replies: replies ?? this.replies,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      isUploading: isUploading ?? this.isUploading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      typingUserNames: typingUserNames ?? this.typingUserNames,
      unavailable: unavailable ?? this.unavailable,
    );
  }

  @override
  List<Object?> get props => [
        rootMessage,
        replies,
        isLoading,
        isSending,
        isUploading,
        hasMore,
        error,
        typingUserNames,
        unavailable,
      ];
}
