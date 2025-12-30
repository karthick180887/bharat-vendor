import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api_client.dart';
import '../../design_system.dart';

class PayoutScreen extends StatefulWidget {
  const PayoutScreen({super.key});

  @override
  State<PayoutScreen> createState() => _PayoutScreenState();
}

class _PayoutScreenState extends State<PayoutScreen> {
  final _api = VendorApiClient();
  bool _isLoading = true;
  List<dynamic> _transactions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('vendor_token');
    if (token == null) return;

    try {
      final res = await _api.fetchTransactions(token: token);
      if (mounted) {
        setState(() {
          if (res.statusCode == 200 && res.data != null) {
            final body = res.data;
            if (body is Map && body.containsKey('data') && body['data'] is List) {
              _transactions = body['data'];
            } else if (body is List) {
               _transactions = body;
            } else {
               // Fallback or empty
               _transactions = [];
            }
          } else {
             _error = res.message ?? 'Failed to load transactions';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payouts & Transactions')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _transactions.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textSecondary),
                          SizedBox(height: 16),
                          Text('No transactions yet', style: AppTextStyles.bodyMedium),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _transactions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final tx = _transactions[index];
                        // Adjust parsing based on actual transaction model
                        final amount = tx['amount']?.toString() ?? '0';
                        final type = tx['type'] ?? 'Payout'; 
                        final status = tx['status'] ?? 'Completed';
                        final date = tx['createdAt']?.toString() ?? '';

                        final breakdown = tx['fareBreakdown'] as Map<String, dynamic>?;
                        final vendorComm = breakdown?['vendorCommission']?.toString();
                        final description = tx['description'] ?? 'No description';
                        // Clean 'Credit' to 'Earnings' or keep 'Credit'
                        final displayType = type == 'Credit' ? 'Earnings' : type;

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(color: AppColors.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: type == 'Credit' ? AppColors.success.withAlpha(26) : AppColors.primaryLight,
                                child: Icon(
                                  type == 'Credit' ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: type == 'Credit' ? AppColors.success : AppColors.primary,
                                ),
                              ),
                              title: Text(displayType, style: AppTextStyles.label),
                              subtitle: Text(date.split('T').first),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹$amount',
                                    style: AppTextStyles.h3.copyWith(
                                      color: type == 'Credit' ? AppColors.success : AppColors.textMain,
                                    ),
                                  ),
                                  Text(
                                    status,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: status == 'Completed' ? AppColors.success : AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      _DetailRow(label: 'Description', value: description),
                                      if (vendorComm != null)
                                        _DetailRow(label: 'Vendor Commission', value: '₹$vendorComm'),
                                      if (tx['transactionId'] != null)
                                        _DetailRow(label: 'Transaction ID', value: tx['transactionId']),
                                      if (tx['remark'] != null && tx['remark'].toString().isNotEmpty)
                                        _DetailRow(label: 'Remark', value: tx['remark']),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.bodyMedium),
          ),
        ],
      ),
    );
  }
}

