import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/map_picker.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});
  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  List<dynamic> _products = [];
  List<dynamic> _categories = [];
  final Map<int, int> _qty = {};
  bool _loadingProducts = true;
  bool _submitting = false;
  bool _showCart = false;
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
          _products = results[0]
              .where((p) => p['is_active'] == true)
              .toList();
          _categories = results[1];
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
      final q = _qty[p['id'] as int] ?? 0;
      if (q > 0) t += (p['price'] as num).toDouble() * q;
    }
    return t;
  }

  int get _itemCount =>
      _qty.values.fold(0, (sum, q) => sum + q);

  List<Map<String, dynamic>> get _selectedItems => _products
      .where((p) => (_qty[p['id'] as int] ?? 0) > 0)
      .map((p) => {
            'product_id': p['id'],
            'quantity': _qty[p['id'] as int]!,
            'name': p['name'],
            'price': p['price'],
          })
      .toList();

  Future<void> _pickAddressFromMap() async {
    final result = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => const MapPickerPage(needAddress: true),
      ),
    );
    if (result == null) return;
    if (result.address != null && result.address!.isNotEmpty) {
      _addressCtrl.text = result.address!;
    } else {
      _addressCtrl.text =
          '${result.lat.toStringAsFixed(5)}, ${result.lon.toStringAsFixed(5)}';
    }
  }

  Future<void> _submit() async {
    if (_selectedItems.isEmpty) {
      setState(() => _error = 'Товар тандаңыз');
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Кардардын телефонун жазыңыз');
      return;
    }
    if (_addressCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Жеткирүү дарегин жазыңыз');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final data = {
        'order_type': 'delivery',
        'customer_phone': _phoneCtrl.text.trim(),
        'to_address': _addressCtrl.text.trim(),
        'items': _selectedItems
            .map((i) => {'product_id': i['product_id'], 'quantity': i['quantity']})
            .toList(),
        if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
      };

      final order = await ApiService.createLocalOrder(data);
      if (!mounted) return;

      setState(() {
        _qty.clear();
        _submitting = false;
        _showCart = false;
      });
      _phoneCtrl.clear();
      _addressCtrl.clear();
      _noteCtrl.clear();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Заказ #${order['id']} түзүлдү'),
        backgroundColor: const Color(0xFF16A34A),
      ));
    } catch (e) {
      String msg = e.toString();
      final m = RegExp(r'"detail":"([^"]+)"').firstMatch(msg);
      if (m != null) msg = m.group(1)!;
      setState(() {
        _error = msg;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        toolbarHeight: 48,
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        title: const Text('🛵 Жеткирүү заказы',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        actions: [
          if (_itemCount > 0)
            GestureDetector(
              onTap: () => setState(() => _showCart = !_showCart),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                ),
                child: Row(children: [
                  const Icon(Icons.shopping_cart_outlined, size: 16),
                  const SizedBox(width: 4),
                  Text('$_itemCount',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  Text('· ${_total.toStringAsFixed(0)} с',
                      style: const TextStyle(fontSize: 12)),
                ]),
              ),
            ),
        ],
      ),
      body: _loadingProducts
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // Cart preview panel
              if (_showCart && _selectedItems.isNotEmpty)
                _CartPanel(
                  items: _selectedItems,
                  total: _total,
                  onRemove: (id) => setState(() => _qty.remove(id)),
                  onClose: () => setState(() => _showCart = false),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    // Customer info
                    _section('Кардар маалыматы', [
                      _field(_phoneCtrl, 'Телефон номери *',
                          Icons.phone_outlined,
                          type: TextInputType.phone),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _addressCtrl,
                        decoration: InputDecoration(
                          hintText: 'Жеткирүү дареги *',
                          prefixIcon: const Icon(Icons.location_on_outlined,
                              size: 18, color: Color(0xFF9CA3AF)),
                          suffixIcon: IconButton(
                            tooltip: 'Картадан тандоо',
                            icon: const Icon(Icons.map_outlined,
                                color: Color(0xFF16A34A)),
                            onPressed: _pickAddressFromMap,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE5E7EB))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE5E7EB))),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
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
                            child: Text('Товар жок. Меню бөлүмүнөн кошуңуз.',
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

                    // Total + submit
                    if (_total > 0)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF16A34A)
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.receipt_outlined,
                              color: Color(0xFF16A34A), size: 18),
                          const SizedBox(width: 8),
                          const Text('Жалпы сумма:',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text('${_total.toStringAsFixed(0)} сом',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: Color(0xFF16A34A))),
                        ]),
                      ),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
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
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Заказ берүү',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ]),
    );
  }

  List<Widget> _buildProductList() {
    final catMap = <int?, List<dynamic>>{};
    for (final p in _products) {
      catMap.putIfAbsent(p['category_id'] as int?, () => []).add(p);
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
        widgets.add(_ProductRow(
          product: p,
          qty: q,
          onAdd: () => setState(() => _qty[id] = q + 1),
          onRemove: q > 0 ? () => setState(() => _qty[id] = q - 1) : null,
        ));
      }
    }
    return widgets;
  }

  static Widget _section(String title, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF111827))),
          const SizedBox(height: 12),
          ...children,
        ]),
      );

  static Widget _field(
    TextEditingController c,
    String hint,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) =>
      TextField(
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      );
}

// ─── Product Row ──────────────────────────────────────────────────────────────

class _ProductRow extends StatelessWidget {
  final dynamic product;
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;
  const _ProductRow(
      {required this.product,
      required this.qty,
      required this.onAdd,
      required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final price = (product['price'] as num).toDouble();
    final imageUrl = product['image_url'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: qty > 0
            ? const Color(0xFF16A34A).withValues(alpha: 0.05)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: qty > 0
              ? const Color(0xFF16A34A).withValues(alpha: 0.3)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(children: [
        // Product image
        if (imageUrl != null && imageUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: _productImage(imageUrl),
          )
        else
          _placeholder(),
        const SizedBox(width: 10),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(product['name'] as String,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          Text('${price.toStringAsFixed(0)} сом',
              style: const TextStyle(
                  color: Color(0xFF16A34A), fontWeight: FontWeight.w700)),
          if (qty > 0)
            Text('= ${(price * qty).toStringAsFixed(0)} сом',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF6B7280))),
        ])),
        // Qty controls
        Row(children: [
          _qBtn(Icons.remove, onRemove),
          Container(
            width: 32,
            alignment: Alignment.center,
            child: Text('$qty',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          _qBtn(Icons.add, onAdd),
        ]),
      ]),
    );
  }

  static Widget _productImage(String url) {
    if (url.startsWith('data:')) {
      final comma = url.indexOf(',');
      if (comma == -1) return _placeholder();
      try {
        final bytes = base64Decode(url.substring(comma + 1));
        return Image.memory(bytes, width: 40, height: 40, fit: BoxFit.cover,
            errorBuilder: (_, e, s) => _placeholder());
      } catch (_) {
        return _placeholder();
      }
    }
    return Image.network(url, width: 40, height: 40, fit: BoxFit.cover,
        errorBuilder: (_, e, s) => _placeholder());
  }

  static Widget _placeholder() => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.fastfood, size: 20, color: Color(0xFF9CA3AF)),
      );

  static Widget _qBtn(IconData icon, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: onTap != null
                ? const Color(0xFF16A34A)
                : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 16,
              color: onTap != null ? Colors.white : const Color(0xFF9CA3AF)),
        ),
      );
}

// ─── Cart Panel ───────────────────────────────────────────────────────────────

class _CartPanel extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final double total;
  final void Function(int id) onRemove;
  final VoidCallback onClose;

  const _CartPanel({
    required this.items,
    required this.total,
    required this.onRemove,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFF16A34A).withValues(alpha: 0.06),
          child: Row(children: [
            const Icon(Icons.shopping_cart,
                size: 16, color: Color(0xFF16A34A)),
            const SizedBox(width: 6),
            const Text('Тандалган товарлар',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
            const Spacer(),
            Text('${total.toStringAsFixed(0)} сом',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF16A34A))),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClose,
              child: const Icon(Icons.keyboard_arrow_up,
                  color: Color(0xFF6B7280)),
            ),
          ]),
        ),
        // Items list
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              final name = item['name'] as String;
              final qty = item['quantity'] as int;
              final price = (item['price'] as num).toDouble();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text('$qty',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(name,
                          style: const TextStyle(fontSize: 13))),
                  Text('${(price * qty).toStringAsFixed(0)} с',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => onRemove(item['product_id'] as int),
                    child: const Icon(Icons.close,
                        size: 16, color: Color(0xFF9CA3AF)),
                  ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}
