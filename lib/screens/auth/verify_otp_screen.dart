import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api_client.dart';
import '../../design_system.dart';
import '../../widgets/gradient_button.dart';
import 'reset_password_screen.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String emailOrPhone;
  final bool isEmail;

  const VerifyOtpScreen({
    super.key,
    required this.emailOrPhone,
    required this.isEmail,
  });

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  int _resendCountdown = 60;
  Timer? _resendTimer;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _animController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = VendorApiClient();
      final result = await api.verifyResetOtp(
        email: widget.isEmail ? widget.emailOrPhone : null,
        phone: widget.isEmail ? null : widget.emailOrPhone,
        otp: _otpController.text.trim(),
      );

      if (result.statusCode == 200 || result.statusCode == 201) {
        final data = result.data as Map<String, dynamic>?;
        final resetToken = data?['data']?['resetToken'] as String?;

        if (resetToken != null && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(resetToken: resetToken),
            ),
          );
        } else {
          setState(() => _errorMessage = "Invalid response from server");
        }
      } else {
        setState(() => _errorMessage = result.message ?? "Failed to verify OTP");
      }
    } catch (e) {
      setState(() => _errorMessage = "An error occurred: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final api = VendorApiClient();
      final result = await api.requestPasswordReset(
        email: widget.isEmail ? widget.emailOrPhone : null,
        phone: widget.isEmail ? null : widget.emailOrPhone,
      );

      if (result.statusCode == 200 || result.statusCode == 201) {
        _startResendTimer();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP resent successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() => _errorMessage = result.message ?? "Failed to resend OTP");
      }
    } catch (e) {
      setState(() => _errorMessage = "An error occurred: $e");
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.darkGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Back Button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.arrow_back_ios_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // OTP Icon
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.pin_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Verify OTP',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter the 6-digit OTP sent to\n${widget.emailOrPhone}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Glass Card Form
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Error Message
                                    if (_errorMessage != null)
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        margin: const EdgeInsets.only(bottom: 20),
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: AppColors.error.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.error_outline,
                                                color: Colors.redAccent, size: 20),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _errorMessage!,
                                                style: const TextStyle(
                                                  color: Colors.redAccent,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    // OTP Field
                                    TextFormField(
                                      controller: _otpController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        letterSpacing: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      maxLength: 6,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: InputDecoration(
                                        hintText: '• • • • • •',
                                        hintStyle: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.3),
                                          fontSize: 24,
                                          letterSpacing: 8,
                                        ),
                                        counterText: '',
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.08),
                                        contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 20),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide(
                                              color: Colors.white.withValues(alpha: 0.15)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                              color: AppColors.accent, width: 1.5),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide:
                                              const BorderSide(color: AppColors.error),
                                        ),
                                        errorStyle:
                                            const TextStyle(color: Colors.redAccent),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Please enter the OTP';
                                        }
                                        if (value.length != 6) {
                                          return 'OTP must be 6 digits';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 28),

                                    // Verify Button
                                    GradientButton(
                                      text: 'Verify OTP',
                                      icon: Icons.verified_rounded,
                                      isLoading: _isLoading,
                                      onPressed: _handleVerifyOtp,
                                    ),
                                    const SizedBox(height: 20),

                                    // Resend OTP
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Didn't receive the OTP? ",
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.6),
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (_resendCountdown > 0)
                                          Text(
                                            'Resend in ${_resendCountdown}s',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.4),
                                              fontSize: 14,
                                            ),
                                          )
                                        else
                                          GestureDetector(
                                            onTap: _isResending ? null : _handleResendOtp,
                                            child: Text(
                                              _isResending ? 'Sending...' : 'Resend',
                                              style: const TextStyle(
                                                color: AppColors.accent,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
