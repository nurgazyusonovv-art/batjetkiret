import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../data/user_api.dart';

class TopupHistoryPage extends StatefulWidget {
  const TopupHistoryPage({super.key, required this.token});
  final String token;

  @override
  State<TopupHistoryPage> createState() => _TopupHistoryPageState();
}

class _TopupHistoryPageState extends State<TopupHistoryPage> {
  final _api = UserApi();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getTopupHistory(widget.token);
      if (!mounted) return;
      setState(() { _items = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Топап тарыхы',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _load, child: const Text('Кайра')),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance_wallet_outlined,
                              size: 64, color: Color(0xFFBDBDBD)),
                          SizedBox(height: 16),
                          Text('Топап тарыхы жок',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 16)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (_, i) => _TopupCard(item: _items[i]),
                      ),
                    ),
    );
  }
}

class _TopupCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _TopupCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final status = (item['status'] as String? ?? 'pending').toLowerCase();
    final amount = (item['amount'] as num?)?.toDouble() ?? 0;
    final approvedAmount = (item['approved_amount'] as num?)?.toDouble();
    final adminNote = item['admin_note'] as String?;
    final createdAt = (item['created_at'] as String? ?? '');

    final statusConfig = _statusConfig(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusConfig.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusConfig.icon, color: statusConfig.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Балансты толуктоо',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (createdAt.length >= 16)
                        Text(
                          createdAt.replaceAll('T', ' ').substring(0, 16),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '+${amount.toStringAsFixed(0)} сом',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: status == 'approved'
                            ? const Color(0xFF16A34A)
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (approvedAmount != null && approvedAmount != amount)
                      Text(
                        'Тастыкталды: ${approvedAmount.toStringAsFixed(0)} сом',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusConfig.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusConfig.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusConfig.color,
                ),
              ),
            ),
            if (adminNote != null && adminNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      adminNote,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  _StatusConfig _statusConfig(String status) {
    switch (status) {
      case 'approved':
        return _StatusConfig(
          label: '✅ Тастыкталды',
          color: const Color(0xFF16A34A),
          icon: Icons.check_circle_outline,
        );
      case 'rejected':
        return _StatusConfig(
          label: '❌ Четке кагылды',
          color: AppColors.danger,
          icon: Icons.cancel_outlined,
        );
      case 'expired':
        return _StatusConfig(
          label: '⏰ Мөөнөтү өттү',
          color: const Color(0xFF9CA3AF),
          icon: Icons.schedule_outlined,
        );
      default:
        return _StatusConfig(
          label: '⏳ Текшерилүүдө',
          color: const Color(0xFFF59E0B),
          icon: Icons.hourglass_empty_outlined,
        );
    }
  }
}

class _StatusConfig {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusConfig({required this.label, required this.color, required this.icon});
}
