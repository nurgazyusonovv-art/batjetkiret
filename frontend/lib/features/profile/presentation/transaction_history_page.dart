import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/user_api.dart';

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key, required this.token});

  final String token;

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  final UserApi _userApi = UserApi();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final transactions = await _userApi.getTransactions(widget.token);
      if (!mounted) return;

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _getTransactionTypeLabel(String type) {
    switch (type) {
      case 'TOPUP':
        return 'Толуктоо';
      case 'HOLD':
        return 'Кармалды';
      case 'RELEASE':
        return 'Бошотулду';
      case 'PAYOUT':
        return 'Төлөм';
      case 'SERVICE_FEE_USER':
        return 'Кызмат төлөмү (колдонуучу)';
      case 'SERVICE_FEE_COURIER':
        return 'Кызмат төлөмү (курьер)';
      default:
        return type;
    }
  }

  Color _getTransactionColor(String type) {
    switch (type) {
      case 'TOPUP':
      case 'PAYOUT':
      case 'RELEASE':
        return AppColors.accent4;
      case 'HOLD':
      case 'SERVICE_FEE_USER':
      case 'SERVICE_FEE_COURIER':
        return AppColors.accent5;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'TOPUP':
        return Icons.add_circle_outline;
      case 'PAYOUT':
        return Icons.payments;
      case 'HOLD':
        return Icons.lock_outline;
      case 'RELEASE':
        return Icons.lock_open;
      case 'SERVICE_FEE_USER':
      case 'SERVICE_FEE_COURIER':
        return Icons.receipt_long;
      default:
        return Icons.swap_horiz;
    }
  }

  String _formatDateTime(String raw) {
    final utc = raw.endsWith('Z') ? raw : '${raw}Z';
    final date = DateTime.tryParse(utc);
    if (date == null) return raw;
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Транзакциялар тарыхы',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadTransactions,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.accent5),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _loadTransactions,
                    child: const Text('Кайра аракет кылуу'),
                  ),
                ],
              )
            : _transactions.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Транзакциялар жок',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final transaction = _transactions[index];
                  final type = transaction['type']?.toString() ?? '';
                  final amount =
                      (transaction['amount'] as num?)?.toDouble() ?? 0.0;
                  final createdAt = transaction['created_at']?.toString() ?? '';
                  final orderId = (transaction['order_id'] as num?)?.toInt();

                  final color = _getTransactionColor(type);
                  final icon = _getTransactionIcon(type);
                  final label = _getTransactionTypeLabel(type);
                  final isPositive = amount >= 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withAlpha(30),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Icon(icon, color: color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDateTime(createdAt),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (orderId != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Заказ #$orderId',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primary.withAlpha(180),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${isPositive ? '+' : ''}${amount.toStringAsFixed(0)} сом',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
