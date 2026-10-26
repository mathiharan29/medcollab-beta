import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/auth/msg91_otp_service.dart';
import 'package:medcollab_app/core/config/env_config.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/notifications/fcm_service.dart';
import 'package:medcollab_app/core/utils/phone_utils.dart';
import 'package:medcollab_app/features/auth/data/models/auth_login_result.dart';
import 'package:medcollab_app/features/auth/data/models/request_otp_request.dart';
import 'package:medcollab_app/features/auth/data/models/update_profile_request.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
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
    FcmService? fcmService,
  })  : _authRepository = authRepository,
        _userRepository = userRepository,
        _msg91OtpService = msg91OtpService,
        _useMsg91Widget = useMsg91Widget,
        _fcmService = fcmService,
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
    on<AuthUserUpdated>(_onUserUpdated);
  }

  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final Msg91OtpService? _msg91OtpService;
  final bool _useMsg91Widget;
  final FcmService? _fcmService;

  bool _sessionCheckStarted = false;

  void _registerPush() {
    final fcm = _fcmService;
    if (fcm == null) return;
    unawaited(fcm.registerTokenWithBackend());
  }

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
      unawaited(_authRepository.restoreSocketConnection());

      if (user.hasMinimumProfile) {
        final activeUser = await _ensureAvailableOnSessionStart(user);
        emit(AuthState(status: AuthStatus.authenticated, user: activeUser));
        _registerPush();
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

      // Production Railway has no DLT SMS template — server request-otp fails.
      // Release APKs must be built with MSG91 widget id + token.
      if (_isProductionApiWithoutWidget()) {
        emit(AuthState(
          status: AuthStatus.unauthenticated,
          phoneE164: phoneE164,
          errorMessage:
              'This app build cannot send OTP. Reinstall a release APK built with MSG91 widget credentials (see build-release-apk.ps1).',
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

  bool _isProductionApiWithoutWidget() {
    final base = EnvConfig.apiBaseUrl.toLowerCase();
    return base.contains('railway.app') || base.contains('medcollab');
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

      if (needsProfile) {
        emit(AuthState(
          status: AuthStatus.needsProfile,
          user: user,
          phoneE164: phone,
        ));
      } else {
        // Await availability restore inside the handler — emitting from an
        // unawaited future after the handler completes crashes the bloc
        // (FR-PUSH-06 / FR-JRN-06 device OTP login).
        final activeUser = await _ensureAvailableOnSessionStart(user);
        emit(AuthState(
          status: AuthStatus.authenticated,
          user: activeUser,
          phoneE164: phone,
        ));
        _registerPush();
      }
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
      _registerPush();
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
    // Every step is bounded — SharedPreferences/FCM hangs on a stressed
    // emulator must not leave AuthBloc past the device harness wait
    // (FR-NAV-05 / FR-JRN-05).
    String? fcmToken;
    try {
      fcmToken = await _fcmService
          ?.prepareLogoutToken()
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      await _authRepository
          .logout(fcmToken: fcmToken)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      try {
        await _authRepository
            .clearLocalSession()
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
    try {
      await _fcmService?.clearLocalToken().timeout(const Duration(seconds: 2));
    } catch (_) {}

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
    // Emit first so resume/refresh denial cannot leave Home mounted (FR-RT-06).
    // Skip the logout API — the refresh token is already dead.
    emit(const AuthState(status: AuthStatus.unauthenticated));
    try {
      await _authRepository.clearLocalSession();
    } catch (_) {}
    await _fcmService?.clearLocalToken();
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

  void _onUserUpdated(AuthUserUpdated event, Emitter<AuthState> emit) {
    emit(state.copyWith(user: event.user));
  }

  /// After login or cold start, return to Available if still marked Off Duty.
  Future<UserModel> _ensureAvailableOnSessionStart(UserModel user) async {
    if (user.availability.status != AvailabilityStatus.offDuty) {
      return user;
    }

    try {
      final availability = await _userRepository.updateAvailability(
        status: AvailabilityStatus.available,
      );
      final deps = AppDependencies.instance;
      if (deps.socketClient.isConnected) {
        deps.socketClient.updateAvailability(
          status: AvailabilityStatus.available.value,
        );
      }
      deps.presenceCubit.applyLocal(
        userId: user.id,
        status: AvailabilityStatus.available,
        isOnline: deps.socketClient.isConnected,
      );
      return user.copyWith(availability: availability);
    } catch (_) {
      return user;
    }
  }
}
