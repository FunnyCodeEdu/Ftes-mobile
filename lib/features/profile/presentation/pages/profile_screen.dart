import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ftes/core/utils/text_styles.dart';
import 'package:ftes/core/constants/app_constants.dart';
import 'package:ftes/core/widgets/bottom_navigation_bar.dart';
import 'package:ftes/features/profile/presentation/pages/edit_profile_screen.dart';

import 'package:ftes/features/points/presentation/pages/invite_friends_screen.dart';
import 'package:ftes/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:ftes/features/auth/domain/entities/user.dart';
import 'package:ftes/features/profile/presentation/viewmodels/profile_viewmodel.dart';
import 'package:ftes/features/profile/domain/entities/profile.dart';
import 'package:ftes/features/profile/presentation/pages/terms_conditions_page.dart';
import 'package:ftes/core/utils/image_cache_helper.dart';
import 'package:ftes/core/widgets/3D/button_3d.dart';

class ProfileScreen extends StatefulWidget {
  final bool hideBottomNav;

  const ProfileScreen({super.key, this.hideBottomNav = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserInfo();
    });
  }

  void _loadUserInfo() async {
    try {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final profileViewModel = Provider.of<ProfileViewModel>(
        context,
        listen: false,
      );

      if (authViewModel.isLoggedIn && authViewModel.currentUser == null) {
        await authViewModel.refreshUserInfo();
      }

      if (authViewModel.isLoggedIn && authViewModel.currentUser != null) {
        final userId = authViewModel.currentUser!.id;
        await profileViewModel.loadProfileFromCache(userId);

        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }

        await profileViewModel.getProfileById(userId);
      } else {
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user info: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  String _getDisplayName(Profile? profile, User? user) {
    if (profile != null && profile.name.isNotEmpty) return profile.name;
    if (user != null) {
      if (user.fullName != null && user.fullName!.isNotEmpty)
        return user.fullName!;
      if (user.username != null && user.username!.isNotEmpty)
        return user.username!;
    }
    return 'Chưa có tên';
  }

  String _getDisplayEmail(Profile? profile, User? user) {
    if (profile != null && profile.email.isNotEmpty) return profile.email;
    return user?.email ?? 'Chưa có email';
  }

  String? _getDisplayAvatar(Profile? profile, User? user) {
    if (profile != null && profile.avatar.isNotEmpty) return profile.avatar;
    return user?.avatar;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Clean, light background
      appBar: AppBar(
        title: Text(
          'Hồ sơ',
          style: AppTextStyles.h3.copyWith(
            color: const Color(0xFF1E293B), // Dark slate
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading:
            false, // Ensure no back button dynamically appears if root
      ),
      body: SafeArea(
        child: Consumer2<AuthViewModel, ProfileViewModel>(
          builder: (context, authViewModel, profileViewModel, child) {
            final isLoadingInitial =
                _isInitializing ||
                (authViewModel.isLoading &&
                    profileViewModel.currentProfile == null) ||
                (profileViewModel.isLoading &&
                    profileViewModel.currentProfile == null);

            if (isLoadingInitial) {
              return const Center(child: CircularProgressIndicator());
            }

            return RefreshIndicator(
              onRefresh: () async {
                final userId = authViewModel.currentUser?.id;
                if (userId != null && userId.isNotEmpty) {
                  await profileViewModel.getProfileById(userId);
                }
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                children: [
                  _buildHeroSection(authViewModel, profileViewModel),
                  const SizedBox(height: 32),
                  _buildMenuSection(
                    title: 'Tài khoản',
                    items: [
                      _MenuItem(
                        icon: Icons.person_outline,
                        title: 'Chỉnh sửa thông tin',
                        onTap: () => _navigateTo(const EditProfileScreen()),
                      ),
                      _MenuItem(
                        icon: Icons.notifications_none_rounded,
                        title: 'Thông báo',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tính năng đang phát triển'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildMenuSection(
                    title: 'Tương tác',
                    items: [
                      _MenuItem(
                        icon: Icons.card_giftcard,
                        title: 'Mời bạn bè',
                        onTap: () => _navigateTo(const InviteFriendsScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildMenuSection(
                    title: 'Khác',
                    items: [
                      _MenuItem(
                        icon: Icons.gavel,
                        title: 'Điều khoản & Chính sách',
                        onTap: () => _navigateTo(const TermsConditionsPage()),
                      ),
                      _MenuItem(
                        icon: Icons.help_outline,
                        title: 'Trợ giúp & Hỗ trợ',
                        onTap: () {
                          // TODO: Implement Help/Support routing
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Chức năng đang phát triển'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildLogoutButton(),
                  const SizedBox(height: 48), // Bottom padding
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: widget.hideBottomNav
          ? null
          : const AppBottomNavigationBar(selectedIndex: 4),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  Widget _buildHeroSection(
    AuthViewModel authViewModel,
    ProfileViewModel profileViewModel,
  ) {
    final user = authViewModel.currentUser;
    final profile = profileViewModel.currentProfile;

    final displayName = _getDisplayName(profile, user);
    final displayEmail = _getDisplayEmail(profile, user);
    final displayAvatar = _getDisplayAvatar(profile, user);
    final role = (profile != null && profile.role.isNotEmpty)
        ? profile.role
        : (user?.role ?? '');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Avatar
        Container(
          height: 110,
          width: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: ClipOval(
            child: displayAvatar != null && displayAvatar.isNotEmpty
                ? ImageCacheHelper.cached(
                    displayAvatar,
                    fit: BoxFit.cover,
                    placeholder: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: const Icon(
                      Icons.person,
                      size: 50,
                      color: Color(0xFFCBD5E1),
                    ),
                  )
                : const Icon(Icons.person, size: 50, color: Color(0xFFCBD5E1)),
          ),
        ),
        const SizedBox(height: 16),
        // Name
        Text(
          displayName,
          style: AppTextStyles.h2.copyWith(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        // Email
        Text(
          displayEmail,
          style: AppTextStyles.body1.copyWith(
            color: const Color(0xFF64748B),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        // Role Badge (if exists)
        if (role.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF), // Light blue
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role,
              style: AppTextStyles.bodySmall.copyWith(
                color: const Color(0xFF3B82F6), // Blue
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMenuSection({
    required String title,
    required List<_MenuItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              fontSize: 12,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final int index = entry.key;
              final _MenuItem item = entry.value;
              final bool isLast = index == items.length - 1;

              return Column(
                children: [
                  ListTile(
                    onTap: item.onTap,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.icon,
                        color: const Color(0xFF475569),
                        size: 22,
                      ),
                    ),
                    title: Text(
                      item.title,
                      style: AppTextStyles.body1.copyWith(
                        color: const Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFFCBD5E1),
                      size: 24,
                    ),
                  ),
                  if (!isLast)
                    const Padding(
                      padding: EdgeInsets.only(
                        left: 56,
                      ), // Align divider with text
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFF1F5F9),
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlineButton3D(
        text: 'Đăng xuất',
        variant: Button3DVariant.outline,
        borderColor: const Color(0xFFEF4444), // Tailwind Red 500
        borderWidth: 1.5,
        borderRadius: 16,
        height: 54,
        width: double.infinity,
        onPressed: _showLogoutDialog,
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Đăng xuất',
            style: AppTextStyles.h3.copyWith(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Bạn có chắc chắn muốn đăng xuất?',
            style: AppTextStyles.body1.copyWith(
              color: const Color(0xFF64748B),
              fontSize: 15,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Hủy',
                style: AppTextStyles.body1.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444), // Red action button
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _handleLogout();
              },
              child: Text(
                'Đăng xuất',
                style: AppTextStyles.body1.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleLogout() async {
    try {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      await authViewModel.logout();

      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppConstants.routeSignIn,
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng xuất thành công!'),
            backgroundColor: Color(0xFF10B981), // Green
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đăng xuất thất bại: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  _MenuItem({required this.icon, required this.title, required this.onTap});
}
