import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Service để kiểm tra và thực hiện update ứng dụng qua Google Play
/// Chỉ hoạt động trên Android khi install qua Google Play
class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  /// Kiểm tra và thực hiện update ngay lập tức (Immediate Update)
  /// - Nếu có version mới -> bắt buộc user update
  /// - Nếu không có update hoặc thất bại -> cho phép tiếp tục
  Future<AppUpdateResult> checkAndUpdate() async {
    try {
      // Kiểm tra xem có update không
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // Có version mới -> thực hiện immediate update
        debugPrint('Phát hiện version mới: ${info.availableVersionCode}');
        return await InAppUpdate.performImmediateUpdate();
      }

      debugPrint('Không có update mới');
      return AppUpdateResult.success;
    } catch (e) {
      // Lỗi có thể do: không phải Android, không install qua Play, network...
      debugPrint('App update error: $e');
      return AppUpdateResult.inAppUpdateFailed;
    }
  }

  /// Kiểm tra update chỉ để hiển thị thông tin (không update)
  Future<AppUpdateInfo?> checkForUpdateInfo() async {
    try {
      return await InAppUpdate.checkForUpdate();
    } catch (e) {
      debugPrint('Check update info error: $e');
      return null;
    }
  }
}
