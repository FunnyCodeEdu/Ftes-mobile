import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:ftes/features/auth/domain/constants/auth_constants.dart';
import 'package:ftes/core/error/failures.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/verify_email_otp_usecase.dart';
import '../../domain/usecases/resend_verification_code_usecase.dart';
import '../../domain/usecases/activate_user_usecase.dart';
import '../../../profile/domain/usecases/profile_usecases.dart';

class RegisterViewModel extends ChangeNotifier {
  final RegisterUseCase registerUseCase;
  final VerifyEmailOTPUseCase verifyEmailOTPUseCase;
  final ResendVerificationCodeUseCase resendVerificationCodeUseCase;
  final ActivateUserUseCase activateUserUseCase;
  final CreateProfileAutoUseCase createProfileAutoUseCase;

  RegisterViewModel({
    required this.registerUseCase,
    required this.verifyEmailOTPUseCase,
    required this.resendVerificationCodeUseCase,
    required this.activateUserUseCase,
    required this.createProfileAutoUseCase,
  });

  // State variables
  User? _registeredUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isRegistered = false;
  String? _registeredEmail;
  String? _accessToken;

  // Getters
  User? get registeredUser => _registeredUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isRegistered => _isRegistered;
  String? get registeredEmail => _registeredEmail;
  String? get accessToken => _accessToken;

  /// Register new user
  Future<bool> register(String username, String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await registerUseCase(RegisterParams(
        username: username,
        email: email,
        password: password,
      ));

      return result.fold(
        (failure) {
          _setError(_mapFailureToMessage(failure));
          return false;
        },
        (user) {
          _registeredUser = user;
          _isRegistered = true;
          _registeredEmail = email;
          
          // Auto-create profile after successful registration (fire-and-forget)
          unawaited(_createProfileAuto(user.id));
          
          notifyListeners();
          return true;
        },
      );
    } catch (e) {
      _setError(AuthConstants.errorRegisterFailed);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Verify email OTP - returns accessToken on success
  Future<String?> verifyOTP(String email, int otp) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await verifyEmailOTPUseCase(VerifyOTPParams(
        email: email,
        otp: otp,
      ));

      return result.fold(
        (failure) {
          _setError(_mapFailureToMessage(failure));
          return null;
        },
        (accessToken) {
          _accessToken = accessToken;
          notifyListeners();
          return accessToken;
        },
      );
    } catch (e) {
      _setError(AuthConstants.errorVerifyOTPFailed);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Activate user account after OTP verification
  Future<bool> activateUser(String accessToken) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await activateUserUseCase(ActivateUserParams(
        accessToken: accessToken,
      ));

      return result.fold(
        (failure) {
          _setError(_mapFailureToMessage(failure));
          return false;
        },
        (_) {
          notifyListeners();
          return true;
        },
      );
    } catch (e) {
      _setError('Kích hoạt tài khoản thất bại');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Resend verification code
  Future<bool> resendCode(String email) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await resendVerificationCodeUseCase(email);

      return result.fold(
        (failure) {
          _setError(_mapFailureToMessage(failure));
          return false;
        },
        (_) {
          notifyListeners();
          return true;
        },
      );
    } catch (e) {
      _setError(AuthConstants.errorResendCodeFailed);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
  }

  /// Reset state
  void reset() {
    _registeredUser = null;
    _isRegistered = false;
    _registeredEmail = null;
    _accessToken = null;
    _errorMessage = null;
    notifyListeners();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  /// Auto-create profile after successful registration
  Future<void> _createProfileAuto(String userId) async {
    try {
      final result = await createProfileAutoUseCase(userId);
      result.fold(
        (failure) => debugPrint('❌ Failed to create profile automatically: ${failure.message}'),
        (profile) => debugPrint('✅ Profile created automatically for user: $userId'),
      );
    } catch (e) {
      debugPrint('❌ Failed to create profile automatically: $e');
      // Don't throw error here as registration was successful
      // Profile can be created later manually
    }
  }

  /// Map failure to user-friendly message
  String _mapFailureToMessage(Failure failure) {
    return failure.message;
  }
}
