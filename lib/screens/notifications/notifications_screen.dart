import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api_client.dart';
import '../../design_system.dart';
import '../../services/socket_service.dart';
import '../bookings/booking_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _socketService = VendorSocketService();
  final _apiClient = VendorApiClient();
  final List<VendorNotification> _notifications = [];
  StreamSubscription? _notificationSub;
  bool _isConnected = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _setupSocketListener();
  }

  Future<void> _fetchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('vendor_token');
      final vendorId = prefs.getString('vendor_id');
      final adminId = prefs.getString('admin_id');

      if (token != null && vendorId != null && adminId != null) {
        final result = await _apiClient.fetchNotifications(
          token: token,
          adminId: adminId,
          vendorId: vendorId,
        );

        if (result.isSuccess && result.data != null) {
          List<dynamic> data = [];
          if (result.data is Map<String, dynamic> && result.data['data'] is List) {
            data = result.data['data'];
          } else if (result.data is List) {
            data = result.data;
          }
          final List<VendorNotification> history = [];

          for (var item in data) {
            // Map backend notification to VendorNotification
            // Backend returns: { title, message, type, date, bookingId (inside message? or ids?) }
            // Actually the model VendorNotification in backend has: bookingId, etc.
            // Let's modify the socket_service.dart VendorNotification model to be more flexible or map it here.
            // The backend returns the DB model: id, title, description, type, read, date, etc.
            // And potentially 'ids' jsonb column?
            // The backend controller returns `VendorNotification.findAll`.
            // The model `VendorNotification` has `title`, `message`, `type`, `bookingId`, `adminId`, `vendorId`.
            
            // We need to construct VendorNotification from this.
            history.add(VendorNotification(
              type: item['type'] ?? 'UNKNOWN',
              bookingId: item['bookingId']?.toString() ?? item['route']?.toString() ?? '',
              status: item['type'] == 'TRIP_COMPLETED' ? 'Completed' : 'Updated', // Infer status
              timestamp: DateTime.tryParse(item['date']) ?? DateTime.now(),
              raw: item, // Pass full item
              // Optional fields might be missing in DB record compared to socket payload
              driverName: item['driverName'], 
              pickup: item['pickup'],
              drop: item['drop'],
            ));
          }

          if (mounted) {
            setState(() {
              _notifications.addAll(history);
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteNotification(String id, int index) async {
    // Optimistic remove
    final removed = _notifications[index];
    setState(() {
      _notifications.removeAt(index);
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('vendor_token');
      final vendorId = prefs.getString('vendor_id');
      final adminId = prefs.getString('admin_id');

      if (token != null && vendorId != null && adminId != null) {
        await _apiClient.deleteNotification(
          token: token,
          id: id,
          adminId: adminId,
          vendorId: vendorId,
        );
      }
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      // Revert if failed (optional, but good UX)
      if (mounted) {
        setState(() {
          _notifications.insert(index, removed);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete notification')),
        );
      }
    }
  }

  void _setupSocketListener() {
    // Listen for connection status
    _socketService.connectionStream.listen((connected) {
      if (mounted) {
        setState(() => _isConnected = connected);
      }
    });

    // Listen for new notifications
    _notificationSub = _socketService.notificationStream.listen((notification) {
      if (mounted) {
        setState(() {
          _notifications.insert(0, notification); // Add to top
        });
      }
    });

    // Check current connection status
    setState(() => _isConnected = _socketService.isConnected);
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'DRIVER_ACCEPTED':
        return Icons.person_add_rounded;
      case 'TRIP_STARTED':
        return Icons.play_circle_rounded;
      case 'TRIP_COMPLETED':
        return Icons.check_circle_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'DRIVER_ACCEPTED':
        return AppColors.info;
      case 'TRIP_STARTED':
        return AppColors.success;
      case 'TRIP_COMPLETED':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Notifications', style: AppTextStyles.h2),
        actions: const [],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    // Use database ID if available (from raw), else use bookingId as fallback or timestamp
                    // The backend ID is needed for deletion.
                    final id = notification.raw['id']?.toString() ?? '';
                    
                    return Dismissible(
                      key: Key(id.isNotEmpty ? id : notification.timestamp.toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                      ),
                      onDismissed: (direction) {
                        if (id.isNotEmpty) {
                          _deleteNotification(id, index);
                        } else {
                          // Local-only remove if no ID (shouldn't happen for persisted ones)
                          setState(() {
                            _notifications.removeAt(index);
                          });
                        }
                      },
                      child: _buildNotificationCard(notification),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.surfaceDark,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 48,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No notifications yet',
            style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Trip updates will appear here in real-time',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (!_isConnected)
            TextButton.icon(
              onPressed: () => _socketService.connect(),
              icon: const Icon(Icons.refresh),
              label: const Text('Reconnect'),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(VendorNotification notification) {
    final color = _getNotificationColor(notification.type);
    final icon = _getNotificationIcon(notification.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            // Navigate to booking detail
            if (notification.bookingId.isNotEmpty) {
              // We pass raw data, but for historical ones we might need to fetch booking details?
              // The BookingDetailScreen likely expects a booking object or ID.
              // If it expects map, we are good.
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookingDetailScreen(booking: notification.raw),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.raw['title'] ?? notification.title, // Prefer DB title if available
                              style: AppTextStyles.label.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(notification.timestamp),
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.raw['message'] ?? notification.message, // Prefer DB message
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (notification.driverName != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person_rounded,
                                size: 14, color: AppColors.textLight),
                            const SizedBox(width: 4),
                            Text(
                              notification.driverName!,
                              style: AppTextStyles.bodySmall,
                            ),
                            if (notification.vehicleNumber != null) ...[
                              const SizedBox(width: 12),
                              const Icon(Icons.directions_car_rounded,
                                  size: 14, color: AppColors.textLight),
                              const SizedBox(width: 4),
                              Text(
                                notification.vehicleNumber!,
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
