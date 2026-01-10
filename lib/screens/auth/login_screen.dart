import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../api_client.dart';
import '../../design_system.dart';
import '../../widgets/gradient_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main_layout.dart';
import '../../services/firebase_messaging_service.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
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
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final input = _emailPhoneController.text.trim();
      final password = _passwordController.text;
      final isEmail = input.contains('@');

      final api = VendorApiClient();
      final result = await api.login(
        email: isEmail ? input : null,
        phone: isEmail ? null : input,
        password: password,
      );

      if (result.statusCode == 200 || result.statusCode == 201) {
        if (result.data is! Map<String, dynamic>) {
          setState(() => _errorMessage = "Unexpected response format");
          return;
        }
        final responseData = result.data as Map<String, dynamic>;
        final innerData = responseData['data'] as Map<String, dynamic>?;
        final token = (innerData?['token'] ?? responseData['token']) as String?;

        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('vendor_token', token);

          try {
            final parts = token.split('.');
            if (parts.length == 3) {
              final payload = parts[1];
              final normalized = base64Url.normalize(payload);
              final resp = utf8.decode(base64Url.decode(normalized));
              final payloadMap = json.decode(resp);

              if (payloadMap is Map<String, dynamic>) {
                final adminId = payloadMap['adminId']?.toString();
                final vendorId = payloadMap['vendorId']?.toString();

                if (adminId != null) await prefs.setString('admin_id', adminId);
                if (vendorId != null) await prefs.setString('vendor_id', vendorId);
                
                // Register FCM token now that we have credentials
                await FirebaseMessagingService().registerToken();
              }
            }
          } catch (e) {
            debugPrint('Error decoding token: $e');
          }

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainLayout()),
            );
          }
        } else {
          setState(() => _errorMessage = "Login succeeded but no token returned.");
        }
      } else {
        setState(() => _errorMessage = result.message ?? "Login failed");
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
                        // Logo and Header
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
                          child: ClipOval(
                            child: Image.asset(
                              'assets/icon/logo.jpeg',
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.local_taxi_rounded,
                                  size: 48,
                                  color: Colors.white,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to your vendor account',
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

                                    // Email/Phone Field
                                    _buildTextField(
                                      controller: _emailPhoneController,
                                      label: 'Email or Phone',
                                      icon: Icons.person_outline_rounded,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Please enter your email or phone';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 18),

                                    // Password Field
                                    _buildTextField(
                                      controller: _passwordController,
                                      label: 'Password',
                                      icon: Icons.lock_outline_rounded,
                                      obscureText: _obscurePassword,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_rounded
                                              : Icons.visibility_rounded,
                                          color: Colors.white60,
                                          size: 20,
                                        ),
                                        onPressed: () => setState(
                                            () => _obscurePassword = !_obscurePassword),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your password';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 28),

                                    // Login Button
                                    GradientButton(
                                      text: 'Sign In',
                                      icon: Icons.login_rounded,
                                      isLoading: _isLoading,
                                      onPressed: _handleLogin,
                                    ),
                                    const SizedBox(height: 16),

                                    // Forgot Password Link
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const ForgotPasswordScreen(),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'Forgot password?',
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white60, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
      validator: validator,
    );
  }
}
