import 'package:flutter/material.dart';
import '../../api_client.dart';
import '../../design_system.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/timeline_route.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'booking_detail_screen.dart';

class BookingsScreen extends StatefulWidget {
  final int initialIndex;
  const BookingsScreen({super.key, this.initialIndex = 0});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _tabs = [
    _TabInfo('All', AppColors.primary, Icons.list_alt_rounded),
    _TabInfo('Pending', AppColors.warning, Icons.hourglass_top_rounded),
    _TabInfo('Not Started', AppColors.primary, Icons.schedule_rounded),
    _TabInfo('Started', AppColors.success, Icons.play_circle_rounded),
    _TabInfo('Completed', AppColors.info, Icons.check_circle_rounded),
    _TabInfo('Cancelled', AppColors.error, Icons.cancel_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Bookings', style: AppTextStyles.h2),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: List.generate(_tabs.length, (index) {
                return Padding(
                  padding: EdgeInsets.only(right: index < _tabs.length - 1 ? 10 : 0),
                  child: AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, child) {
                      final isSelected = _tabController.index == index;
                      return GestureDetector(
                        onTap: () => _tabController.animateTo(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? _tabs[index].color : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? _tabs[index].color : AppColors.border,
                              width: 1.5,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: _tabs[index].color.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ] : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _tabs[index].icon,
                                size: 16,
                                color: isSelected ? Colors.white : _tabs[index].color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _tabs[index].label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : AppColors.textMain,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((t) => BookingList(status: t.label)).toList(),
      ),
    );
  }
}

class SingleBookingScreen extends StatelessWidget {
  final String status;
  final String title;

  const SingleBookingScreen({
    super.key,
    required this.status,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title, style: AppTextStyles.h2),
      ),
      body: BookingList(status: status),
    );
  }
}

class _TabInfo {
  final String label;
  final Color color;
  final IconData icon;
  _TabInfo(this.label, this.color, this.icon);
}

class BookingList extends StatefulWidget {
  final String status;
  const BookingList({super.key, required this.status});

  @override
  State<BookingList> createState() => _BookingListState();
}

class _BookingListState extends State<BookingList>
    with AutomaticKeepAliveClientMixin {
  final _api = VendorApiClient();
  bool _isLoading = true;
  List<dynamic> _bookings = [];
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('vendor_token');
      final adminId = prefs.getString('admin_id');
      final vendorId = prefs.getString('vendor_id');

      if (token == null) return;

      setState(() {
        _isLoading = true;
        _error = null;
      });

      String backendStatus = '';
      switch (widget.status) {
        case 'All':
          backendStatus = ''; // Fetch all
          break;
        case 'Pending':
          backendStatus = 'new-bookings';
          break;
        case 'Not Started':
          backendStatus = 'not-started';
          break;
        case 'Started':
          backendStatus = 'started';
          break;
        case 'Completed':
          backendStatus = 'completed';
          break;
        case 'Cancelled':
          backendStatus = 'cancelled';
          break;
        default:
          backendStatus = '';
      }

      final res = await _api.getSpecificBookings(
        token: token,
        queryParams: {'status': backendStatus},
        adminId: adminId,
        vendorId: vendorId,
      );

      if (res.statusCode == 200) {
        final data = res.data;
        List<dynamic> list = [];
        if (data is List) {
          list = data;
        } else if (data is Map) {
          if (data['data'] is List) {
            list = data['data'];
          } else if (data['bookings'] is List) {
            list = data['bookings'];
          }
        }

        setState(() {
          _bookings = list;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = res.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  StatusType _getStatusType(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return StatusType.success;
      case 'started':
        return StatusType.info;
      case 'cancelled':
        return StatusType.error;
      case 'pending':
      case 'booking confirmed':
        return StatusType.warning;
      default:
        return StatusType.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return _buildSkeletonList();
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Error: $_error', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _fetchBookings,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.surfaceDark,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 48,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No ${widget.status.toLowerCase()} bookings',
              style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bookings will appear here',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookings.length,
        itemBuilder: (context, index) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 300 + (index * 50)),
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
            child: _buildBookingCard(_bookings[index]),
          );
        },
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final pickup = booking['pickup'] ?? booking['pickupAddress'] ?? 'N/A';
    final drop = booking['drop'] ?? booking['dropoffAddress'] ?? 'N/A';
    final stops = booking['stops'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookingDetailScreen(booking: booking),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Text(
                      '#${booking['bookingId'] ?? '...'}',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    StatusBadge(
                      label: booking['status'] ?? 'Unknown',
                      type: _getStatusType(booking['status']),
                      showIcon: false,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Timeline Route
                TimelineRoute(
                  pickup: pickup,
                  drop: drop,
                  stops: stops.map((s) => s.toString()).toList(),
                  compact: true,
                ),
                const Divider(height: 24),
                // Footer Row
                Row(
                  children: [
                    // Date/Time
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 16, color: AppColors.textLight),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(booking['pickupDateTime']),
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Amount
                    Text(
                      '₹${booking['finalAmount'] ?? booking['totalAmount'] ?? 0}',
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textLight),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr.toString());
      final now = DateTime.now();
      final diff = date.difference(now).inDays;

      String dayLabel;
      if (diff == 0) {
        dayLabel = 'Today';
      } else if (diff == 1) {
        dayLabel = 'Tomorrow';
      } else if (diff == -1) {
        dayLabel = 'Yesterday';
      } else {
        dayLabel = '${date.day}/${date.month}';
      }

      final time =
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      return '$dayLabel, $time';
    } catch (_) {
      return dateStr.toString();
    }
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _skeletonBox(80, 16),
                  const Spacer(),
                  _skeletonBox(60, 24, radius: 12),
                ],
              ),
              const SizedBox(height: 16),
              _skeletonBox(double.infinity, 14),
              const SizedBox(height: 8),
              _skeletonBox(200, 14),
              const SizedBox(height: 8),
              _skeletonBox(150, 14),
              const SizedBox(height: 16),
              Row(
                children: [
                  _skeletonBox(100, 14),
                  const Spacer(),
                  _skeletonBox(60, 20),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _skeletonBox(double width, double height, {double radius = 6}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
