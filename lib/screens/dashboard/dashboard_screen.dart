import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api_client.dart';
import '../../design_system.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/animated_counter.dart';
import '../../services/socket_service.dart';
import '../bookings/bookings_screen.dart';
import '../create_booking/create_booking_screen.dart';
import '../notifications/notifications_screen.dart';
import '../auth/login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final _api = VendorApiClient();
  bool _isLoading = true;
  Map<String, dynamic>? _counts;
  Map<String, dynamic>? _profile;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

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
    _loadData();
    
    // Connect to socket for real-time notifications
    VendorSocketService().connect();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final token = prefs.getString('vendor_token');
    final adminId = prefs.getString('admin_id');
    final vendorId = prefs.getString('vendor_id');

    if (token == null) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      return;
    }

    try {
      if (adminId == null || vendorId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final resCounts = await _api.getBookingCounts(
          token: token, adminId: adminId, vendorId: vendorId);
      final profileRes = await _api.fetchProfile(token: token);
      if (!mounted) return;

      if (resCounts.statusCode == 200 && resCounts.data != null) {
        final body = resCounts.data as Map<String, dynamic>;
        setState(() => _counts = body['data'] as Map<String, dynamic>?);
      }

      if (profileRes.statusCode == 200 && profileRes.data != null) {
        final data = profileRes.data;
        debugPrint('Dashboard: Profile API response: $data');
        
        // Handle different response structures
        Map<String, dynamic>? vendorData;
        if (data is Map<String, dynamic>) {
          if (data.containsKey('vendor')) {
            vendorData = data['vendor'];
          } else if (data['data'] != null && data['data']['vendor'] != null) {
            vendorData = data['data']['vendor'];
          } else if (data['data'] != null && data['data'] is Map) {
            // Maybe data.data directly contains vendor fields
            vendorData = data['data'];
          } else {
            // Maybe data directly contains vendor fields  
            vendorData = data;
          }
        }
        
        if (vendorData != null) {
          debugPrint('Dashboard: Vendor data: $vendorData');
          debugPrint('Dashboard: totalEarnings = ${vendorData['totalEarnings']}');
          debugPrint('Dashboard: totalTrips = ${vendorData['totalTrips']}');
          setState(() => _profile = vendorData);
        }
      }
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _animController.forward();
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('vendor_token');
    await prefs.remove('admin_id');
    await prefs.remove('vendor_id');
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // Gradient Header
                  SliverToBoxAdapter(child: _buildHeader()),
                  // Stats Cards
                  SliverToBoxAdapter(child: _buildStatsRow()),
                  // Create Booking CTA
                  SliverToBoxAdapter(child: _buildCreateBookingCTA()),
                  // Summary Grid Header
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                      child: Text('Booking Status', style: AppTextStyles.h2),
                    ),
                  ),
                  // Summary Grid
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: _buildSummaryGrid(),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 24,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      (_profile?['name'] ?? 'V')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Greeting
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _profile?['name'] ?? 'Vendor',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Notification Bell
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Logout
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    onPressed: _logout,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Row(
          children: [
            Expanded(
              child: _PremiumStatCard(
                title: 'Total Earnings',
                value: _profile?['totalEarnings'] ?? 0,
                prefix: '₹',
                icon: Icons.account_balance_wallet_rounded,
                iconColor: AppColors.success,
                iconBgColor: AppColors.successLight,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _PremiumStatCard(
                title: 'Total Trips',
                value: _profile?['totalTrips'] ?? 0,
                icon: Icons.directions_car_rounded,
                iconColor: AppColors.primary,
                iconBgColor: AppColors.primaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateBookingCTA() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: GradientButton(
          text: 'Create New Booking',
          icon: Icons.add_circle_outline_rounded,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateBookingScreen()),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryGrid() {
    final items = [
      _SummaryItem(
        title: 'Total',
        count: _counts?['all'] ?? 0,
        icon: Icons.confirmation_number_rounded,
        color: AppColors.primary,
        onTap: () => _navigateToBookings(0),
      ),
      _SummaryItem(
        title: 'Not Started',
        count: _counts?['not-started'] ?? 0,
        icon: Icons.schedule_rounded,
        color: AppColors.warning,
        onTap: () => _navigateToBookings(1),
      ),
      _SummaryItem(
        title: 'Started',
        count: _counts?['started'] ?? 0,
        icon: Icons.play_circle_rounded,
        color: AppColors.success,
        onTap: () => _navigateToBookings(2),
      ),
      _SummaryItem(
        title: 'Completed',
        count: _counts?['completed'] ?? 0,
        icon: Icons.check_circle_rounded,
        color: AppColors.info,
        onTap: () => _navigateToBookings(3),
      ),
      _SummaryItem(
        title: 'Cancelled',
        count: _counts?['cancelled'] ?? 0,
        icon: Icons.cancel_rounded,
        color: AppColors.error,
        onTap: () => _navigateToBookings(4),
      ),
    ];

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.15,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 400 + (index * 100)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: _buildSummaryCard(items[index]),
          );
        },
        childCount: items.length,
      ),
    );
  }

  Widget _buildSummaryCard(_SummaryItem item) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedCounter(
                        value: item.count,
                        style: AppTextStyles.h1.copyWith(fontSize: 24),
                      ),
                      Text(item.title, style: AppTextStyles.bodySmall, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToBookings(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookingsScreen(initialIndex: index)),
    );
  }
}

class _PremiumStatCard extends StatelessWidget {
  final String title;
  final dynamic value;
  final String? prefix;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const _PremiumStatCard({
    required this.title,
    required this.value,
    this.prefix,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });

  @override
  Widget build(BuildContext context) {
    final numValue = value is int ? value : int.tryParse(value?.toString() ?? '0') ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 14),
          AnimatedCounter(
            value: numValue,
            prefix: prefix,
            style: AppTextStyles.h1.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 4),
          Text(title, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _SummaryItem {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  _SummaryItem({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    this.onTap,
  });
}
