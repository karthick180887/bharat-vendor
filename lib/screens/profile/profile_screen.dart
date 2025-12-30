import 'package:flutter/material.dart';
import '../../api_client.dart';
import '../../design_system.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import '../payout/payout_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = VendorApiClient();
  bool _isLoading = true;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('vendor_token');
    if (token == null) return;

    try {
      final res = await _api.fetchProfile(token: token);
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            final body = res.data as Map<String, dynamic>;
            if (body.containsKey('data') && body['data'] is Map && body['data'].containsKey('vendor')) {
               _profile = body['data']['vendor'];
            } else if (body.containsKey('vendor')) {
               _profile = body['vendor'];
            } else {
               _profile = body;
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('vendor_token');
    await prefs.remove('admin_id');
    await prefs.remove('vendor_id');
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Peppy Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 60, bottom: 40, left: 24, right: 24),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                   Container(
                     padding: const EdgeInsets.all(4),
                     decoration: const BoxDecoration(
                       shape: BoxShape.circle,
                       color: Colors.white,
                     ),
                     child: const CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.primaryLight,
                      child: Icon(Icons.person, size: 50, color: AppColors.primary),
                                     ),
                   ),
                  const SizedBox(height: 16),
                  Text(
                    _profile?['name'] ?? 'Vendor Name',
                    style: AppTextStyles.h1.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _profile?['phone'] ?? '',
                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withAlpha(230)),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // Menu Options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _ProfileMenuCard(
                    title: 'Payouts',
                    icon: Icons.account_balance_wallet_outlined,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PayoutScreen()));
                    },
                  ),
                  const SizedBox(height: 16),
                  _ProfileMenuCard(
                    title: 'Bank Details',
                    icon: Icons.account_balance_outlined,
                    onTap: () {}, // Placeholder for now
                  ),
                  const SizedBox(height: 16),
                  _ProfileMenuCard(
                    title: 'Help & Support',
                    icon: Icons.headset_mic_outlined,
                    onTap: () {},
                  ),
                  const SizedBox(height: 32),
                  
                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error.withAlpha(26),
                        foregroundColor: AppColors.error,
                        elevation: 0,
                         shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.logout_rounded),
                          const SizedBox(width: 12),
                          Text('Logout', style: AppTextStyles.h3.copyWith(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ),

                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ProfileMenuCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withAlpha(128),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Text(title, style: AppTextStyles.h3),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
