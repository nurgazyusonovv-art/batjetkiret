import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';

class AdvancedFilterDialog extends StatefulWidget {
  final Function(AdvancedFilterOptions) onApply;
  final AdvancedFilterOptions? initialOptions;

  const AdvancedFilterDialog({
    Key? key,
    required this.onApply,
    this.initialOptions,
  }) : super(key: key);

  @override
  State<AdvancedFilterDialog> createState() => _AdvancedFilterDialogState();
}

class _AdvancedFilterDialogState extends State<AdvancedFilterDialog> {
  final TextEditingController _orderIdController = TextEditingController();
  DateTimeRange? _dateRange;
  RangeValues _priceRange = const RangeValues(0, 10000);
  double? _minPrice;
  double? _maxPrice;

  @override
  void initState() {
    super.initState();
    if (widget.initialOptions != null) {
      final options = widget.initialOptions!;
      if (options.orderId != null) {
        _orderIdController.text = options.orderId!;
      }
      _dateRange = options.dateRange;
      if (options.minPrice != null || options.maxPrice != null) {
        _priceRange = RangeValues(
          options.minPrice ?? 0,
          options.maxPrice ?? 10000,
        );
        _minPrice = options.minPrice;
        _maxPrice = options.maxPrice;
      }
    }
  }

  @override
  void dispose() {
    _orderIdController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _orderIdController.clear();
      _dateRange = null;
      _priceRange = const RangeValues(0, 10000);
      _minPrice = null;
      _maxPrice = null;
    });
  }

  bool get _hasActiveFilters {
    return _orderIdController.text.isNotEmpty ||
        _dateRange != null ||
        _minPrice != null ||
        _maxPrice != null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Кошумча фильтр',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Order ID Search
              const Text(
                'Заказ ID',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _orderIdController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Заказ номерин киргизиңиз',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Date Range
              const Text(
                'Дата',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppColors.primary,
                            surface: AppColors.surface,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (range != null) {
                    setState(() => _dateRange = range);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _dateRange != null
                              ? '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}'
                              : 'Датаны тандаңыз',
                          style: TextStyle(
                            color: _dateRange != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (_dateRange != null)
                        IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => setState(() => _dateRange = null),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Price Range
              const Text(
                'Наркы (SOM)',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              RangeSlider(
                values: _priceRange,
                min: 0,
                max: 10000,
                divisions: 100,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.textSecondary.withOpacity(0.2),
                labels: RangeLabels(
                  '${_priceRange.start.toInt()} SOM',
                  '${_priceRange.end.toInt()} SOM',
                ),
                onChanged: (range) {
                  setState(() {
                    _priceRange = range;
                    _minPrice = range.start;
                    _maxPrice = range.end;
                  });
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_priceRange.start.toInt()} SOM',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${_priceRange.end.toInt()} SOM',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  if (_hasActiveFilters)
                    Expanded(
                      child: AppButton.secondary(
                        onPressed: _clearFilters,
                        label: 'Тазалоо',
                      ),
                    ),
                  if (_hasActiveFilters) const SizedBox(width: 12),
                  Expanded(
                    child: AppButton.primary(
                      onPressed: () {
                        final options = AdvancedFilterOptions(
                          orderId: _orderIdController.text.isEmpty
                              ? null
                              : _orderIdController.text,
                          dateRange: _dateRange,
                          minPrice: _minPrice,
                          maxPrice: _maxPrice,
                        );
                        Navigator.pop(context);
                        widget.onApply(options);
                      },
                      label: 'Колдонуу',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class AdvancedFilterOptions {
  final String? orderId;
  final DateTimeRange? dateRange;
  final double? minPrice;
  final double? maxPrice;

  const AdvancedFilterOptions({
    this.orderId,
    this.dateRange,
    this.minPrice,
    this.maxPrice,
  });

  bool get hasActiveFilters {
    return orderId != null ||
        dateRange != null ||
        minPrice != null ||
        maxPrice != null;
  }

  bool matchesOrder(dynamic order) {
    // Filter by Order ID
    if (orderId != null && orderId!.isNotEmpty) {
      final orderIdStr = order.id.toString();
      if (!orderIdStr.contains(orderId!)) {
        return false;
      }
    }

    // Filter by Date Range
    if (dateRange != null) {
      final createdAt = DateTime.tryParse(order.createdAt);
      if (createdAt != null) {
        final localDate = createdAt.toLocal();
        if (localDate.isBefore(dateRange!.start) ||
            localDate.isAfter(dateRange!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }
    }

    // Filter by Price Range
    if (minPrice != null && (order.estimatedPrice ?? 0) < minPrice!) {
      return false;
    }
    if (maxPrice != null && (order.estimatedPrice ?? 0) > maxPrice!) {
      return false;
    }

    return true;
  }
}
