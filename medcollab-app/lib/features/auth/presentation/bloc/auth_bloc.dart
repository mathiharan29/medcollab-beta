import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/auth/msg91_otp_service.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/utils/phone_utils.dart';
import 'package:medcollab_app/features/auth/data/models/auth_login_result.dart';
import 'package:medcollab_app/features/auth/data/models/request_otp_request.dart';
import 'package:medcollab_app/features/auth/data/models/update_profile_request.dart';
import 'package:medcollab_app/features/auth/data/models/verify_msg91_token_request.dart';
import 'package:medcollab_app/features/auth/data/models/verify_otp_request.dart';
import 'package:medcollab_app/features/auth/data/repositories/auth_repository.dart';
import 'package:medcollab_app/features/auth/data/repositories/user_repository.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required AuthRepository authRepository,
    required UserRepository userRepository,
    Msg91OtpService? msg91OtpService,
    bool useMsg91Widget = false,
  })  : _authRepository = authRepository,
        _userRepository = userRepository,
        _msg91OtpService = msg91OtpService,
        _useMsg91Widget = useMsg91Widget,
        super(const AuthState.unknown()) {
    on<AuthStarted>(_onStarted);
    on<AuthPhoneSubmitted>(_onPhoneSubmitted);
    on<AuthOtpSubmitted>(_onOtpSubmitted);
    on<AuthProfileSubmitted>(_onProfileSubmitted);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthErrorDismissed>(_onErrorDismissed);
    on<AuthOtpResendRequested>(_onOtpResendRequested);
    on<AuthChangePhoneRequested>(_onChangePhoneRequested);
    on<AuthSessionExpired>(_onSessionExpired);
    on<AuthAvailabilityUpdated>(_onAvailabilityUpdated);
  }

  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final Msg91OtpService? _msg91OtpService;
  final bool _useMsg91Widget;

  bool _sessionCheckStarted = false;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    if (_sessionCheckStarted && state.status != AuthStatus.unknown) {
      return;
    }
    _sessionCheckStarted = true;

    emit(AuthState.loading(user: state.user, phoneE164: state.phoneE164));

    try {
      final hasSession = await _authRepository.hasSession();
      if (!hasSession) {
        emit(const AuthState(status: AuthStatus.unauthenticated));
        return;
      }

      final user = await _userRepository.getMe();
      await _authRepository.restoreSocketConnection();

      if (user.hasMinimumProfile) {
        emit(AuthState(status: AuthStatus.authenticated, user: user));
      } else {
        emit(AuthState(status: AuthStatus.needsProfile, user: user));
      }
    } on UnauthorizedException {
      await _authRepository.logout();
      emit(const AuthState(status: AuthStatus.unauthenticated));
    } on NetworkException catch (e) {
      _sessionCheckStarted = false;
      emit(
        AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: e.message,
        ),
      );
    } on AppException catch (e) {
      _sessionCheckStarted = false;
      emit(
        AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      _sessionCheckStarted = false;
      emit(
        const AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Could not restore session. Please log in again.',
        ),
      );
    }
  }

  Future<void> _onPhoneSubmitted(
    AuthPhoneSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final validation = PhoneUtils.validateLocalNumber(event.localPhone);
    if (validation != null) {
      emit(state.copyWith(errorMessage: validation));
      return;
    }

    final phoneE164 = PhoneUtils.toE164(event.localPhone);
    emit(AuthState.loading(phoneE164: phoneE164));

    try {
      if (_useMsg91Widget) {
        final reqId = await _msg91OtpService!.sendOtp(phoneE164);
        emit(AuthState(
          status: AuthStatus.otpSent,
          phoneE164: phoneE164,
          msg91ReqId: reqId,
        ));
        return;
      }

      await _authRepository.requestOtp(RequestOtpRequest(phone: phoneE164));
      emit(AuthState(status: AuthStatus.otpSent, phoneE164: phoneE164));
    } on AppException catch (e) {
      emit(AuthState(
        status: AuthStatus.unauthenticated,
        phoneE164: phoneE164,
        errorMessage: e.message,
      ));
    } catch (_) {
      emit(AuthState(
        status: AuthStatus.unauthenticated,
        phoneE164: phoneE164,
        errorMessage: 'Failed to send OTP. Please try again.',
      ));
    }
  }

  Future<void> _onOtpSubmitted(
    AuthOtpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final phone = state.phoneE164;
    if (phone == null) {
      emit(const AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Session expired. Enter your phone number again.',
      ));
      return;
    }

    final validation = PhoneUtils.validateOtp(event.otp);
    if (validation != null) {
      emit(state.copyWith(errorMessage: validation));
      return;
    }

    emit(AuthState.loading(
      phoneE164: phone,
      user: state.user,
      msg91ReqId: state.msg91ReqId,
    ));

    try {
      late final AuthLoginResult result;
      if (_useMsg91Widget) {
        final reqId = state.msg91ReqId;
        if (reqId == null) {
          emit(AuthState(
            status: AuthStatus.unauthenticated,
            phoneE164: phone,
            errorMessage: 'OTP session expired. Request a new code.',
          ));
          return;
        }

        final widgetAccessToken = await _msg91OtpService!.verifyOtp(
          reqId: reqId,
          otp: event.otp.trim(),
        );
        result = await _authRepository.verifyMsg91Token(
          VerifyMsg91TokenRequest(
            phone: phone,
            accessToken: widgetAccessToken,
          ),
        );
      } else {
        result = await _authRepository.verifyOtp(
          VerifyOtpRequest(phone: phone, otp: event.otp.trim()),
        );
      }

      final user = result.session.user;
      final needsProfile = result.isNewUser || !user.hasMinimumProfile;

      emit(AuthState(
        status:
            needsProfile ? AuthStatus.needsProfile : AuthStatus.authenticated,
        user: user,
        phoneE164: phone,
      ));
    } on AppException catch (e) {
      emit(AuthState(
        status: AuthStatus.otpSent,
        phoneE164: phone,
        msg91ReqId: state.msg91ReqId,
        user: state.user,
        errorMessage: e.message,
      ));
    } catch (_) {
      emit(AuthState(
        status: AuthStatus.otpSent,
        phoneE164: phone,
        msg91ReqId: state.msg91ReqId,
        errorMessage: 'Invalid OTP. Please try again.',
      ));
    }
  }

  Future<void> _onProfileSubmitted(
    AuthProfileSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final name = event.name.trim();
    if (name.length < 2) {
      emit(state.copyWith(errorMessage: 'Name must be at least 2 characters'));
      return;
    }

    final role = UserRole.fromString(event.role);
    emit(AuthState.loading(user: state.user, phoneE164: state.phoneE164));

    try {
      final user = await _userRepository.updateMe(
        UpdateProfileRequest(
          name: name,
          role: role,
          speciality: event.speciality,
          institution: event.institution,
        ),
      );

      emit(AuthState(
        status: AuthStatus.authenticated,
        user: user,
        phoneE164: state.phoneE164,
      ));
    } on AppException catch (e) {
      emit(AuthState(
        status: AuthStatus.needsProfile,
        user: state.user,
        phoneE164: state.phoneE164,
        errorMessage: e.message,
      ));
    } catch (e, stackTrace) {
      assert(() {
        // ignore: avoid_print
        print('AuthBloc._onProfileSubmitted error: $e\n$stackTrace');
        return true;
      }());
      emit(AuthState(
        status: AuthStatus.needsProfile,
        user: state.user,
        phoneE164: state.phoneE164,
        errorMessage: 'Could not save profile. Please try again.',
      ));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading(user: state.user));

    try {
      await _authRepository.logout();
    } catch (_) {
      // Clear local session even if API call fails.
    }

    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  void _onErrorDismissed(AuthErrorDismissed event, Emitter<AuthState> emit) {
    emit(state.copyWith(clearError: true));
  }

  Future<void> _onOtpResendRequested(
    AuthOtpResendRequested event,
    Emitter<AuthState> emit,
  ) async {
    final phone = state.phoneE164;
    if (phone == null) return;

    emit(AuthState.loading(phoneE164: phone, msg91ReqId: state.msg91ReqId));

    try {
      if (_useMsg91Widget) {
        final reqId = state.msg91ReqId;
        if (reqId == null) {
          final newReqId = await _msg91OtpService!.sendOtp(phone);
          emit(AuthState(
            status: AuthStatus.otpSent,
            phoneE164: phone,
            msg91ReqId: newReqId,
          ));
          return;
        }
        await _msg91OtpService!.retryOtp(reqId);
        emit(AuthState(
          status: AuthStatus.otpSent,
          phoneE164: phone,
          msg91ReqId: reqId,
        ));
        return;
      }

      await _authRepository.requestOtp(RequestOtpRequest(phone: phone));
      emit(AuthState(status: AuthStatus.otpSent, phoneE164: phone));
    } on AppException catch (e) {
      emit(
        AuthState(
          status: AuthStatus.otpSent,
          phoneE164: phone,
          msg91ReqId: state.msg91ReqId,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      emit(
        AuthState(
          status: AuthStatus.otpSent,
          phoneE164: phone,
          msg91ReqId: state.msg91ReqId,
          errorMessage: 'Failed to resend OTP. Please try again.',
        ),
      );
    }
  }

  void _onChangePhoneRequested(
    AuthChangePhoneRequested event,
    Emitter<AuthState> emit,
  ) {
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> _onSessionExpired(
    AuthSessionExpired event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _authRepository.logout();
    } catch (_) {
      // Ensure local session is cleared even if API fails.
    }
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  void _onAvailabilityUpdated(
    AuthAvailabilityUpdated event,
    Emitter<AuthState> emit,
  ) {
    final user = state.user;
    if (user == null) return;
    emit(
      state.copyWith(
        user: user.copyWith(availability: event.availability),
      ),
    );
  }
}
