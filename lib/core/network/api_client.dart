import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../error/exceptions.dart';
import '../constants/app_constants.dart';
import '../services/token_validator.dart';
import '../services/token_service.dart';
import '../utils/auth_helper.dart';

/// API Client using Dio for HTTP requests
class ApiClient {
  final Dio _dio;
  final SharedPreferences _sharedPreferences;
  late final TokenService _tokenService;

  // Expose dio and sharedPreferences for external URL calls (e.g., video stream server)
  Dio get dio => _dio;
  SharedPreferences get sharedPreferences => _sharedPreferences;

  ApiClient({required Dio dio, required SharedPreferences sharedPreferences})
      : _dio = dio, _sharedPreferences = sharedPreferences {
    _tokenService = TokenService(dio: dio, sharedPreferences: sharedPreferences);
    _setupDio();
    _setupInterceptors();
  }

  TokenService get tokenService => _tokenService;

  void _setupDio() {
    _dio.options.baseUrl = AppConstants.baseUrl;
    _dio.options.connectTimeout = AppConstants.connectTimeout;
    _dio.options.receiveTimeout = AppConstants.receiveTimeout;
    _dio.options.headers['Content-Type'] = 'application/json';
  }

  /// Public endpoints that do not require authentication
  static const List<String> _publicEndpoints = [
    '/api/auth/token',
    '/api/users/registration',
    '/api/auth/outbound/authentication',
    '/api/users/mail/forgot-password',
    '/api/users/mail/resend-verify-code',
    '/api/auth/verify-email-code',
    '/api/users/reset-password',
    '/api/auth/refresh', // Token refresh
    '/api/auth/introspect',
  ];

  /// Auth endpoints - requests to these will NOT trigger refresh attempts
  static const List<String> _authEndpoints = [
    '/api/auth/token',
    '/api/auth/refresh',
    '/api/auth/introspect',
    '/api/auth/logout',
  ];

  /// Base paths that need auth (endpoint base, not full path with IDs)
  static const List<String> _authBasePaths = [
    '/api/users/active-user',
  ];

  /// Token validator (delegated from TokenService)
  TokenValidator get _tokenValidator => _tokenService.tokenValidator;

  /// Flag to prevent multiple logout attempts
  bool _isLoggingOut = false;

  /// Check if endpoint requires authentication
  bool _requiresAuthentication(String path) {
    // Normalize path for comparison
    final normalizedPath = _normalizePath(path);
    return !_publicEndpoints.contains(normalizedPath) &&
        !_authBasePaths.any((p) => normalizedPath.startsWith(p));
  }

  /// Normalize path by removing trailing segments for endpoints with path params
  String _normalizePath(String path) {
    // Handle detail endpoints: /api/courses/detail/slug -> /api/courses/detail
    // Handle profile view: /api/profiles/view/userId -> /api/profiles/view
    final segments = path.split('/');
    if (segments.length > 3) {
      final basePath = segments.take(3).join('/');
      const detailBases = [
        '/api/courses/detail',
        '/api/lessons/detail',
        '/api/feedbacks/course',
        '/api/profiles/view',
        '/api/courses/creator',
      ];
      if (detailBases.contains(basePath)) {
        return basePath;
      }
    }
    return path;
  }

  /// Check if endpoint is an auth endpoint (avoid infinite refresh loops)
  bool _isAuthEndpoint(String path) {
    final normalizedPath = _normalizePath(path);
    return _authEndpoints.contains(normalizedPath);
  }

  void _setupInterceptors() {
    _dio.interceptors.addAll([
      // Authentication interceptor
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_requiresAuthentication(options.path)) {
            final token = _tokenService.getAccessToken();
            if (token != null) {
              debugPrint('ApiClient: Adding Bearer token: ${token.substring(0, min(20, token.length))}...');
              options.headers['Authorization'] = 'Bearer $token';
            } else {
              debugPrint('ApiClient: No access token, request without auth');
            }
          } else {
            debugPrint('ApiClient: Public endpoint: ${options.path}');
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 Unauthorized - attempt token refresh
          if (error.response?.statusCode == 401) {
            // Never refresh for auth endpoints or when already logging out
            if (_isAuthEndpoint(error.requestOptions.path) || _isLoggingOut) {
              debugPrint('ApiClient: Auth endpoint 401 or logging out, pass through');
              return handler.next(error);
            }

            debugPrint('ApiClient: Got 401, attempting token refresh...');

            try {
              // Attempt to refresh the token
              final newToken = await _tokenService.refreshAccessToken();

              // Retry the original request with new token
              debugPrint('ApiClient: Token refreshed, retrying request...');
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newToken';

              final response = await _dio.fetch(opts);
              return handler.resolve(response);
            } on AuthException {
              // Refresh failed (token expired), force logout
              debugPrint('ApiClient: Token refresh failed, forcing logout...');
              _isLoggingOut = true;
              unawaited(_handleTokenExpired());
              return handler.next(error);
            } catch (e) {
              debugPrint('ApiClient: Refresh error: $e');
              return handler.next(error);
            }
          }

          // Handle 403 Forbidden - token may be revoked
          if (error.response?.statusCode == 403) {
            if (!_isAuthEndpoint(error.requestOptions.path) && !_isLoggingOut) {
              debugPrint('ApiClient: Got 403, token may be revoked, logging out...');
              _isLoggingOut = true;
              unawaited(_handleTokenExpired());
            }
          }

          return handler.next(error);
        },
      ),

      // Logging interceptor
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        error: true,
        logPrint: (o) => debugPrint('ApiClient: $o'),
      ),

      // Error handling interceptor
      InterceptorsWrapper(
        onError: (error, handler) {
          AppException appException;

          if (error.response != null) {
            final statusCode = error.response!.statusCode;
            String message = 'Unknown error';
            if (error.response!.data != null) {
              final data = error.response!.data;
              if (data is Map) {
                final msgDto = data['messageDTO'];
                if (msgDto is Map) {
                  message = msgDto['message'] ?? message;
                } else {
                  message = data['message'] ?? message;
                }
              }
            }

            switch (statusCode) {
              case 400:
                appException = ValidationException(message);
                break;
              case 401:
                appException = AuthException('Unauthorized: $message');
                break;
              case 403:
                appException = AuthException('Forbidden: $message');
                break;
              case 404:
                appException = ServerException('Not found: $message');
                break;
              case 500:
                appException = ServerException('Server error: $message');
                break;
              default:
                appException = ServerException('HTTP $statusCode: $message');
            }
          } else {
            String errorMessage;
            if (error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.receiveTimeout ||
                error.type == DioExceptionType.sendTimeout) {
              errorMessage = 'Connection timeout';
            } else if (error.type == DioExceptionType.connectionError) {
              errorMessage = 'No internet connection';
            } else if (error.type == DioExceptionType.cancel) {
              errorMessage = 'Request cancelled';
            } else {
              errorMessage = error.message ?? 'Unknown network error';
            }
            appException = NetworkException(errorMessage);
          }

          return handler.reject(DioException(
            requestOptions: error.requestOptions,
            error: appException,
            response: error.response,
            type: error.type,
          ));
        },
      ),
    ]);
  }

  /// GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Handle token expired - logout and navigate to login
  Future<void> _handleTokenExpired() async {
    try {
      await _tokenService.clearTokens();
      await AuthHelper.logoutAndNavigateToLogin();
    } catch (e) {
      debugPrint('ApiClient: Error during token expiration: $e');
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        _isLoggingOut = false;
      });
    }
  }

  /// Clear token cache (useful after login/logout)
  void clearTokenCache() {
    _tokenValidator.clearCache();
  }

  /// Handle and convert errors to appropriate exceptions
  Exception _handleError(dynamic error) {
    if (error is AppException) {
      return error;
    } else if (error is DioException) {
      if (error.error is AppException) {
        return error.error as AppException;
      }
      return NetworkException('Network error: ${error.message ?? 'Unknown'}');
    } else {
      return ServerException('Unexpected error: $error');
    }
  }
}

