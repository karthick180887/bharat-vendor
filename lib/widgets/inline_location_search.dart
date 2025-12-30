import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../design_system.dart';

class InlineLocationSearch extends StatefulWidget {
  const InlineLocationSearch({
    super.key,
    required this.label,
    required this.icon,
    required this.googleMapsKey,
    required this.controller,
    required this.onLocationSelected,
    this.initialAddress,
    this.validator,
  });

  final String label;
  final IconData icon;
  final String googleMapsKey;
  final TextEditingController controller;
  final ValueChanged<Map<String, dynamic>> onLocationSelected;
  final String? initialAddress;
  final String? Function(String?)? validator;

  @override
  State<InlineLocationSearch> createState() => _InlineLocationSearchState();
}

class _InlineLocationSearchState extends State<InlineLocationSearch> {
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _predictions = [];
  Timer? _debounce;
  bool _isLoading = false;
  bool _showPredictions = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null && widget.controller.text.isEmpty) {
      widget.controller.text = widget.initialAddress!;
    }

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showPredictions = false);
        });
      } else if (_predictions.isNotEmpty) {
        setState(() => _showPredictions = true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant InlineLocationSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialAddress != oldWidget.initialAddress &&
        widget.initialAddress != widget.controller.text) {
      widget.controller.text = widget.initialAddress ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.isEmpty) {
      widget.onLocationSelected({});
      setState(() {
        _predictions = [];
        _showPredictions = false;
        _error = null;
      });
      return;
    }

    if (widget.googleMapsKey.isEmpty) {
      widget.onLocationSelected({'address': query});
      setState(() {
        _predictions = [];
        _showPredictions = false;
        _error = 'Maps API key missing';
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchPredictions(query);
    });
  }

  Future<void> _fetchPredictions(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=${widget.googleMapsKey}&components=country:in',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) {
        setState(() {
          _error = 'Network error: ${response.statusCode}';
          _isLoading = false;
        });
        return;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String?;

      if (status == 'OK' && data['predictions'] is List) {
        setState(() {
          _predictions = List<Map<String, dynamic>>.from(data['predictions']);
          _showPredictions = true;
          _isLoading = false;
        });
        return;
      }

      if (status == 'ZERO_RESULTS') {
        setState(() {
          _predictions = [];
          _showPredictions = false;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _predictions = [];
        _isLoading = false;
        _error = 'API error: ${status ?? 'Unknown'}';
      });
    } catch (e) {
      setState(() {
        _predictions = [];
        _isLoading = false;
        _error = 'Error: $e';
      });
    }
  }

  Future<void> _getPlaceDetails(String placeId, String description) async {
    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=formatted_address,geometry&key=${widget.googleMapsKey}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK') {
          final result = data['result'] as Map<String, dynamic>;
          final geometry = result['geometry'] as Map<String, dynamic>;
          final locationData = geometry['location'] as Map<String, dynamic>;
          final location = {
            'address': result['formatted_address'] ?? description,
            'lat': locationData['lat'],
            'lng': locationData['lng'],
          };

          widget.controller.text = location['address'] as String;
          widget.onLocationSelected(location);

          setState(() {
            _showPredictions = false;
            _isLoading = false;
          });
          _focusNode.unfocus();
        } else {
          setState(() {
            _isLoading = false;
            _error = 'Place details error: ${data['status'] ?? 'Unknown'}';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Network error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: Icon(widget.icon),
            suffixIcon: widget.controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      widget.controller.clear();
                      widget.onLocationSelected({});
                      _onSearchChanged('');
                    },
                  ),
          ),
          validator: widget.validator,
          onChanged: _onSearchChanged,
        ),
        if (_showPredictions || _isLoading || _error != null)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _error!,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _predictions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _predictions[index];
                          final structured = item['structured_formatting'] as Map<String, dynamic>?;
                          final mainText = structured?['main_text'] ?? item['description'];
                          final secondaryText = structured?['secondary_text'] ?? '';

                          return InkWell(
                            onTap: () => _getPlaceDetails(
                              item['place_id'] as String,
                              item['description'] as String,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 16,
                                    color: AppColors.textLight,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          mainText.toString(),
                                          style: AppTextStyles.bodyMedium,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (secondaryText.toString().isNotEmpty)
                                          Text(
                                            secondaryText.toString(),
                                            style: AppTextStyles.bodySmall,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
      ],
    );
  }
}
