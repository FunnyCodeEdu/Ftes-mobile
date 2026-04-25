import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../error/exceptions.dart';
import '../services/token_validator.dart';

/// Service to manage token refresh logic
/// Implements automatic token refresh on 401 responses
class TokenService {
  final Dio _dio;
  final SharedPreferences _sharedPreferences;
  late final TokenValidator _tokenValidator;

  bool _isRefreshing = false;
  final List<_QueuedRequest> _pendingRequests = [];

  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyDeviceId = 'device_id';

  TokenService({
    required Dio dio,
    required SharedPreferences sharedPreferences,
  })  : _dio = dio,
        _sharedPreferences = sharedPreferences {
    _tokenValidator = TokenValidator.getInstance(dio);
  }

  SharedPreferences get sharedPreferences => _sharedPreferences;

  /// Expose token validator for cache clearing
  TokenValidator get tokenValidator => _tokenValidator;

  /// Get device ID (generate if not exists)
  Future<String> getOrCreateDeviceId() async {
    String? deviceId = _sharedPreferences.getString(_keyDeviceId);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = _generateDeviceId();
      await _sharedPreferences.setString(_keyDeviceId, deviceId);
    }
    return deviceId;
  }

  String _generateDeviceId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = List.generate(8, (i) => _chars[(now + i * 7) % _chars.length]).join();
    return 'mobile_${now}_$random';
  }

  static const String _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';

  /// Cache tokens from login/refresh response
  Future<void> cacheTokens({
    required String accessToken,
    required String refreshToken,
    String? deviceId,
  }) async {
    await Future.wait([
      _sharedPreferences.setString(_keyAccessToken, accessToken),
      _sharedPreferences.setString(_keyRefreshToken, refreshToken),
      if (deviceId != null && deviceId.isNotEmpty)
        _sharedPreferences.setString(_keyDeviceId, deviceId),
    ]);
    _tokenValidator.clearCache();
    debugPrint('TokenService: Tokens cached successfully');
  }

  /// Get cached access token
  String? getAccessToken() {
    return _sharedPreferences.getString(_keyAccessToken);
  }

  /// Get cached refresh token
  String? getRefreshToken() {
    return _sharedPreferences.getString(_keyRefreshToken);
  }

  /// Clear all tokens
  Future<void> clearTokens() async {
    await Future.wait([
      _sharedPreferences.remove(_keyAccessToken),
      _sharedPreferences.remove(_keyRefreshToken),
    ]);
    _tokenValidator.clearCache();
    debugPrint('TokenService: Tokens cleared');
  }

  /// Refresh access token using refresh token
  /// Returns new access token on success, throws on failure
  Future<String> refreshAccessToken() async {
    if (_isRefreshing) {
      debugPrint('TokenService: Refresh already in progress, waiting...');
      return _waitForRefresh();
    }

    _isRefreshing = true;

    try {
      final refreshToken = getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        throw const AuthException('No refresh token available');
      }

      final deviceId = await getOrCreateDeviceId();
      debugPrint('TokenService: Attempting to refresh access token...');

      final response = await _dio.post(
        '${AppConstants.baseUrl}${AppConstants.refreshTokenEndpoint}',
        data: {
          'refreshToken': refreshToken,
          'deviceId': deviceId,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      debugPrint('TokenService: Refresh response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        final result = data['result'] as Map<String, dynamic>?;
        if (result == null) {
          throw const AuthException('Invalid refresh response');
        }

        final newAccessToken = result['accessToken'] as String?;
        final newRefreshToken = result['refreshToken'] as String?;
        final newDeviceId = result['deviceId'] as String?;

        if (newAccessToken == null || newAccessToken.isEmpty) {
          throw const AuthException('No access token in refresh response');
        }

        await cacheTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken ?? refreshToken,
          deviceId: newDeviceId,
        );

        debugPrint('TokenService: Token refreshed successfully');
        _processPendingRequests(newAccessToken);
        return newAccessToken;
      } else {
        final message = _extractErrorMessage(response.data);
        throw AuthException('Refresh failed: $message');
      }
    } on DioException catch (e) {
      debugPrint('TokenService: Refresh DioException: ${e.message}');
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        debugPrint('TokenService: Refresh token expired/invalid, forcing logout');
        throw const AuthException('Session expired. Please login again.');
      }
      throw AuthException('Network error during refresh: ${e.message}');
    } catch (e) {
      debugPrint('TokenService: Refresh error: $e');
      _processPendingRequestsWithError(e);
      rethrow;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Wait for ongoing refresh to complete
  Future<String> _waitForRefresh() async {
    int attempts = 0;
    while (_isRefreshing && attempts < 30) {
      await Future.delayed(const Duration(milliseconds: 200));
      attempts++;
    }
    final token = getAccessToken();
    if (token != null && token.isNotEmpty) {
      return token;
    }
    throw const AuthException('Failed to get new token');
  }

  /// Process pending requests with new token
  void _processPendingRequests(String newToken) {
    debugPrint('TokenService: Processing ${_pendingRequests.length} pending requests');
    for (final request in _pendingRequests) {
      request.completer.complete(newToken);
    }
    _pendingRequests.clear();
  }

  /// Process pending requests with error
  void _processPendingRequestsWithError(Object error) {
    debugPrint('TokenService: Processing pending requests with error');
    for (final request in _pendingRequests) {
      request.completer.completeError(error);
    }
    _pendingRequests.clear();
  }

  /// Queue a request to retry with new token
  Future<String> queueRequest() async {
    final completer = Completer<String>();
    _pendingRequests.add(_QueuedRequest(completer));
    return completer.future;
  }

  String _extractErrorMessage(dynamic data) {
    if (data == null) return 'Unknown error';
    if (data is Map) {
      final result = data['result'];
      if (result is Map) {
        final msg = result['message'];
        if (msg is String) return msg;
      }
      final msg = data['message'];
      if (msg is String) return msg;
      final msgDto = data['messageDTO'];
      if (msgDto is Map) {
        final msg2 = msgDto['message'];
        if (msg2 is String) return msg2;
      }
    }
    return 'Unknown error';
  }
}

class _QueuedRequest {
  final Completer<String> completer;
  _QueuedRequest(this.completer);
}
