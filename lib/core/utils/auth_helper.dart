import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../services/token_validator.dart';

/// Helper class for authentication operations
class AuthHelper {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static bool _isLoggingOut = false;

  /// Logout user and navigate to login page
  /// Clears both SharedPreferences tokens and TokenValidator cache
  static Future<void> logoutAndNavigateToLogin() async {
    if (_isLoggingOut) {
      debugPrint('AuthHelper: Logout already in progress, skipping...');
      return;
    }

    _isLoggingOut = true;

    try {
      debugPrint('AuthHelper: Logging out user...');

      // Clear SharedPreferences tokens
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(AppConstants.keyAccessToken),
        prefs.remove(AppConstants.keyRefreshToken),
        prefs.remove(AppConstants.keyUserId),
        prefs.remove(AppConstants.keyUserData),
      ]);

      // Clear token validator cache
      try {
        TokenValidator.getInstance(null).clearCache();
      } catch (_) {}

      debugPrint('AuthHelper: Auth data cleared');

      // Navigate to login page
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppConstants.routeSignIn,
          (route) => false,
        );
        debugPrint('AuthHelper: Navigated to login page');
      } else {
        debugPrint('AuthHelper: Navigator context not available');
      }
    } catch (e) {
      debugPrint('AuthHelper: Error during logout: $e');
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        _isLoggingOut = false;
      });
    }
  }
}

