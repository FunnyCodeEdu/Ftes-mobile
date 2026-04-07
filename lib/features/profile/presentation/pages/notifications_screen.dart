import 'package:flutter/material.dart';
import 'package:ftes/core/utils/text_styles.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Notification settings state
  bool _specialOffers = true;
  bool _sound = true;
  bool _vibrate = false;
  bool _generalNotification = true;
  bool _promoDiscount = false;
  bool _paymentOptions = true;
  bool _appUpdate = true;
  bool _newServiceAvailable = false;
  bool _newTipsAvailable = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      body: SafeArea(
        child: Column(
          children: [
            // Status Bar Space
            const SizedBox(height: 25),

            // Navigation Bar
            _buildNavigationBar(),

            const SizedBox(height: 20),

            // Notification Settings
            Expanded(child: _buildNotificationSettings()),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 35),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Color(0xFF202244),
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Thông báo',
            style: AppTextStyles.heading1.copyWith(
              color: const Color(0xFF202244),
              fontSize: 21,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNotificationItem(
            title: 'Ưu đãi đặc biệt',
            value: _specialOffers,
            onChanged: (value) {
              setState(() {
                _specialOffers = value;
              });
            },
          ),

          const SizedBox(height: 40),

          _buildNotificationItem(
            title: 'Âm thanh',
            value: _sound,
            onChanged: (value) {
              setState(() {
                _sound = value;
              });
            },
          ),

          const SizedBox(height: 40),

          _buildNotificationItem(
            title: 'Rung',
            value: _vibrate,
            onChanged: (value) {
              setState(() {
                _vibrate = value;
              });
            },
          ),

          const SizedBox(height: 40),

          _buildNotificationItem(
            title: 'Thông báo chung',
            value: _generalNotification,
            onChanged: (value) {
              setState(() {
                _generalNotification = value;
              });
            },
          ),

          const SizedBox(height: 40),

          _buildNotificationItem(
            title: 'Khuyến mãi & Giảm giá',
            value: _promoDiscount,
            onChanged: (value) {
              setState(() {
                _promoDiscount = value;
              });
            },
          ),

          const SizedBox(height: 40),

          _buildNotificationItem(
            title: 'Tùy chọn thanh toán',
            value: _paymentOptions,
            onChanged: (value) {
              setState(() {
                _paymentOptions = value;
              });
            },
          ),

          const SizedBox(height: 40),

          _buildNotificationItem(
            title: 'Cập nhật ứng dụng',
            value: _appUpdate,
            onChanged: (value) {
              setState(() {
                _appUpdate = value;
              });
            },
          ),

          const SizedBox(height: 40),

          _buildNotificationItem(
            title: 'Dịch vụ mới có sẵn',
            value: _newServiceAvailable,
            onChanged: (value) {
              setState(() {
                _newServiceAvailable = value;
              });
            },
          ),

          const SizedBox(height: 40),

          _buildNotificationItem(
            title: 'Mẹo mới có sẵn',
            value: _newTipsAvailable,
            onChanged: (value) {
              setState(() {
                _newTipsAvailable = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTextStyles.body1.copyWith(
            color: const Color(0xFF202244),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        _buildToggleSwitch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildToggleSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tính năng đang phát triển')),
        );
      },
      child: Container(
        width: 50,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F1FF),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: const Color(0xFFB4BDC4).withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            if (value)
              Positioned(
                left: 2,
                top: 2,
                bottom: 2,
                child: Container(
                  width: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0961F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              )
            else
              Positioned(
                right: 2,
                top: 2,
                bottom: 2,
                child: Container(
                  width: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F1FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
