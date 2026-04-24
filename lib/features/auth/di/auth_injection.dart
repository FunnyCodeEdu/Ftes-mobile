import 'package:ftes/core/network/api_client.dart';
import 'package:ftes/core/di/injection_container.dart' as core;
import '../data/datasources/auth_remote_datasource.dart';
import '../data/datasources/auth_remote_datasource_impl.dart';
import '../data/datasources/auth_local_datasource.dart';
import '../data/datasources/auth_local_datasource_impl.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/usecases/login_usecase.dart';
import '../domain/usecases/login_with_google_usecase.dart';
import '../domain/usecases/get_current_user_usecase.dart';
import '../domain/usecases/logout_usecase.dart';
import '../domain/usecases/refresh_user_info_usecase.dart';
import '../domain/usecases/register_usecase.dart';
import '../domain/usecases/verify_email_otp_usecase.dart';
import '../domain/usecases/resend_verification_code_usecase.dart';
import '../domain/usecases/send_forgot_password_email_usecase.dart';
import '../domain/usecases/verify_forgot_password_otp_usecase.dart';
import '../domain/usecases/reset_password_usecase.dart';
import '../domain/usecases/activate_user_usecase.dart';
import '../presentation/viewmodels/auth_viewmodel.dart';
import '../presentation/viewmodels/register_viewmodel.dart';
import '../presentation/viewmodels/forgot_password_viewmodel.dart';

/// Initialize auth feature dependencies
Future<void> initAuthDependencies() async {
  final sl = core.sl;

  // Data sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(apiClient: sl<ApiClient>()),
  );
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sharedPreferences: sl()),
  );

  // Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => LoginWithGoogleUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => RefreshUserInfoUseCase(sl()));
  sl.registerLazySingleton(() => RegisterUseCase(sl()));
  sl.registerLazySingleton(() => VerifyEmailOTPUseCase(sl()));
  sl.registerLazySingleton(() => ResendVerificationCodeUseCase(sl()));
  sl.registerLazySingleton(() => SendForgotPasswordEmailUseCase(sl()));
  sl.registerLazySingleton(() => VerifyForgotPasswordOTPUseCase(sl()));
  sl.registerLazySingleton(() => ResetPasswordUseCase(sl()));
  sl.registerLazySingleton(() => ActivateUserUseCase(sl()));

  // ViewModels
  sl.registerFactory(() => AuthViewModel(
    loginUseCase: sl(),
    loginWithGoogleUseCase: sl(),
    getCurrentUserUseCase: sl(),
    logoutUseCase: sl(),
    refreshUserInfoUseCase: sl(),
  ));
  sl.registerFactory(() => RegisterViewModel(
    registerUseCase: sl(),
    verifyEmailOTPUseCase: sl(),
    resendVerificationCodeUseCase: sl(),
    activateUserUseCase: sl(),
    createProfileAutoUseCase: sl(),
  ));
  sl.registerFactory(() => ForgotPasswordViewModel(
    sendForgotPasswordEmailUseCase: sl(),
    verifyForgotPasswordOTPUseCase: sl(),
    resetPasswordUseCase: sl(),
  ));
}
