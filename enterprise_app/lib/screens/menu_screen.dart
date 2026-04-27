import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
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
        title: const Text('Меню',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [Tab(text: 'Товарлар'), Tab(text: 'Категориялар')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_ProductsTab(), _CategoriesTab()],
      ),
    );
  }
}

// ─── Products tab ────────────────────────────────────────────────────────────

class _ProductsTab extends StatefulWidget {
  const _ProductsTab();
  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<dynamic> _products = [];
  List<dynamic> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Future.wait(
          [ApiService.getProducts(), ApiService.getCategories()]);
      if (mounted) {
        setState(() {
          _products = r[0];
          _categories = r[1];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _catName(int? id) {
    if (id == null) return '';
    final c = _categories.cast<Map<String, dynamic>>()
        .where((c) => c['id'] == id)
        .firstOrNull;
    return c?['name'] as String? ?? '';
  }

  Future<void> _addOrEdit([Map<String, dynamic>? existing]) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ProductForm(
        categories: _categories,
        existing: existing,
      ),
    );
    if (result == true) _load();
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Товарды өчүрүү'),
        content: const Text('Бул товарды өчүрүүнү каалайсызбы?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Жок')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Өчүрүү',
                  style: TextStyle(color: Color(0xFFDC2626)))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deleteProduct(id);
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(),
        backgroundColor: const Color(0xFF16A34A),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _products.isEmpty
                  ? _empty('Товар жок. + басып кошуңуз.')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
                      itemCount: _products.length,
                      itemBuilder: (_, i) {
                        final p = _products[i] as Map<String, dynamic>;
                        final active = p['is_active'] == true;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2)),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            leading: _productImage(p),
                            title: Text(p['name'] as String,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: active
                                        ? const Color(0xFF111827)
                                        : const Color(0xFF9CA3AF))),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${(p['price'] as num).toStringAsFixed(0)} сом',
                                    style: const TextStyle(
                                        color: Color(0xFF16A34A),
                                        fontWeight: FontWeight.w700)),
                                if (_catName(p['category_id'] as int?) .isNotEmpty)
                                  Text(_catName(p['category_id'] as int?),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF9CA3AF))),
                              ],
                            ),
                            trailing: Row(mainAxisSize: MainAxisSize.min,
                                children: [
                              if (!active)
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Text('Жок',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF9CA3AF))),
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 20, color: Color(0xFF6B7280)),
                                onPressed: () => _addOrEdit(p),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 20, color: Color(0xFFDC2626)),
                                onPressed: () =>
                                    _delete(p['id'] as int),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  static Widget _productImage(Map<String, dynamic> p) {
    final url = p['image_url'] as String?;
    if (url != null && url.isNotEmpty) {
      final img = url.startsWith('data:')
          ? null
          : Image.network(url,
              width: 46, height: 46, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.fastfood, color: Color(0xFF9CA3AF)));
      return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: img ?? const Icon(Icons.fastfood, color: Color(0xFF9CA3AF)));
    }
    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.fastfood, color: Color(0xFF9CA3AF), size: 22),
    );
  }

  static Widget _empty(String text) => ListView(children: [
    const SizedBox(height: 200),
    Center(child: Column(children: [
      const Icon(Icons.menu_book_outlined, size: 56, color: Color(0xFFD1D5DB)),
      const SizedBox(height: 12),
      Text(text, style: const TextStyle(color: Color(0xFF9CA3AF))),
    ])),
  ]);
}

// ─── Product Form ─────────────────────────────────────────────────────────────

class _ProductForm extends StatefulWidget {
  final List<dynamic> categories;
  final Map<String, dynamic>? existing;
  const _ProductForm({required this.categories, this.existing});

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int? _catId;
  bool _active = true;
  bool _saving = false;
  File? _imageFile;
  int? _productId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _productId = e['id'] as int?;
      _nameCtrl.text = e['name'] as String? ?? '';
      _priceCtrl.text =
          (e['price'] as num?)?.toStringAsFixed(0) ?? '';
      _descCtrl.text = e['description'] as String? ?? '';
      _catId = e['category_id'] as int?;
      _active = e['is_active'] as bool? ?? true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final p =
        await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (p != null) setState(() => _imageFile = File(p.path));
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final price = double.tryParse(_priceCtrl.text.trim());
    if (price == null || price <= 0) return;

    setState(() => _saving = true);
    try {
      final data = {
        'name': _nameCtrl.text.trim(),
        'price': price,
        'description': _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        'category_id': _catId,
        'is_active': _active,
      };

      if (_productId != null) {
        await ApiService.updateProduct(_productId!, data);
        if (_imageFile != null) {
          await ApiService.uploadProductImage(_productId!, _imageFile!);
        }
      } else {
        await ApiService.createProduct(data);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _productId != null;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(isEdit ? 'Товарды өзгөртүү' : 'Жаңы товар',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),

          // Image picker
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity, height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: _imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(_imageFile!, fit: BoxFit.cover))
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 28, color: Color(0xFF9CA3AF)),
                        SizedBox(height: 4),
                        Text('Сүрөт кошуу',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF9CA3AF))),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),

          _tf(_nameCtrl, 'Товар аты *'),
          const SizedBox(height: 10),
          _tf(_priceCtrl, 'Баасы (сом) *',
              type: TextInputType.number),
          const SizedBox(height: 10),
          _tf(_descCtrl, 'Сүрөттөмө'),
          const SizedBox(height: 10),

          // Category
          DropdownButtonFormField<int?>(
            value: _catId,
            decoration: _dec('Категория'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Категориясыз')),
              ...widget.categories.map((c) => DropdownMenuItem(
                    value: c['id'] as int,
                    child: Text(c['name'] as String),
                  )),
            ],
            onChanged: (v) => setState(() => _catId = v),
          ),
          const SizedBox(height: 10),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Активдүү'),
            value: _active,
            activeColor: const Color(0xFF16A34A),
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(isEdit ? 'Сактоо' : 'Кошуу',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  static Widget _tf(TextEditingController c, String hint,
      {TextInputType type = TextInputType.text}) =>
      TextField(
        controller: c,
        keyboardType: type,
        decoration: _dec(hint),
      );

  static InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
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
  );
}

// ─── Categories tab ───────────────────────────────────────────────────────────

class _CategoriesTab extends StatefulWidget {
  const _CategoriesTab();
  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<dynamic> _cats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getCategories();
      if (mounted) setState(() { _cats = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addOrEdit([Map<String, dynamic>? existing]) async {
    final ctrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Категория кошуу' : 'Өзгөртүү'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Категория аты'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Жок')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A)),
            child: const Text('Сактоо',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (saved == null || saved.isEmpty) return;
    try {
      if (existing == null) {
        await ApiService.createCategory(saved);
      } else {
        await ApiService.updateCategory(existing['id'] as int, saved);
      }
      _load();
    } catch (_) {}
  }

  Future<void> _delete(int id) async {
    try {
      await ApiService.deleteCategory(id);
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(),
        backgroundColor: const Color(0xFF16A34A),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _cats.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 200),
                      Center(
                        child: Text('Категория жок. + басып кошуңуз.',
                            style: TextStyle(color: Color(0xFF9CA3AF))),
                      ),
                    ])
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
                      itemCount: _cats.length,
                      onReorder: (_, __) {},
                      itemBuilder: (_, i) {
                        final c = _cats[i] as Map<String, dynamic>;
                        return Container(
                          key: ValueKey(c['id']),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.drag_handle,
                                color: Color(0xFF9CA3AF)),
                            title: Text(c['name'] as String,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 20, color: Color(0xFF6B7280)),
                                onPressed: () => _addOrEdit(c),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 20, color: Color(0xFFDC2626)),
                                onPressed: () => _delete(c['id'] as int),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
