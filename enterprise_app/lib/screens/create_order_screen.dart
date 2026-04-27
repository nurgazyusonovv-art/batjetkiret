import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});
  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        toolbarHeight: 48,
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        title: const Text('Заказ түзүү',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: '🛵 Жеткирүү'),
            Tab(text: '🍽 Стол'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _OrderForm(orderType: 'delivery'),
          _OrderForm(orderType: 'dine_in'),
        ],
      ),
    );
  }
}

class _OrderForm extends StatefulWidget {
  final String orderType;
  const _OrderForm({required this.orderType});

  @override
  State<_OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends State<_OrderForm> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _tableCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  List<dynamic> _products = [];
  List<dynamic> _categories = [];
  final Map<int, int> _qty = {};
  bool _loadingProducts = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _tableCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final results = await Future.wait([
        ApiService.getProducts(),
        ApiService.getCategories(),
      ]);
      if (mounted) {
        setState(() {
          _products = (results[0] as List<dynamic>).where((p) => p['is_active'] == true).toList();
          _categories = results[1] as List<dynamic>;
          _loadingProducts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  double get _total {
    double t = 0;
    for (final p in _products) {
      final id = p['id'] as int;
      final q = _qty[id] ?? 0;
      if (q > 0) t += (p['price'] as num).toDouble() * q;
    }
    return t;
  }

  List<Map<String, dynamic>> get _selectedItems => _products
      .where((p) => (_qty[p['id'] as int] ?? 0) > 0)
      .map((p) => {'product_id': p['id'], 'quantity': _qty[p['id'] as int]!})
      .toList();

  Future<void> _submit() async {
    if (_selectedItems.isEmpty) {
      setState(() => _error = 'Товар тандаңыз');
      return;
    }
    if (widget.orderType == 'delivery' && _phoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Кардардын телефонун жазыңыз');
      return;
    }
    if (widget.orderType == 'delivery' && _addressCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Жеткирүү дарегин жазыңыз');
      return;
    }

    setState(() { _submitting = true; _error = null; });
    try {
      final data = <String, dynamic>{
        'order_type': widget.orderType,
        'items': _selectedItems,
        if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
      };
      if (widget.orderType == 'delivery') {
        data['customer_phone'] = _phoneCtrl.text.trim();
        data['to_address'] = _addressCtrl.text.trim();
      } else {
        if (_tableCtrl.text.trim().isNotEmpty) {
          data['table_number'] = int.tryParse(_tableCtrl.text.trim());
        }
        if (_phoneCtrl.text.trim().isNotEmpty) {
          data['customer_phone'] = _phoneCtrl.text.trim();
        }
      }

      final order = await ApiService.createLocalOrder(data);
      if (!mounted) return;

      setState(() { _qty.clear(); _submitting = false; });
      _phoneCtrl.clear();
      _addressCtrl.clear();
      _tableCtrl.clear();
      _noteCtrl.clear();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Заказ #${order['id']} түзүлдү'),
        backgroundColor: const Color(0xFF16A34A),
      ));
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('detail')) {
        final m = RegExp(r'"detail":"([^"]+)"').firstMatch(msg);
        if (m != null) msg = m.group(1)!;
      }
      setState(() { _error = msg; _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _loadingProducts
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(14),
            children: [
              // Customer info
              _section('Кардар маалыматы', [
                if (widget.orderType == 'delivery' ||
                    widget.orderType == 'dine_in') ...[
                  _field(_phoneCtrl, 'Телефон номери (милдеттүү эмес)',
                      Icons.phone_outlined,
                      type: TextInputType.phone,
                      required: widget.orderType == 'delivery'),
                ],
                if (widget.orderType == 'delivery') ...[
                  const SizedBox(height: 10),
                  _field(_addressCtrl, 'Жеткирүү дареги *',
                      Icons.location_on_outlined, required: true),
                ],
                if (widget.orderType == 'dine_in') ...[
                  const SizedBox(height: 10),
                  _field(_tableCtrl, 'Стол номери',
                      Icons.table_restaurant_outlined,
                      type: TextInputType.number),
                ],
                const SizedBox(height: 10),
                _field(_noteCtrl, 'Эскертүү (милдеттүү эмес)',
                    Icons.note_outlined),
              ]),
              const SizedBox(height: 14),

              // Products
              _section('Товарлар', [
                if (_products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text('Товар жок. Алгач меню бөлүмүнөн кошуңуз.',
                          style: TextStyle(color: Color(0xFF9CA3AF))),
                    ),
                  )
                else
                  ..._buildProductList(),
              ]),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(color: Color(0xFFDC2626))),
                ),
              ],

              const SizedBox(height: 16),
              if (_total > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Жалпы сумма:',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('${_total.toStringAsFixed(0)} сом',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: Color(0xFF16A34A))),
                    ],
                  ),
                ),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Заказ берүү',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
  }

  List<Widget> _buildProductList() {
    // Group by category
    final catMap = <int?, List<dynamic>>{};
    for (final p in _products) {
      final cid = p['category_id'] as int?;
      catMap.putIfAbsent(cid, () => []).add(p);
    }

    final widgets = <Widget>[];
    for (final entry in catMap.entries) {
      final catName = _categories
          .cast<Map<String, dynamic>>()
          .firstWhere((c) => c['id'] == entry.key,
              orElse: () => {'name': 'Башка'})['name'] as String;

      if (catMap.length > 1) {
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
          child: Text(catName,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF374151))),
        ));
      }

      for (final p in entry.value) {
        final id = p['id'] as int;
        final q = _qty[id] ?? 0;
        final price = (p['price'] as num).toDouble();
        widgets.add(Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: q > 0
                ? const Color(0xFF16A34A).withValues(alpha: 0.05)
                : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: q > 0
                  ? const Color(0xFF16A34A).withValues(alpha: 0.3)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['name'] as String,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text('${price.toStringAsFixed(0)} сом',
                    style: const TextStyle(
                        color: Color(0xFF16A34A), fontWeight: FontWeight.w700)),
              ],
            )),
            Row(children: [
              _qtyBtn(Icons.remove, q > 0
                  ? () => setState(() => _qty[id] = q - 1)
                  : null),
              SizedBox(
                width: 28,
                child: Text('$q',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              _qtyBtn(Icons.add,
                  () => setState(() => _qty[id] = q + 1)),
            ]),
          ]),
        ));
      }
    }
    return widgets;
  }

  static Widget _qtyBtn(IconData icon, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: onTap != null
            ? const Color(0xFF16A34A)
            : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16,
          color: onTap != null ? Colors.white : const Color(0xFF9CA3AF)),
    ),
  );

  static Widget _section(String title, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2)),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 14,
              color: Color(0xFF111827))),
      const SizedBox(height: 12),
      ...children,
    ]),
  );

  static Widget _field(
    TextEditingController c, String hint, IconData icon, {
    TextInputType type = TextInputType.text,
    bool required = false,
  }) {
    return TextField(
      controller: c,
      keyboardType: type,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: required
                  ? const Color(0xFFDC2626).withValues(alpha: 0.3)
                  : const Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
