import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'local_notification_service.dart';

/// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.messageId}');
  
  // Show local notification for background messages
  final localNotification = LocalNotificationService();
  await localNotification.initialize();
  
  final data = message.data;
  final notification = message.notification;
  
  await localNotification.showNotification(
    title: notification?.title ?? data['title'] ?? 'Trip Update',
    body: notification?.body ?? data['message'] ?? 'You have a new update',
    payload: data['bookingId'],
  );
}

/// Firebase Cloud Messaging service for vendor push notifications
class FirebaseMessagingService {
  static final FirebaseMessagingService _instance = FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final LocalNotificationService _localNotifications = LocalNotificationService();
  bool _isInitialized = false;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  /// Initialize Firebase messaging
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // Set up background handler
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        // Get FCM token
        _fcmToken =
            await _messaging.getToken().timeout(const Duration(seconds: 8));
        debugPrint('[FCM] Token: $_fcmToken');

        // Register token with backend
        if (_fcmToken != null) {
          await _registerTokenWithBackend(_fcmToken!);
        }

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) async {
          _fcmToken = newToken;
          debugPrint('[FCM] Token refreshed: $newToken');
          await _registerTokenWithBackend(newToken);
        });

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle message taps when app is in background
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

        // Initialize local notifications for foreground display
        await _localNotifications.initialize();

        _isInitialized = true;
        debugPrint('[FCM] ✅ Initialized successfully');
      }
    } catch (e) {
      debugPrint('[FCM] ❌ Initialization error: $e');
    }
  }

  /// Register FCM token with backend
  Future<void> registerToken() async {
    try {
      _fcmToken ??=
          await _messaging.getToken().timeout(const Duration(seconds: 8));
      if (_fcmToken != null) {
        await _registerTokenWithBackend(_fcmToken!);
      }
    } on TimeoutException {
      debugPrint('[FCM] Token fetch timed out');
    } catch (e) {
      debugPrint('[FCM] Token fetch error: $e');
    }
  }

  /// Internal method to register token
  Future<void> _registerTokenWithBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vendorToken = prefs.getString('vendor_token');
      final vendorId = prefs.getString('vendor_id');
      final adminId = prefs.getString('admin_id');

      if (vendorToken == null || vendorId == null) {
        debugPrint('[FCM] No vendor credentials, skipping token registration');
        return;
      }

      // Server URL for FCM token registration
      final url = Uri.parse('https://api.cabigo.in/vendor/fcm-token');
      
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $vendorToken',
            },
            body: json.encode({
              'fcmToken': token,
              'vendorId': vendorId,
              'adminId': adminId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[FCM] ✅ Token registered with backend');
      } else {
        debugPrint('[FCM] ⚠️ Token registration failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[FCM] ❌ Token registration error: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground message: ${message.messageId}');
    
    final notification = message.notification;
    final data = message.data;

    // Show local notification
    _localNotifications.showNotification(
      title: notification?.title ?? data['title'] ?? 'Trip Update',
      body: notification?.body ?? data['message'] ?? 'You have a new update',
      payload: data['bookingId'],
    );
  }

  /// Handle message tap (when notification is tapped)
  void _handleMessageTap(RemoteMessage message) {
    debugPrint('[FCM] Message tapped: ${message.messageId}');
    // Navigation can be handled here based on message.data
  }
}
