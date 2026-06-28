import 'package:equatable/equatable.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.phoneE164,
    this.msg91ReqId,
    this.errorMessage,
  });

  const AuthState.unknown() : this();

  const AuthState.loading({UserModel? user, String? phoneE164, String? msg91ReqId})
      : this(
          status: AuthStatus.loading,
          user: user,
          phoneE164: phoneE164,
          msg91ReqId: msg91ReqId,
        );

  final AuthStatus status;
  final UserModel? user;
  final String? phoneE164;
  final String? msg91ReqId;
  final String? errorMessage;

  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? phoneE164,
    String? msg91ReqId,
    String? errorMessage,
    bool clearError = false,
    bool clearPhone = false,
    bool clearUser = false,
    bool clearMsg91ReqId = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      phoneE164: clearPhone ? null : (phoneE164 ?? this.phoneE164),
      msg91ReqId: clearMsg91ReqId ? null : (msg91ReqId ?? this.msg91ReqId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, user, phoneE164, msg91ReqId, errorMessage];
}
