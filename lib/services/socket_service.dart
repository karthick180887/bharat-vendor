import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'local_notification_service.dart';

/// Real-time notification data from socket
class VendorNotification {
  final String type;
  final String bookingId;
  final String status;
  final String? driverName;
  final String? driverPhone;
  final String? vehicleNumber;
  final String? pickup;
  final String? drop;
  final DateTime timestamp;
  final Map<String, dynamic> raw;

  VendorNotification({
    required this.type,
    required this.bookingId,
    required this.status,
    this.driverName,
    this.driverPhone,
    this.vehicleNumber,
    this.pickup,
    this.drop,
    required this.timestamp,
    required this.raw,
  });

  factory VendorNotification.fromMap(Map<String, dynamic> data) {
    return VendorNotification(
      type: data['type'] ?? 'UNKNOWN',
      bookingId: data['bookingId']?.toString() ?? '',
      status: data['status']?.toString() ?? '',
      driverName: data['driverName'],
      driverPhone: data['driverPhone'],
      vehicleNumber: data['vehicleNumber'],
      pickup: data['pickup']?.toString(),
      drop: data['drop']?.toString(),
      timestamp: data['timestamp'] != null 
          ? DateTime.tryParse(data['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      raw: data,
    );
  }

  String get title {
    switch (type) {
      case 'DRIVER_ACCEPTED':
        return 'Driver Assigned';
      case 'TRIP_STARTED':
        return 'Trip Started';
      case 'TRIP_COMPLETED':
        return 'Trip Completed';
      case 'INVOICE_READY':
        return 'Invoice Ready';
      case 'CUSTOM_NOTIFICATION':
        return 'Notification';
      default:
        return 'Booking Update';
    }
  }

  String get message {
    switch (type) {
      case 'DRIVER_ACCEPTED':
        return 'Driver $driverName has been assigned to booking #$bookingId';
      case 'TRIP_STARTED':
        return 'Trip #$bookingId has started. Driver is on the way.';
      case 'TRIP_COMPLETED':
        return 'Trip #$bookingId has been completed successfully.';
      case 'INVOICE_READY':
        return 'Invoice for booking #$bookingId is ready.';
      case 'CUSTOM_NOTIFICATION':
        return raw['message']?.toString() ?? 'You have a new notification.';
      default:
        return 'Booking #$bookingId status: $status';
    }
  }
}

/// Singleton socket service for vendor app
class VendorSocketService {
  static final VendorSocketService _instance = VendorSocketService._internal();
  factory VendorSocketService() => _instance;
  VendorSocketService._internal();

  io.Socket? _socket;
  String? _vendorId;
  String? _authToken;
  bool _isConnected = false;
  final _localNotifications = LocalNotificationService();

  // Stream controllers for real-time updates
  final _notificationController = StreamController<VendorNotification>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<VendorNotification> get notificationStream => _notificationController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;

  /// Connect to the socket server with vendor credentials
  Future<void> connect() async {
    if (_socket != null && _isConnected) {
      debugPrint('[VendorSocket] Already connected');
      return;
    }

    // Initialize local notifications
    await _localNotifications.initialize();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('vendor_token');
      _vendorId = prefs.getString('vendor_id');

      if (token == null || _vendorId == null) {
        debugPrint('[VendorSocket] No token or vendorId found');
        return;
      }
      _authToken = token;

      // Get socket URL from shared config or use default
      const socketUrl = 'https://api.cabigo.in';

      debugPrint('[VendorSocket] Connecting to $socketUrl...');

      _socket = io.io(
        socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setQuery({'token': token})
            .setAuth({'token': token})
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(10)
            .setReconnectionDelay(2000)
            .build(),
      );

      _setupListeners();
      _socket!.connect();
    } catch (e) {
      debugPrint('[VendorSocket] Connection error: $e');
    }
  }

  void _setupListeners() {
    _socket!.onConnect((_) {
      debugPrint('[VendorSocket] ✅ Connected');
      _isConnected = true;
      _connectionController.add(true);

      if (_authToken != null && _authToken!.isNotEmpty) {
        final payload = <String, dynamic>{'token': _authToken};
        if (_vendorId != null && _vendorId!.isNotEmpty) {
          payload['userId'] = _vendorId;
        }
        _socket!.emit('vendor_authenticate', payload);
        debugPrint('[VendorSocket] Sent vendor_authenticate');
      }
    });

    _socket!.on('auth_success', (data) {
      debugPrint('[VendorSocket] ✅ Authenticated: $data');
    });

    _socket!.on('auth_error', (data) {
      debugPrint('[VendorSocket] ❌ Auth error: $data');
    });

    // Listen for trip notifications
    _socket!.on('notification', (data) {
      debugPrint('[VendorSocket] 📨 Notification received: $data');
      _handleNotification(data);
    });

    _socket!.onDisconnect((_) {
      debugPrint('[VendorSocket] ❌ Disconnected');
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onConnectError((error) {
      debugPrint('[VendorSocket] ❌ Connect error: $error');
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onError((error) {
      debugPrint('[VendorSocket] ❌ Socket error: $error');
    });
  }

  void _handleNotification(dynamic data) {
    try {
      Map<String, dynamic> notificationData;

      if (data is String) {
        notificationData = json.decode(data);
      } else if (data is Map) {
        notificationData = Map<String, dynamic>.from(data);
      } else {
        debugPrint('[VendorSocket] Unknown notification format: ${data.runtimeType}');
        return;
      }

      final type = notificationData['type'] as String?;
      final innerData = notificationData['data'] as Map<String, dynamic>? ?? notificationData;

      // Only handle vendor-relevant events
      if (type == 'DRIVER_ACCEPTED' || 
          type == 'TRIP_STARTED' || 
          type == 'TRIP_COMPLETED' ||
          type == 'INVOICE_READY' ||
          type == 'CUSTOM_NOTIFICATION' ||
          type == 'VENDOR_TRIP_UPDATE') {
        
        final notification = VendorNotification.fromMap({
          'type': type,
          ...innerData,
        });

        _notificationController.add(notification);
        debugPrint('[VendorSocket] ✅ Notification processed: ${notification.title}');

        // 🔔 Show local notification
        _localNotifications.showTripNotification(
          type: type ?? 'UNKNOWN',
          bookingId: notification.bookingId,
          driverName: notification.driverName,
          status: notification.status,
        );
      }
    } catch (e) {
      debugPrint('[VendorSocket] Error processing notification: $e');
    }
  }

  /// Disconnect from the socket server
  void disconnect() {
    debugPrint('[VendorSocket] Disconnecting...');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _connectionController.add(false);
  }

  /// Dispose all resources
  void dispose() {
    disconnect();
    _notificationController.close();
    _connectionController.close();
  }
}
