import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service to show local notifications when app is in foreground
class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permission on Android 13+
    await _requestPermissions();

    _isInitialized = true;
    debugPrint('[LocalNotification] ✅ Initialized');
  }

  Future<void> _requestPermissions() async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[LocalNotification] Tapped: ${response.payload}');
    // You can handle navigation here based on payload
  }

  /// Show a notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'vendor_trip_updates_v2', // Changed ID to force update settings on device
      'Trip Updates',
      channelDescription: 'Notifications about trip status updates (High Priority)',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    debugPrint('[LocalNotification] ✅ Shown: $title');
  }

  /// Show trip-specific notification
  Future<void> showTripNotification({
    required String type,
    required String bookingId,
    String? driverName,
    String? status,
  }) async {
    String title;
    String body;

    switch (type) {
      case 'DRIVER_ACCEPTED':
        title = '🚗 Driver Assigned';
        body = 'Driver ${driverName ?? 'has been'} assigned to booking #$bookingId';
        break;
      case 'TRIP_STARTED':
        title = '▶️ Trip Started';
        body = 'Trip #$bookingId has started. Driver is on the way!';
        break;
      case 'TRIP_COMPLETED':
        title = '✅ Trip Completed';
        body = 'Trip #$bookingId has been completed successfully.';
        break;
      default:
        title = '📋 Booking Update';
        body = 'Booking #$bookingId status: ${status ?? 'Updated'}';
    }

    await showNotification(
      title: title,
      body: body,
      payload: bookingId,
    );
  }
}
