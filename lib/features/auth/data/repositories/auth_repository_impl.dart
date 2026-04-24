import 'dart:async';
import 'package:dartz/dartz.dart';
// import 'package:flutter_web_auth/flutter_web_auth.dart';
import 'package:ftes/core/error/exceptions.dart';
import 'package:ftes/core/error/failures.dart';
import 'package:ftes/core/network/network_info.dart';
import 'package:ftes/features/auth/domain/constants/auth_constants.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, User>> login(String email, String password) async {
    if (await networkInfo.isConnected) {
      try {
        final authResponse = await remoteDataSource.login(email, password);
        
        // Cache access token and user ID (critical, await them)
        await Future.wait([
          localDataSource.cacheAccessToken(authResponse.accessToken),
          if (authResponse.userId != null && authResponse.userId!.isNotEmpty)
            localDataSource.cacheUserId(authResponse.userId!),
        ]);

        // Fetch user info after login (like Google login)
        // If getMyInfo fails, return placeholder user (user info can be fetched later)
        try {
          final userInfo = await remoteDataSource.getMyInfo();
          
          // Cache user info with TTL (non-critical, don't block)
          unawaited(
            localDataSource
                .cacheUserWithTTL(userInfo, AuthConstants.userCacheTTL)
                .catchError((_) {}),
          );

          return Right(userInfo);
        } catch (e) {
          // If getMyInfo fails (e.g., endpoint not available), return placeholder
          // User info can be fetched later when needed
          final placeholderUser = UserModel(
            id: authResponse.userId ?? 'temp',
            email: email,
          );
          return Right(placeholderUser);
        }
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } on AuthException catch (e) {
        return Left(ServerFailure(e.message)); // AuthException can be treated as a specific ServerFailure
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure(AuthConstants.errorNoInternet));
    }
  }

  @override
  Future<Either<Failure, User>> loginWithGoogle() async {
    if (await networkInfo.isConnected) {
      try {
        // Step 1: Get authorization code from Google OAuth
        final authCode = await _getGoogleAuthCode();
        if (authCode == null) {
          return const Left(ServerFailure(AuthConstants.errorGoogleCancelled));
        }
        
        // Step 2: Exchange code with backend
        final authResponse = await remoteDataSource.loginWithGoogle(authCode, isAdmin: false);
        
        // Step 3: Parallel execution - Cache access token and fetch user info simultaneously
        final results = await Future.wait([
          localDataSource.cacheAccessToken(authResponse.accessToken), // Critical operation
          remoteDataSource.getMyInfo(), // Can run in parallel
        ]);
        
        final userInfo = results[1] as UserModel;
        
        // Cache user info (non-critical, don't block)
        unawaited(
          localDataSource
              .cacheUserWithTTL(userInfo, AuthConstants.userCacheTTL)
              .catchError((_) {}),
        );
        
        return Right(userInfo);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } on AuthException catch (e) {
        return Left(ServerFailure(e.message));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure(AuthConstants.errorNoInternet));
    }
  }

  Future<String?> _getGoogleAuthCode() async {
    try {
      // final googleAuthUrl = Uri.https('accounts.google.com', '/o/oauth2/auth', {
      //   'client_id': EnvConfig.googleClientId,
      //   'redirect_uri': EnvConfig.redirectUri,
      //   'response_type': 'code',
      //   'scope': 'openid email profile',
      // });

      // TODO: Fix flutter_web_auth namespace issue for mobile
      // final result = await FlutterWebAuth.authenticate(
      //   url: googleAuthUrl.toString(),
      //   callbackUrlScheme: 'http',
      // );
      // 
      // final code = Uri.parse(result).queryParameters['code'];
      // return code;
      
      // Temporary fallback - return null for now
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    try {
      // 1. Try cache first (even offline) - with TTL check
      final cached = await localDataSource.getCachedUserWithTTL(AuthConstants.userCacheTTL);
      if (cached != null) {
        return Right(cached);
      }

      // 2. Check network connection
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(AuthConstants.errorNoInternet));
      }

      // 3. Fetch from network
      final remoteUser = await remoteDataSource.getMyInfo();

      // 4. Cache for next time (async, don't block)
      unawaited(
        localDataSource
            .cacheUserWithTTL(remoteUser, AuthConstants.userCacheTTL)
            .catchError((_) {}),
      );

      return Right(remoteUser);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('${AuthConstants.errorGetUserInfo}: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await remoteDataSource.logout();
      await localDataSource.clearAuthData();
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on AuthException catch (e) {
      return Left(ServerFailure(e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, User>> register(String username, String email, String password) async {
    if (await networkInfo.isConnected) {
      try {
        final response = await remoteDataSource.register(username, email, password);
        if (response.success && response.result != null) {
          return Right(response.result!);
        } else {
          return Left(ServerFailure(response.messageDTO?.message ?? AuthConstants.errorRegisterFailed));
        }
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } on AuthException catch (e) {
        return Left(ServerFailure(e.message));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure(AuthConstants.errorNoInternet));
    }
  }

  @override
  Future<Either<Failure, String>> verifyEmailOTP(String email, int otp) async {
    if (await networkInfo.isConnected) {
      try {
        final response = await remoteDataSource.verifyEmailOTP(email, otp);
        if (response.success && response.result != null) {
          // Cache the access token
          await localDataSource.cacheAccessToken(response.result!.accessToken);
          return Right(response.result!.accessToken);
        } else {
          return Left(ServerFailure(response.messageDTO?.message ?? AuthConstants.errorVerifyOTPFailed));
        }
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } on AuthException catch (e) {
        return Left(ServerFailure(e.message));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure(AuthConstants.errorNoInternet));
    }
  }

  @override
  Future<Either<Failure, void>> resendVerificationCode(String email) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.resendVerificationCode(email);
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } on AuthException catch (e) {
        return Left(ServerFailure(e.message));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure(AuthConstants.errorNoInternet));
    }
  }

  @override
  Future<Either<Failure, void>> sendForgotPasswordEmail(String email) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.sendForgotPasswordEmail(email);
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } on AuthException catch (e) {
        return Left(ServerFailure(e.message));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure(AuthConstants.errorNoInternet));
    }
  }

  @override
  Future<Either<Failure, String>> verifyForgotPasswordOTP(String email, int otp) async {
    if (await networkInfo.isConnected) {
      try {
        final response = await remoteDataSource.verifyForgotPasswordOTP(email, otp);
        return Right(response.result.accessToken);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } on AuthException catch (e) {
        return Left(ServerFailure(e.message));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure(AuthConstants.errorNoInternet));
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword(String password, String accessToken) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.resetPassword(password, accessToken);
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } on AuthException catch (e) {
        return Left(ServerFailure(e.message));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure(AuthConstants.errorNoInternet));
    }
  }

  @override
  Future<Either<Failure, void>> invalidateUserCache() async {
    try {
      await localDataSource.clearUser();
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure('${AuthConstants.errorCache}: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> activateUser(String accessToken) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.activateUser(accessToken);
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } on AuthException catch (e) {
        return Left(ServerFailure(e.message));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure(AuthConstants.errorNoInternet));
    }
  }
}