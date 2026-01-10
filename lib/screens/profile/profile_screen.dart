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
            if (body.containsKey('data') && body['data'] is Map) {
              final data = body['data'] as Map<String, dynamic>;
              if (data.containsKey('vendor')) {
                _profile = data['vendor'];
              } else {
                _profile = data;
              }
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
      body: RefreshIndicator(
        onRefresh: _fetchProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                      _profile?['name'] ?? 'Vendor',
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
                  _ProfileTile(
                    title: 'Payouts',
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.success,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PayoutScreen()));
                    },
                  ),
                  _ProfileTile(
                    title: 'Bank Details',
                    icon: Icons.account_balance_rounded,
                    color: AppColors.primary,
                    onTap: () {}, // Placeholder
                  ),
                  _ProfileTile(
                    title: 'Help & Support',
                    icon: Icons.headset_mic_rounded,
                    color: AppColors.warning,
                    onTap: () {},
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Logout Tile
                  _ProfileTile(
                    title: 'Logout',
                    icon: Icons.logout_rounded,
                    color: AppColors.error,
                    isLogout: true,
                    onTap: _logout,
                  ),
                  
                  const SizedBox(height: 20),
                  Text(
                    'Version 1.0.0',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textLight),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ));
  }
}

class _ProfileTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLogout;

  const _ProfileTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLogout = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isLogout ? color.withAlpha(0x0D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isLogout ? [] : [
          BoxShadow(
            color: Colors.black.withAlpha(0x08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: isLogout ? Border.all(color: color.withAlpha(0x1A)) : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(0x1A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: AppTextStyles.h3.copyWith(
                    color: isLogout ? color : AppColors.textMain,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (!isLogout)
                  Icon(Icons.chevron_right_rounded, size: 24, color: AppColors.textLight.withAlpha(0x80)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
