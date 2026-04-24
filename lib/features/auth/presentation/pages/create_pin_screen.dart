import 'package:flutter/material.dart';
import 'package:ftes/core/utils/colors.dart';
import 'package:ftes/core/utils/text_styles.dart';
import 'package:ftes/core/constants/app_constants.dart';
import 'package:ftes/core/di/injection_container.dart' as di;
import 'package:ftes/features/auth/presentation/viewmodels/register_viewmodel.dart';

class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({super.key}); // Force rebuild

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  List<String> _pinDigits = ['', '', '', '', '', '']; // 6 digits
  int _currentIndex = 0;
  int _resendCountdown = 59;
  bool _isResendEnabled = false;

  @override
  void initState() {
    super.initState();
    // Ensure _pinDigits has exactly 6 elements
    _pinDigits = List.filled(6, '');
    _startCountdown();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Don't send verification code automatically
    // Backend already sends OTP during registration
    // Only send when user clicks "Resend" button
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          if (_resendCountdown > 0) {
            _resendCountdown--;
          } else {
            _isResendEnabled = true;
          }
        });
      }
      return mounted && _resendCountdown > 0;
    });
  }

  void _resendPin() async {
    setState(() {
      _resendCountdown = 59;
      _isResendEnabled = false;
    });
    _startCountdown();
    
    // Send verification code
    await _sendVerificationCode();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 25),
              // Navigation bar with back button and title
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Xác thực OTP',
                    style: AppTextStyles.heading1.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 80),
              // Description text
              Center(
                child: Text(
                  'Vui lòng nhập mã xác thực OTP được gửi đến email của bạn!',
                  style: AppTextStyles.body1.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 80),
              // PIN input fields
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    // Safety check to prevent index out of range
                    if (index >= _pinDigits.length) {
                      return SizedBox(width: 50, height: 60);
                    }
                    return Container(
                      margin: EdgeInsets.only(right: index < 5 ? 6 : 0),
                      width: 50,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: _currentIndex == index
                            ? Border.all(color: AppColors.primary, width: 2)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _pinDigits[index].isEmpty ? '*' : _pinDigits[index],
                          style: AppTextStyles.body1.copyWith(
                            color: const Color(0xFF505050),
                            fontSize: _pinDigits[index].isEmpty ? 30 : 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 70),
              // Continue button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isPinComplete() ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.textSecondary.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Xác thực',
                        style: AppTextStyles.button.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Resend PIN section
              Center(
                child: _isResendEnabled
                    ? GestureDetector(
                        onTap: _resendPin,
                        child: Text(
                          'Gửi lại mã OTP',
                          style: AppTextStyles.body1.copyWith(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : Text(
                        'Resend PIN in ${_resendCountdown}s',
                        style: AppTextStyles.body1.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(height: 30),
              // Number pad
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                      // Row 1: 1, 2, 3
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _NumberButton('1'),
                          const SizedBox(width: 60),
                          _NumberButton('2'),
                          const SizedBox(width: 60),
                          _NumberButton('3'),
                        ],
                      ),
                      const SizedBox(height: 40),
                      // Row 2: 4, 5, 6
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _NumberButton('4'),
                          const SizedBox(width: 60),
                          _NumberButton('5'),
                          const SizedBox(width: 60),
                          _NumberButton('6'),
                        ],
                      ),
                      const SizedBox(height: 40),
                      // Row 3: 7, 8, 9
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _NumberButton('7'),
                          const SizedBox(width: 60),
                          _NumberButton('8'),
                          const SizedBox(width: 60),
                          _NumberButton('9'),
                        ],
                      ),
                      const SizedBox(height: 40),
                      // Row 4: *, 0, backspace
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _NumberButton('*'),
                          const SizedBox(width: 60),
                          _NumberButton('0'),
                          const SizedBox(width: 60),
                          _BackspaceButton(),
                        ],
                      ),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isPinComplete() {
    return _pinDigits.every((digit) => digit.isNotEmpty);
  }

  void _onNumberPressed(String number) {
    if (_currentIndex < 6) {
      setState(() {
        _pinDigits[_currentIndex] = number;
        _currentIndex++;
      });
    }
  }

  void _onBackspacePressed() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _pinDigits[_currentIndex] = '';
      });
    }
  }

  Future<void> _sendVerificationCode() async {
    // Get contact info from route arguments
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final contactInfo = args?['contactInfo'] as String?;
    final method = args?['method'] as String?;
    
    if (contactInfo != null && method == 'email') {
      try {
        final vm = di.sl<RegisterViewModel>();
        await vm.resendCode(contactInfo);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mã xác thực đã được gửi đến email của bạn!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi gửi mã xác thực: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _continue() async {
    if (_isPinComplete()) {
      final pin = _pinDigits.join();
      
      // Validate PIN
      if (pin.length != 6) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng nhập đầy đủ 6 chữ số'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // Get contact info from route arguments
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final contactInfo = args?['contactInfo'] as String?;
      final method = args?['method'] as String?;
      
      if (contactInfo != null && method == 'email') {
        // Verify email code via RegisterViewModel
        final vm = di.sl<RegisterViewModel>();
        final otp = int.tryParse(pin) ?? -1;
        final success = otp >= 0 ? await vm.verifyOTP(contactInfo, otp) : false;
        
        if (success != null) {
          if (mounted) {
            Navigator.pushReplacementNamed(context, AppConstants.routeCongratulations);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Mã xác thực không đúng. Vui lòng thử lại.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppConstants.routeCongratulations);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng nhập đầy đủ 6 chữ số'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _NumberButton extends StatelessWidget {
  final String number;

  const _NumberButton(this.number);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Access the parent state through context
        final state = context.findAncestorStateOfType<_CreatePinScreenState>();
        state?._onNumberPressed(number);
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Center(
          child: Text(
            number,
            style: AppTextStyles.body1.copyWith(
              color: const Color(0xFF505050),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _BackspaceButton extends StatelessWidget {
  const _BackspaceButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Access the parent state through context
        final state = context.findAncestorStateOfType<_CreatePinScreenState>();
        state?._onBackspacePressed();
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: const Center(
          child: Icon(
            Icons.backspace_outlined,
            color: Color(0xFF505050),
            size: 20,
          ),
        ),
      ),
    );
  }
}
