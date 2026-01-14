import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api_client.dart';
import '../../design_system.dart';

class BookingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> booking;

  const BookingDetailScreen({super.key, required this.booking});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late Map<String, dynamic> _booking;
  final _api = VendorApiClient();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
  }

  Future<void> _assignToAllDrivers() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('vendor_token');
      if (token == null) return;

      final res = await _api.assignAllDrivers(
        token: token, 
        bookingId: _booking['bookingId'],
      );

      if (mounted) {
        if (res.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request sent to all drivers!'), backgroundColor: AppColors.success),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${res.message}'), backgroundColor: AppColors.error),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Default admin phone number
  static const String _defaultAdminPhone = '+919342374700';

  /// Returns the contact phone number based on booking source:
  /// - Customer App bookings (createdBy: 'user'/'customer') → Admin: +91 93423 74700
  /// - Admin Dashboard bookings (createdBy: 'admin') → Admin: +91 93423 74700
  /// - Vendor bookings (createdBy: 'vendor') → Vendor's phone number
  /// - Fallback → Admin number
  String _getContactPhone(Map<String, dynamic> booking) {
    final createdBy = _readCreatedBy(booking);
    
    // Customer App bookings → Admin number
    if (createdBy == 'user' || createdBy == 'customer') {
      return _defaultAdminPhone;
    }
    
    // Admin Dashboard bookings → Admin number
    if (createdBy == 'admin') {
      return _defaultAdminPhone;
    }
    
    // Vendor bookings → Vendor's phone number
    if (createdBy == 'vendor') {
      final vendorPhone = _readVendorPhone(booking);
      if (vendorPhone.isNotEmpty) {
        return vendorPhone;
      }
    }

    // Default fallback → Admin number
    return _defaultAdminPhone;
  }

  String _readCreatedBy(Map<String, dynamic> booking) {
    final value = booking['createdBy'] ?? booking['created_by'];
    if (value == null) return '';
    return value.toString().trim().toLowerCase();
  }

  String _readVendorPhone(Map<String, dynamic> booking) {
    // Try vendor object first
    final vendor = booking['vendor'];
    if (vendor is Map) {
      final phone = vendor['phone'] ?? vendor['contactNumber'] ?? vendor['mobile'];
      if (phone != null && phone.toString().trim().isNotEmpty) {
        return phone.toString().trim();
      }
    }
    
    // Try direct vendorPhone field
    final vendorPhone = booking['vendorPhone'] ?? booking['vendor_phone'];
    if (vendorPhone != null && vendorPhone.toString().trim().isNotEmpty) {
      return vendorPhone.toString().trim();
    }
    
    // Try vendorContact field
    final vendorContact = booking['vendorContact'] ?? booking['vendor_contact'];
    if (vendorContact is Map) {
      final phone = vendorContact['phone'] ?? vendorContact['mobile'];
      if (phone != null && phone.toString().trim().isNotEmpty) {
        return phone.toString().trim();
      }
    }
    if (vendorContact is String && vendorContact.trim().isNotEmpty) {
      return vendorContact.trim();
    }
    
    return '';
  }

  Future<void> _callContact() async {
    final phone = _getContactPhone(_booking);
    final uri = Uri(scheme: 'tel', path: phone);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to make phone call')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _booking['status'] ?? 'Unknown';
    final canAssign = (status == 'Booking Confirmed' || status == 'Pending') && 
                      (_booking['driverId'] == null || _booking['driverId'] == '');

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ID: ${_booking['bookingId']}', style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(status, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                   ),
                   const Divider(height: 24),
                   _buildRow(Icons.person, 'Customer', _booking['name'] ?? 'N/A'),
                   const SizedBox(height: 8),
                   _buildRow(Icons.phone, 'Phone', _booking['phone'] ?? 'N/A'),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Route Card
            const Text('Route Details', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildLocationRow(Icons.my_location, 'Pickup', _booking['pickup'] ?? _booking['pickupAddress'] ?? 'N/A'),
                   Padding(
                    padding: const EdgeInsets.only(left: 11),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(height: 20, width: 2, color: AppColors.border),
                    ),
                  ),
                  _buildLocationRow(Icons.location_on, 'Dropoff', _booking['drop'] ?? _booking['dropoffAddress'] ?? 'N/A'),
                ],
              ),
            ),

            const SizedBox(height: 16),

             // Payment Card
            const Text('Payment', style: AppTextStyles.h3),
            const SizedBox(height: 8),
             Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                   _buildRow(Icons.payments_outlined, 'Payment Method', _booking['paymentMethod'] ?? 'N/A'),
                   const SizedBox(height: 8),
                   _buildRow(Icons.percent, 'Total Amount', '₹${_booking['finalAmount'] ?? _booking['totalAmount'] ?? 0}'),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            if (canAssign)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _assignToAllDrivers,
                  icon: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Icon(Icons.podcasts), 
                  label: Text(_isLoading ? 'Sending Request...' : 'Assign to All Drivers'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              
             if (!canAssign && _booking['driverId'] != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                     color: AppColors.success.withAlpha(26),
                     borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       const Icon(Icons.check_circle, color: AppColors.success),
                       const SizedBox(width: 8),
                       Text('Driver Assigned', style: AppTextStyles.label.copyWith(color: AppColors.success)),
                    ],
                  ),
                ),

            // Contact Admin Button
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _callContact,
                icon: const Icon(Icons.phone),
                label: const Text('Contact Admin'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textLight)),
            Text(value, style: AppTextStyles.bodyMedium),
          ],
        ),
      ],
    );
  }
   Widget _buildLocationRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textLight)),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
