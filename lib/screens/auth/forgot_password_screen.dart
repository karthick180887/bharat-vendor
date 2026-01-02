import 'dart:ui';
import 'package:flutter/material.dart';
import '../../api_client.dart';
import '../../design_system.dart';
import '../../widgets/gradient_button.dart';
import 'verify_otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailPhoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
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
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailPhoneController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final input = _emailPhoneController.text.trim();
      final isEmail = input.contains('@');

      final api = VendorApiClient();
      final result = await api.requestPasswordReset(
        email: isEmail ? input : null,
        phone: isEmail ? null : input,
      );

      if (result.statusCode == 200 || result.statusCode == 201) {
        final data = result.data as Map<String, dynamic>?;
        final sentTo = data?['data']?['sentTo'] ?? 'your phone/email';
        
        setState(() {
          _successMessage = 'OTP sent to $sentTo';
        });

        // Navigate to OTP verification screen
        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => VerifyOtpScreen(
                  emailOrPhone: input,
                  isEmail: isEmail,
                ),
              ),
            );
          }
        }
      } else {
        setState(() => _errorMessage = result.message ?? "Failed to send OTP");
      }
    } catch (e) {
      setState(() => _errorMessage = "An error occurred: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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

                        // Lock Icon
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
                            Icons.lock_reset_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter your email or phone number to receive an OTP',
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

                                    // Success Message
                                    if (_successMessage != null)
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        margin: const EdgeInsets.only(bottom: 20),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.green.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.check_circle_outline,
                                                color: Colors.green, size: 20),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _successMessage!,
                                                style: const TextStyle(
                                                  color: Colors.green,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    // Email/Phone Field
                                    TextFormField(
                                      controller: _emailPhoneController,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 15),
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: InputDecoration(
                                        labelText: 'Email or Phone',
                                        labelStyle: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.6),
                                            fontSize: 14),
                                        prefixIcon: const Icon(
                                          Icons.person_outline_rounded,
                                          color: Colors.white60,
                                          size: 20,
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.08),
                                        contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 16),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide(
                                              color:
                                                  Colors.white.withValues(alpha: 0.15)),
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
                                          return 'Please enter your email or phone';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 28),

                                    // Send OTP Button
                                    GradientButton(
                                      text: 'Send OTP',
                                      icon: Icons.send_rounded,
                                      isLoading: _isLoading,
                                      onPressed: _handleRequestOtp,
                                    ),
                                    const SizedBox(height: 16),

                                    // Back to Login Link
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: Text(
                                        'Back to Login',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.7),
                                          fontSize: 14,
                                        ),
                                      ),
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
