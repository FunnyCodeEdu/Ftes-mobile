import '../models/auth_response_model.dart';
import '../models/user_model.dart';
import '../models/register_response_model.dart';
import '../models/verify_otp_response_model.dart';
import '../models/verify_otp_for_password_response_model.dart';

/// Abstract remote data source for authentication operations
abstract class AuthRemoteDataSource {
  /// Login with email and password
  Future<AuthenticationResponseModel> login(String email, String password);

  /// Login with Google OAuth
  Future<AuthenticationResponseModel> loginWithGoogle(String authCode, {bool isAdmin = false});

  /// Get current user info
  Future<UserModel> getMyInfo();

  /// Logout
  Future<void> logout();

  /// Register new user
  Future<RegisterResponseModel> register(String username, String email, String password);

  /// Verify email OTP
  Future<VerifyOTPResponseModel> verifyEmailOTP(String email, int otp);

  /// Activate user account
  Future<void> activateUser(String accessToken);

  /// Resend verification code
  Future<void> resendVerificationCode(String email);

  /// Send forgot password email
  Future<void> sendForgotPasswordEmail(String email);

  /// Verify forgot password OTP
  Future<VerifyOTPForPasswordResponseModel> verifyForgotPasswordOTP(String email, int otp);

  /// Reset password with access token
  Future<void> resetPassword(String password, String accessToken);
}
