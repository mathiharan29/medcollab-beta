import 'package:flutter_bloc/flutter_bloc.dart';

/// Drops state updates that arrive after the cubit was closed.
///
/// Screens close their cubit when the user leaves; network calls started on
/// that screen can still complete afterwards. Without this, `emit` throws
/// "Cannot emit new states after calling close" — found by the UI journey
/// test when a doctor sent a message and left the chat immediately (the
/// error was then mis-handled as a send failure, which emitted again).
mixin SafeEmit<S> on Cubit<S> {
  @override
  void emit(S state) {
    if (isClosed) return;
    super.emit(state);
  }
}
