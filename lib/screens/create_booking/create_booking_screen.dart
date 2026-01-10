import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api_client.dart';
import '../../design_system.dart';
import '../../widgets/inline_location_search.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/timeline_route.dart';

class CreateBookingScreen extends StatefulWidget {
  const CreateBookingScreen({super.key});

  @override
  State<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends State<CreateBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Date & Time
  DateTime _pickupDate = DateTime.now();
  TimeOfDay _pickupTime = TimeOfDay.now();
  DateTime? _returnDate;
  
  // Stops
  final List<TextEditingController> _stopControllers = [];
  final List<Map<String, dynamic>?> _stopLocations = [];
  
  // Pricing fields
  final _pricePerKmController = TextEditingController(text: '0');
  final _extraPricePerKmController = TextEditingController(text: '0');
  final _driverBataController = TextEditingController(text: '0');
  final _extraDriverBataController = TextEditingController(text: '0');
  final _tollController = TextEditingController(text: '0');
  final _extraTollController = TextEditingController(text: '0');
  final _hillController = TextEditingController(text: '0');
  final _extraHillController = TextEditingController(text: '0');
  final _permitController = TextEditingController(text: '0');
  final _extraPermitController = TextEditingController(text: '0');
  
  String _tripType = 'One Way';
  bool _isLoadingServices = true;
  bool _isLoadingVehicles = false;
  bool _isLoadingConfig = true;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _vehicles = [];
  Map<String, dynamic>? _selectedService;
  Map<String, dynamic>? _selectedVehicle;
  String? _token;
  String? _adminId;
  String? _vendorId;
  String _googleMapsKey = '';
  Map<String, dynamic>? _pickupLocation;
  Map<String, dynamic>? _dropLocation;
  
  bool _isLoading = false;
  Map<String, dynamic>? _estimationData; // Stores estimation result for preview
  final _api = VendorApiClient();

  String _normalizeServiceType(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.contains('round')) return 'Round trip';
    if (normalized.contains('one')) return 'One way';
    return raw;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _pricePerKmController.dispose();
    _extraPricePerKmController.dispose();
    _driverBataController.dispose();
    _extraDriverBataController.dispose();
    _tollController.dispose();
    _extraTollController.dispose();
    _hillController.dispose();
    _extraHillController.dispose();
    _permitController.dispose();
    _extraPermitController.dispose();
    for (final c in _stopControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('vendor_token');
    _adminId = prefs.getString('admin_id');
    _vendorId = prefs.getString('vendor_id');

    if (_token == null || _adminId == null) {
      if (mounted) {
        setState(() {
          _isLoadingServices = false;
          _isLoadingConfig = false;
        });
      }
      return;
    }

    await _fetchConfigKeys();
    await _fetchServices();
  }

  Future<void> _fetchConfigKeys() async {
    if (_token == null || _vendorId == null) {
      if (mounted) {
        setState(() => _isLoadingConfig = false);
      }
      return;
    }

    final res = await _api.getConfigKeys(
      token: _token!,
      adminId: _adminId,
      vendorId: _vendorId,
    );

    if (!mounted) return;

    if (res.isSuccess && res.data is Map && res.data['data'] is Map) {
      final data = Map<String, dynamic>.from(res.data['data']);
      setState(() {
        _googleMapsKey = (data['google_maps_key'] ?? '').toString();
        _isLoadingConfig = false;
      });
      return;
    }

    setState(() => _isLoadingConfig = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to load config keys: ${res.message ?? 'Unknown error'}')),
    );
  }

  Future<void> _fetchServices() async {
    if (_token == null || _adminId == null) return;
    setState(() => _isLoadingServices = true);

    final res = await _api.getServices(
      token: _token!,
      adminId: _adminId!,
    );

    if (!mounted) return;

    if (res.isSuccess && res.data is Map && res.data['data'] is List) {
      final list = List<Map<String, dynamic>>.from(res.data['data']);
      setState(() {
        _services = list;
        _selectedService = list.isNotEmpty ? list.first : null;
      });
      if (_selectedService != null) {
        await _fetchVehicles(_selectedService!['serviceId'] as String);
      }
    } else {
      setState(() => _services = []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load services: ${res.message ?? 'Unknown error'}')),
      );
    }

    if (mounted) {
      setState(() => _isLoadingServices = false);
    }
  }

  Future<void> _fetchVehicles(String serviceId) async {
    if (_token == null || _adminId == null) return;
    setState(() => _isLoadingVehicles = true);

    final res = await _api.getVehiclesByService(
      token: _token!,
      adminId: _adminId!,
      serviceId: serviceId,
      vendorId: _vendorId,
    );

    if (!mounted) return;

    if (res.isSuccess && res.data is Map && res.data['data'] is List) {
      final list = List<Map<String, dynamic>>.from(res.data['data']);
      setState(() {
        _vehicles = list;
        _selectedVehicle = list.isNotEmpty ? list.first : null;
      });
      // Auto-populate pricing from selected vehicle
      _populatePricingFromVehicle();
    } else {
      setState(() => _vehicles = []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load vehicles: ${res.message ?? 'Unknown error'}')),
      );
    }

    if (mounted) {
      setState(() => _isLoadingVehicles = false);
    }
  }

  void _populatePricingFromVehicle() {
    if (_selectedVehicle == null) return;
    
    final price = (_selectedVehicle!['price'] as num?)?.toString() ?? '0';
    final extraPrice = (_selectedVehicle!['extraPrice'] as num?)?.toString() ?? '0';
    final driverBeta = (_selectedVehicle!['driverBeta'] as num?)?.toString() ?? '0';
    final extraDriverBeta = (_selectedVehicle!['extraDriverBeta'] as num?)?.toString() ?? '0';
    
    setState(() {
      _pricePerKmController.text = price;
      _extraPricePerKmController.text = extraPrice;
      _driverBataController.text = driverBeta;
      _extraDriverBataController.text = extraDriverBeta;
    });
  }

  void _addStop() {
    setState(() {
      _stopControllers.add(TextEditingController());
      _stopLocations.add(null);
    });
  }

  void _removeStop(int index) {
    setState(() {
      _stopControllers[index].dispose();
      _stopControllers.removeAt(index);
      _stopLocations.removeAt(index);
    });
  }

  Future<void> _selectPickupDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _pickupDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _pickupDate = date);
    }
  }

  Future<void> _selectPickupTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _pickupTime,
    );
    if (time != null) {
      setState(() => _pickupTime = time);
    }
  }

  Future<void> _selectReturnDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _returnDate ?? _pickupDate.add(const Duration(days: 1)),
      firstDate: _pickupDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _returnDate = date);
    }
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _estimateFare() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedService == null || _selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a service and vehicle')),
      );
      return;
    }
    if (_token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please log in again.')),
      );
      return;
    }

    final pickupAddress =
        (_pickupLocation?['address'] ?? _pickupController.text).toString().trim();
    final dropAddress =
        (_dropLocation?['address'] ?? _dropoffController.text).toString().trim();
    if (pickupAddress.isEmpty || dropAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter pickup and drop locations')),
      );
      return;
    }

    // Validate round trip has return date
    final isRoundTrip = _tripType.toLowerCase().contains('round');
    if (isRoundTrip && _returnDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a return date for round trip')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final pickupDateTime = _combineDateAndTime(_pickupDate, _pickupTime);
      final serviceName = _selectedService?['name']?.toString() ?? '';
      final normalizedServiceType = _normalizeServiceType(serviceName);
      
      // Collect stop addresses
      final List<String> stops = [];
      for (int i = 0; i < _stopControllers.length; i++) {
        final stopAddr = (_stopLocations[i]?['address'] ?? _stopControllers[i].text).toString().trim();
        if (stopAddr.isNotEmpty) {
          stops.add(stopAddr);
        }
      }

      final bookingData = {
        'pickup': pickupAddress,
        'drop': dropAddress,
        'stops': stops,
        'name': _nameController.text,
        'phone': _phoneController.text,
        'serviceType': normalizedServiceType,
        'serviceId': _selectedService?['serviceId'],
        'vehicleType': _selectedVehicle?['name'],
        'vehicleId': _selectedVehicle?['vehicleId'],
        'tariffId': _selectedVehicle?['tariffId'],
        'pricePerKm': double.tryParse(_pricePerKmController.text) ?? 0,
        'extraPricePerKm': double.tryParse(_extraPricePerKmController.text) ?? 0,
        'driverBeta': double.tryParse(_driverBataController.text) ?? 0,
        'extraDriverBeta': double.tryParse(_extraDriverBataController.text) ?? 0,
        'toll': double.tryParse(_tollController.text) ?? 0,
        'extraToll': double.tryParse(_extraTollController.text) ?? 0,
        'hill': double.tryParse(_hillController.text) ?? 0,
        'extraHill': double.tryParse(_extraHillController.text) ?? 0,
        'permitCharge': double.tryParse(_permitController.text) ?? 0,
        'extraPermitCharge': double.tryParse(_extraPermitController.text) ?? 0,
        'pickupDateTime': pickupDateTime.toIso8601String(),
        if (isRoundTrip && _returnDate != null) 'dropDate': _returnDate!.toIso8601String(),
        'tripType': _tripType,
        'paymentMethod': 'Cash',
        if (_adminId != null) 'adminId': _adminId,
        if (_vendorId != null) 'vendorId': _vendorId,
      };

      final estimateRes = await _api.estimateFare(
        token: _token!,
        data: bookingData,
        adminId: _adminId,
      );

      if (!estimateRes.isSuccess ||
          estimateRes.data is! Map ||
          estimateRes.data['data'] is! Map) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to estimate fare: ${estimateRes.message ?? 'Unknown error'}')),
          );
        }
        return;
      }

      // Store estimation data and show preview
      setState(() {
        _estimationData = Map<String, dynamic>.from(estimateRes.data['data']);
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
         setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmBooking() async {
    if (_estimationData == null || _token == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final payload = Map<String, dynamic>.from(_estimationData!);
      if (_adminId != null) payload['adminId'] = _adminId;
      if (_vendorId != null) payload['vendorId'] = _vendorId;
      payload['paymentMethod'] = payload['paymentMethod'] ?? 'Cash';
      // Ensure name and phone are up to date from controllers
      payload['name'] = _nameController.text;
      payload['phone'] = _phoneController.text;

      final res = await _api.createBooking(
        token: _token!,
        data: payload,
        adminId: _adminId,
        vendorId: _vendorId,
      );
      
      if (mounted) {
        if (res.statusCode == 200 || res.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking Created Successfully!'), backgroundColor: AppColors.success),
          );
          _clearForm();
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
      if (mounted) {
         setState(() => _isLoading = false);
      }
    }
  }

  void _clearForm() {
    _pickupController.clear();
    _dropoffController.clear();
    _pickupLocation = null;
    _dropLocation = null;
    _nameController.clear();
    _phoneController.clear();
    for (final c in _stopControllers) {
      c.dispose();
    }
    _stopControllers.clear();
    _stopLocations.clear();
    _pickupDate = DateTime.now();
    _pickupTime = TimeOfDay.now();
    _returnDate = null;
    _pricePerKmController.text = '0';
    _extraPricePerKmController.text = '0';
    _driverBataController.text = '0';
    _extraDriverBataController.text = '0';
    _tollController.text = '0';
    _extraTollController.text = '0';
    _hillController.text = '0';
    _extraHillController.text = '0';
    _permitController.text = '0';
    _extraPermitController.text = '0';
    _estimationData = null;
    setState(() {});
  }

  Widget _buildPricingField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixText: '₹',
        isDense: true,
      ),
    );
  }

  Widget _buildEstimationPreview() {
    if (_estimationData == null) return const SizedBox.shrink();
    
    final data = _estimationData!;
    final distance = data['distance'] ?? 0;
    final duration = data['duration'] ?? '-';
    final pricePerKm = data['pricePerKm'] ?? 0;
    final driverBeta = data['driverBeta'] ?? 0;
    final toll = (data['toll'] ?? 0) + (data['extraToll'] ?? 0);
    final hill = (data['hill'] ?? 0) + (data['extraHill'] ?? 0);
    final permit = (data['permitCharge'] ?? 0) + (data['extraPermitCharge'] ?? 0);
    final taxAmount = data['taxAmount'] ?? 0;
    final convenienceFee = data['convenienceFee'] ?? 0;
    final estimatedAmount = data['estimatedAmount'] ?? 0;
    final finalAmount = data['finalAmount'] ?? 0;
    final pickup = data['pickup']?.toString() ?? '';
    final drop = data['drop']?.toString() ?? '';
    final stops = (data['stops'] as List?)?.map((s) => s.toString()).toList() ?? [];
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.05), AppColors.accent.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Fare Estimation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route Timeline
                TimelineRoute(pickup: pickup, drop: drop, stops: stops, compact: true),
                
                const SizedBox(height: 16),
                
                // Trip Info Row
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _infoChip(Icons.straighten_rounded, '$distance km', 'Distance'),
                      Container(width: 1, height: 30, color: AppColors.border),
                      _infoChip(Icons.access_time_rounded, '$duration', 'Duration'),
                      Container(width: 1, height: 30, color: AppColors.border),
                      _infoChip(Icons.directions_car_rounded, '${data['vehicleType'] ?? '-'}', 'Vehicle'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Fare Breakdown
                Text('Fare Breakdown', style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                _fareRow('Base Fare', '₹$estimatedAmount', subtitle: '$distance km × ₹$pricePerKm'),
                _fareRow('Driver Bata', '₹$driverBeta'),
                if (toll > 0) _fareRow('Toll Charges', '₹$toll'),
                if (hill > 0) _fareRow('Hill Charges', '₹$hill'),
                if (permit > 0) _fareRow('Permit Charges', '₹$permit'),
                if (taxAmount > 0) _fareRow('Tax', '₹$taxAmount'),
                if (convenienceFee > 0) _fareRow('Convenience Fee', '₹$convenienceFee'),
                
                const SizedBox(height: 16),
                
                // Total Amount
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '₹$finalAmount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 6),
        Text(value, style: AppTextStyles.label),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.bodySmall.copyWith(fontSize: 10)),
      ],
    );
  }

  Widget _fareRow(String label, String value, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodyMedium),
                if (subtitle != null)
                  Text(subtitle, style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
              ],
            ),
          ),
          Text(value, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final isRoundTrip = _tripType.toLowerCase().contains('round');
    
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Booking')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Trip Details Section
              const Text('Trip Details', style: AppTextStyles.h3),
              const SizedBox(height: 16),

              if (_isLoadingServices)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<Map<String, dynamic>>(
                  key: ValueKey(_selectedService?['serviceId'] ?? 'service'),
                  initialValue: _selectedService,
                  decoration: const InputDecoration(labelText: 'Trip Type'),
                  items: _services
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s['name']?.toString() ?? '-'),
                          ))
                      .toList(),
                  onChanged: (service) async {
                    if (service == null) return;
                    setState(() {
                      _selectedService = service;
                      _selectedVehicle = null;
                      _tripType = service['name']?.toString() ?? 'One Way';
                    });
                    await _fetchVehicles(service['serviceId'] as String);
                  },
                  validator: (value) => value == null ? 'Required' : null,
                ),
              const SizedBox(height: 12),

              if (_isLoadingVehicles)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<Map<String, dynamic>>(
                  key: ValueKey(_selectedVehicle?['vehicleId'] ?? 'vehicle'),
                  initialValue: _selectedVehicle,
                  decoration: const InputDecoration(labelText: 'Vehicle Type'),
                  items: _vehicles
                      .map((v) => DropdownMenuItem(
                            value: v,
                            child: Text(
                              '${v['name'] ?? '-'} • ₹${v['price'] ?? 0}/km',
                            ),
                          ))
                      .toList(),
                  onChanged: (vehicle) {
                    setState(() => _selectedVehicle = vehicle);
                    _populatePricingFromVehicle();
                  },
                  validator: (value) => value == null ? 'Required' : null,
                ),

              // Customer Details Section
              const SizedBox(height: 24),
              const Text('Customer Details', style: AppTextStyles.h3),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => v?.isNotEmpty == true ? null : 'Required',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) => v?.isNotEmpty == true ? null : 'Required',
              ),

              // Location Details Section
              const SizedBox(height: 24),
              const Text('Location Details', style: AppTextStyles.h3),
              const SizedBox(height: 16),

              if (!_isLoadingConfig && _googleMapsKey.isEmpty) ...[
                Text(
                  'Maps API key missing. Autocomplete is disabled.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                ),
                const SizedBox(height: 8),
              ],
              
              if (_isLoadingConfig)
                const Center(child: CircularProgressIndicator())
              else
                InlineLocationSearch(
                  label: 'From Location',
                  icon: Icons.my_location,
                  googleMapsKey: _googleMapsKey,
                  controller: _pickupController,
                  initialAddress: _pickupLocation?['address'] as String?,
                  validator: (v) => v?.isNotEmpty == true ? null : 'Required',
                  onLocationSelected: (loc) => setState(() => _pickupLocation = loc),
                ),

              // Stops Section
              const SizedBox(height: 16),
              const Text('Stops (Optional)', style: AppTextStyles.h4),
              const SizedBox(height: 8),
              ..._buildStopsList(),
              OutlinedButton.icon(
                onPressed: _addStop,
                icon: const Icon(Icons.add_location_alt),
                label: const Text('Add Stop'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              ),

              const SizedBox(height: 16),
              if (_isLoadingConfig)
                const Center(child: CircularProgressIndicator())
              else
                InlineLocationSearch(
                  label: 'To Location',
                  icon: Icons.location_on_outlined,
                  googleMapsKey: _googleMapsKey,
                  controller: _dropoffController,
                  initialAddress: _dropLocation?['address'] as String?,
                  validator: (v) => v?.isNotEmpty == true ? null : 'Required',
                  onLocationSelected: (loc) => setState(() => _dropLocation = loc),
                ),

              // Date & Time Section
              const SizedBox(height: 24),
              const Text('Pickup Date & Time', style: AppTextStyles.h3),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectPickupDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Pickup Date',
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          '${_pickupDate.day.toString().padLeft(2, '0')}-${_pickupDate.month.toString().padLeft(2, '0')}-${_pickupDate.year}',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _selectPickupTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Pickup Time',
                          suffixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(_pickupTime.format(context)),
                      ),
                    ),
                  ),
                ],
              ),

              if (isRoundTrip) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: _selectReturnDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Return Date',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _returnDate != null
                          ? '${_returnDate!.day.toString().padLeft(2, '0')}-${_returnDate!.month.toString().padLeft(2, '0')}-${_returnDate!.year}'
                          : 'Select return date',
                    ),
                  ),
                ),
              ],

              // Pricing Details Section
              const SizedBox(height: 24),
              const Text('Pricing Details', style: AppTextStyles.h3),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(child: _buildPricingField('Amount Per KM', _pricePerKmController)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildPricingField('Extra Amount Per KM', _extraPricePerKmController)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildPricingField('Driver Bata', _driverBataController)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildPricingField('Extra Driver Bata', _extraDriverBataController)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildPricingField('Toll Charge', _tollController)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildPricingField('Extra Toll Charge', _extraTollController)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildPricingField('Hill Charge', _hillController)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildPricingField('Extra Hill Charge', _extraHillController)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildPricingField('Permit Charge', _permitController)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildPricingField('Extra Permit Charge', _extraPermitController)),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Estimation Preview or Estimate Button
              if (_estimationData == null) ...[
                GradientButton(
                  text: 'Estimate Fare',
                  icon: Icons.calculate_rounded,
                  isLoading: _isLoading,
                  onPressed: _estimateFare,
                ),
              ] else ...[
                // Estimation Preview Card
                _buildEstimationPreview(),
                const SizedBox(height: 20),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: _isLoading ? null : () => setState(() => _estimationData = null),
                            borderRadius: BorderRadius.circular(14),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.edit_rounded, color: AppColors.textSecondary, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Edit', style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: GradientButton(
                        text: 'Confirm Booking',
                        icon: Icons.check_rounded,
                        isLoading: _isLoading,
                        onPressed: _confirmBooking,
                        height: 52,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStopsList() {
    return List.generate(_stopControllers.length, (index) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: _isLoadingConfig
                  ? const Center(child: CircularProgressIndicator())
                  : InlineLocationSearch(
                      label: 'Stop ${index + 1}',
                      icon: Icons.pin_drop_outlined,
                      googleMapsKey: _googleMapsKey,
                      controller: _stopControllers[index],
                      initialAddress: _stopLocations[index]?['address'] as String?,
                      onLocationSelected: (loc) => setState(() => _stopLocations[index] = loc),
                    ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
              onPressed: () => _removeStop(index),
            ),
          ],
        ),
      );
    });
  }
}
