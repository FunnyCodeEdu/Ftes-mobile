import 'package:dartz/dartz.dart';
import 'package:ftes/core/error/failures.dart';
import '../entities/user.dart';

/// Abstract repository interface for authentication operations
abstract class AuthRepository {
  /// Login with email and password
  Future<Either<Failure, User>> login(String email, String password);

  /// Login with Google OAuth
  Future<Either<Failure, User>> loginWithGoogle();

  /// Get current user info
  Future<Either<Failure, User>> getCurrentUser();

  /// Logout
  Future<Either<Failure, void>> logout();

  /// Register new user
  Future<Either<Failure, User>> register(String username, String email, String password);

  /// Verify email OTP
  Future<Either<Failure, String>> verifyEmailOTP(String email, int otp);

  /// Resend verification code
  Future<Either<Failure, void>> resendVerificationCode(String email);

  /// Send forgot password email
  Future<Either<Failure, void>> sendForgotPasswordEmail(String email);

  /// Verify forgot password OTP
  Future<Either<Failure, String>> verifyForgotPasswordOTP(String email, int otp);

  /// Reset password with access token
  Future<Either<Failure, void>> resetPassword(String password, String accessToken);

  /// Activate user account
  Future<Either<Failure, void>> activateUser(String accessToken);

  /// Invalidate user cache
  Future<Either<Failure, void>> invalidateUserCache();
}
