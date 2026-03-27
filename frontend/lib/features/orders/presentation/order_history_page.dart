import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../data/order_api.dart';
import '../data/order_model.dart';
import 'cubit/orders_cubit.dart';
import 'cubit/orders_state.dart';
import 'order_detail_page.dart';
import 'widgets/advanced_filter_dialog.dart';

enum _HistoryPeriod { sevenDays, thirtyDays, thisMonth }

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key, required this.token});

  final String token;

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  final OrderApi _orderApi = OrderApi();
  _HistoryPeriod _selectedPeriod = _HistoryPeriod.thirtyDays;
  AdvancedFilterOptions? _advancedFilterOptions;
  bool _isDeleting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersCubit = context.read<OrdersCubit>();

    return BlocBuilder<OrdersCubit, OrdersState>(
      builder: (context, state) {
        final query = _searchController.text.trim().toLowerCase();
        final historyOrders = _historyOrders(
          state.orders,
          query,
          _selectedPeriod,
        );
        final totalCount = historyOrders.length;
        final totalAmount = historyOrders.fold<double>(
          0,
          (sum, order) => sum + (order.estimatedPrice ?? 0),
        );
        final sections = _buildSections(historyOrders);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            title: const Text(
              'Заказ тарыхы',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            actions: [
              // Advanced Filter Icon
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.filter_list,
                      color: AppColors.textPrimary,
                    ),
                    tooltip: 'Кошумча фильтр',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AdvancedFilterDialog(
                          initialOptions: _advancedFilterOptions,
                          onApply: (options) {
                            setState(() {
                              _advancedFilterOptions = options;
                            });
                          },
                        ),
                      );
                    },
                  ),
                  if (_advancedFilterOptions?.hasActiveFilters ?? false)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              if (historyOrders.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: 'Бардыгын тазалоо',
                  onPressed: _isDeleting
                      ? null
                      : () => _confirmClearAll(ordersCubit),
                ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'ID, адрес, категория боюнча издөө',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildPeriodChip(
                      label: 'Акыркы 7 күн',
                      period: _HistoryPeriod.sevenDays,
                    ),
                    const SizedBox(width: 8),
                    _buildPeriodChip(
                      label: 'Акыркы 30 күн',
                      period: _HistoryPeriod.thirtyDays,
                    ),
                    const SizedBox(width: 8),
                    _buildPeriodChip(
                      label: 'Ушул ай',
                      period: _HistoryPeriod.thisMonth,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: _buildSummaryCard(
                  totalCount: totalCount,
                  totalAmount: totalAmount,
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ordersCubit.loadOrders(widget.token),
                  child: state.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : state.error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  state.error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 16),
                                AppButton.primary(
                                  onPressed: () =>
                                      ordersCubit.loadOrders(widget.token),
                                  label: 'Кайра жүктөө',
                                ),
                              ],
                            ),
                          ),
                        )
                      : historyOrders.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.history,
                                      size: 52,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      query.isNotEmpty
                                          ? 'Издөөгө ылайык заказ табылган жок'
                                          : state.isCourier
                                          ? 'Курьер тарыхында заказ жок'
                                          : 'Колдонуучу тарыхында заказ жок',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: sections.length,
                          itemBuilder: (context, index) {
                            final section = sections[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (section.isMonthHeader)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 6,
                                      bottom: 8,
                                    ),
                                    child: Text(
                                      section.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                if (!section.isMonthHeader)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 2,
                                      bottom: 8,
                                    ),
                                    child: Text(
                                      section.title,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ...section.orders.map((order) {
                                  final canDelete =
                                      !state.isCourier &&
                                      (order.status == 'cancelled' ||
                                          order.status == 'completed');

                                  return _HistoryOrderCard(
                                    order: order,
                                    isCourier: state.isCourier,
                                    token: widget.token,
                                    canDelete: canDelete,
                                    onDelete: _isDeleting
                                        ? null
                                        : () => _confirmAndDeleteOrder(
                                            order,
                                            ordersCubit,
                                          ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodChip({
    required String label,
    required _HistoryPeriod period,
  }) {
    final isActive = _selectedPeriod == period;

    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      onSelected: (_) {
        setState(() {
          _selectedPeriod = period;
        });
      },
      selectedColor: AppColors.primary.withAlpha(35),
      side: BorderSide(color: isActive ? AppColors.primary : AppColors.border),
      labelStyle: TextStyle(
        color: isActive ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildSummaryCard({
    required int totalCount,
    required double totalAmount,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Жалпы сан',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalCount заказ',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 34, color: AppColors.border),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Жалпы сумма',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${totalAmount.round()} сом',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDeleteOrder(
    Order order,
    OrdersCubit ordersCubit,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Заказды өчүрүү'),
        content: Text('№${order.id} заказын өчүрөсүзбү?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Жок'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ооба'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await _orderApi.deleteOrder(widget.token, order.id);
      if (!mounted) return;
      await ordersCubit.loadOrders(widget.token);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заказ өчүрүлдү')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Future<void> _confirmClearAll(OrdersCubit ordersCubit) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep, color: AppColors.danger),
            SizedBox(width: 12),
            Text('Бардыгын тазалоо'),
          ],
        ),
        content: const Text(
          'Бардык аяктаган жана жокко чыгарылган заказдарды тазалайсызбы?\n\nБул аракетти кайтаруу мүмкүн эмес.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Жокко чыгаруу'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Тазалоо'),
          ),
        ],
      ),
    );

    if (shouldClear != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final result = await _orderApi.deleteAllOrders(widget.token);
      if (!mounted) return;
      await ordersCubit.loadOrders(widget.token);
      if (!mounted) return;
      final message = result['message'] as String? ?? 'Заказдар тазаланды';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.accent3),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  List<Order> _historyOrders(
    List<Order> orders,
    String query,
    _HistoryPeriod period,
  ) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final periodStart = switch (period) {
      _HistoryPeriod.sevenDays => now.subtract(const Duration(days: 7)),
      _HistoryPeriod.thirtyDays => now.subtract(const Duration(days: 30)),
      _HistoryPeriod.thisMonth => monthStart,
    };

    var filtered = orders
        .where(
          (order) =>
              order.status == 'completed' ||
              order.status == 'delivered' ||
              order.status == 'cancelled',
        )
        .where((order) => _parseDate(order.createdAt).isAfter(periodStart))
        .toList();

    // Apply advanced filters
    if (_advancedFilterOptions != null &&
        _advancedFilterOptions!.hasActiveFilters) {
      filtered = filtered
          .where((order) => _advancedFilterOptions!.matchesOrder(order))
          .toList();
    }

    // Sort by date
    filtered.sort(
      (a, b) => _parseDate(b.createdAt).compareTo(_parseDate(a.createdAt)),
    );

    if (query.isEmpty) return filtered;

    return filtered.where((order) {
      final content = [
        '#${order.id}',
        order.category,
        order.categoryName,
        order.fromAddress,
        order.toAddress,
        order.status,
      ].join(' ').toLowerCase();
      return content.contains(query);
    }).toList();
  }

  List<_HistorySection> _buildSections(List<Order> orders) {
    final sections = <_HistorySection>[];
    String? lastMonthKey;
    String? lastDayKey;

    for (final order in orders) {
      final date = _parseDate(order.createdAt);
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final dayKey = '$monthKey-${date.day.toString().padLeft(2, '0')}';

      if (monthKey != lastMonthKey) {
        sections.add(
          _HistorySection(
            title: _monthLabel(date),
            orders: const [],
            isMonthHeader: true,
          ),
        );
        lastMonthKey = monthKey;
        lastDayKey = null;
      }

      if (dayKey != lastDayKey) {
        sections.add(
          _HistorySection(
            title: _dayLabel(date),
            orders: [order],
            isMonthHeader: false,
          ),
        );
        lastDayKey = dayKey;
      } else {
        final lastIndex = sections.length - 1;
        sections[lastIndex] = _HistorySection(
          title: sections[lastIndex].title,
          orders: [...sections[lastIndex].orders, order],
          isMonthHeader: false,
        );
      }
    }

    return sections;
  }

  DateTime _parseDate(String raw) {
    try {
      final utc = raw.endsWith('Z') ? raw : '${raw}Z';
      return DateTime.parse(utc).toLocal();
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  String _monthLabel(DateTime date) {
    const months = [
      '',
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];
    return '${months[date.month]} ${date.year}';
  }

  String _dayLabel(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _HistorySection {
  const _HistorySection({
    required this.title,
    required this.orders,
    required this.isMonthHeader,
  });

  final String title;
  final List<Order> orders;
  final bool isMonthHeader;
}

class _HistoryOrderCard extends StatelessWidget {
  const _HistoryOrderCard({
    required this.order,
    required this.isCourier,
    required this.token,
    required this.canDelete,
    required this.onDelete,
  });

  final Order order;
  final bool isCourier;
  final String token;
  final bool canDelete;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final accentColor = _statusColor(order.status);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderDetailPage(
              order: order,
              token: token,
              isCourier: isCourier,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${order.id}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    if (canDelete)
                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.danger,
                        ),
                        tooltip: 'Өчүрүү',
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _statusLabel(order.status),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${order.fromAddress} → ${order.toAddress}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${order.distance} км',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                Text(
                  '${order.estimatedPrice?.round() ?? 0} сом',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'cancelled':
        return AppColors.accent5;
      case 'completed':
      case 'delivered':
        return AppColors.accent4;
      default:
        return AppColors.primary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'cancelled':
        return 'Жокко чыгарылды';
      case 'completed':
      case 'delivered':
        return 'Аякталды';
      default:
        return status;
    }
  }
}
