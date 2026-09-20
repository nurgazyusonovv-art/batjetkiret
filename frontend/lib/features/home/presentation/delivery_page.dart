import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/utils/distance_calculator.dart';
import 'package:frontend/core/widgets/app_button.dart';
import 'package:frontend/features/home/data/category_model.dart' as models;
import 'package:frontend/features/home/data/enterprise_api.dart';
import 'package:frontend/features/home/data/enterprise_model.dart';
import 'package:frontend/features/home/presentation/home_page.dart';
import 'package:geolocator/geolocator.dart';

/// Delivery browse screen — search, category chips and the enterprise list.
///
/// This is the old home body, minus the banner carousel: the carousel now
/// lives only on the services home screen.
class DeliveryPage extends StatefulWidget {
  final String token;
  final String? initialCategoryId;

  const DeliveryPage({super.key, required this.token, this.initialCategoryId});

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  // Taxi / intercity are ordered from the services home, not from here.
  static const _actionCategories = {'taxi', 'intercity'};

  late final List<models.Category> _categories;
  late String _selectedCategoryId;

  List<Enterprise> _enterprises = [];
  bool _loading = false;
  String? _error;
  int _fetchVersion = 0;

  final _searchController = TextEditingController();
  String _search = '';
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    _categories = models.categories
        .where((c) => !_actionCategories.contains(c.id))
        .toList();
    final requested = widget.initialCategoryId;
    _selectedCategoryId =
        _categories.any((c) => c.id == requested) && requested != null
        ? requested
        : _categories.first.id;
    _searchController.addListener(
      () => setState(() => _search = _searchController.text.trim()),
    );
    _loadEnterprises(_selectedCategoryId);
    _fetchUserLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Silent location read — only if permission is already granted (no prompt here).
  Future<void> _fetchUserLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      if (!mounted) return;
      setState(
        () => _userLocation = LatLng(
          latitude: pos.latitude,
          longitude: pos.longitude,
        ),
      );
    } catch (_) {}
  }

  double? _enterpriseDistanceKm(Enterprise e) {
    if (_userLocation == null || e.lat == null || e.lon == null) return null;
    return DistanceCalculator.calculateDistance(
      from: _userLocation!,
      to: LatLng(latitude: e.lat!, longitude: e.lon!),
    );
  }

  String _formatDistance(double km) =>
      km < 1 ? '${(km * 1000).round()} м' : '${km.toStringAsFixed(1)} км';

  List<Enterprise> get _visibleEnterprises {
    if (_search.isEmpty) return _enterprises;
    final q = _search.toLowerCase();
    return _enterprises
        .where(
          (e) =>
              e.name.toLowerCase().contains(q) ||
              (e.address ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _loadEnterprises(String categoryId) async {
    final version = ++_fetchVersion;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await EnterpriseApi().fetchEnterprises(
        token: widget.token,
        category: categoryId,
      );
      if (!mounted || version != _fetchVersion) return;
      setState(() {
        _enterprises = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || version != _fetchVersion) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _selectCategory(models.Category category) {
    if (_selectedCategoryId == category.id) return;
    setState(() {
      _selectedCategoryId = category.id;
      _searchController.clear();
      _search = '';
    });
    _loadEnterprises(category.id);
  }

  void _openEnterpriseDirectly(int enterpriseId, String category) {
    final cat = models.categories.firstWhere(
      (c) => c.id == category,
      orElse: () => models.categories.first,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderCreatePage(
          token: widget.token,
          selectedCategory: cat,
          initialEnterpriseId: enterpriseId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = _categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => _categories.first,
    );
    final visible = _visibleEnterprises;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Жеткирүү',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: Listener(
        onPointerDown: (_) => FocusScope.of(context).unfocus(),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildSearchBar(),
              const SizedBox(height: 10),
              _buildCategoryChips(),
              const SizedBox(height: 12),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => _loadEnterprises(_selectedCategoryId),
                  child: ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    children: [
                      _buildSectionTitle(selectedCategory, visible.length),
                      _buildEnterpriseSection(visible),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(models.Category category, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (!_loading && _error == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Search bar ───────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            isCollapsed: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            hintText: 'Ишкана издөө...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 21),
            suffixIcon: _search.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[500], size: 19),
                    onPressed: () => _searchController.clear(),
                  ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }

  // ── Horizontal category chips ────────────────────────────────────────────────
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 116,
      child: Stack(
        children: [
          ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 2, 28, 6),
            itemCount: _categories.length + 1, // + trailing "all" chip
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == _categories.length) {
                return _buildAllCategoriesChip();
              }
              final category = _categories[index];
              return _categoryChip(
                selected: category.id == _selectedCategoryId,
                onTap: () => _selectCategory(category),
                label: category.name,
                imageTile: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(category.icon, fit: BoxFit.cover),
                ),
              );
            },
          ),
          // Right-edge fade hints there are more categories to scroll.
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.background.withValues(alpha: 0),
                      AppColors.background,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip({
    required bool selected,
    required VoidCallback onTap,
    required String label,
    required Widget imageTile,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 84,
        height: 104,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.20)
                  : Colors.black.withValues(alpha: 0.035),
              blurRadius: selected ? 10 : 6,
              offset: Offset(0, selected ? 4 : 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: imageTile,
            ),
            const SizedBox(height: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllCategoriesChip() {
    return _categoryChip(
      selected: false,
      onTap: _openCategoriesSheet,
      label: 'Баары',
      imageTile: const Icon(
        Icons.grid_view_rounded,
        color: AppColors.primary,
        size: 26,
      ),
    );
  }

  // Bottom sheet showing every category in a grid for quick discovery.
  void _openCategoriesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Категориялар',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.82,
                  children: [
                    for (final c in _categories)
                      GestureDetector(
                        onTap: () {
                          Navigator.of(sheetCtx).pop();
                          _selectCategory(c);
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: c.id == _selectedCategoryId
                                    ? AppColors.primarySoft
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(16),
                                border: c.id == _selectedCategoryId
                                    ? Border.all(
                                        color: AppColors.primary,
                                        width: 2,
                                      )
                                    : null,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.asset(c.icon, fit: BoxFit.cover),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              c.name,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.1,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Enterprise list ──────────────────────────────────────────────────────────
  Widget _buildEnterpriseSection(List<Enterprise> visible) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 44, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            AppButton.primary(
              onPressed: () => _loadEnterprises(_selectedCategoryId),
              label: 'Кайра жүктөө',
            ),
          ],
        ),
      );
    }
    if (visible.isEmpty) {
      final searching = _search.isNotEmpty;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          children: [
            Icon(
              searching ? Icons.search_off : Icons.storefront_outlined,
              size: 46,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              searching
                  ? '«$_search» боюнча эч нерсе табылган жок'
                  : 'Бул категорияда ишкана жок',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
          ],
        ),
      );
    }
    return Column(children: [for (final e in visible) _buildEnterpriseCard(e)]);
  }

  Widget _buildEnterpriseCard(Enterprise e) {
    final closed = e.isOpen == false;
    final prep = e.prepTimeMinutes;
    final distance = _enterpriseDistanceKm(e);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 9,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openEnterpriseDirectly(e.id, _selectedCategoryId),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Logo with a soft frame; dimmed when the shop is closed.
                  Opacity(
                    opacity: closed ? 0.55 : 1,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: AppColors.primarySoft,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _enterpriseLogo(e),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if ((e.address ?? '').isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(
                                Icons.place_outlined,
                                size: 13,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  e.address!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _statusPill(closed),
                            if (prep != null && prep > 0)
                              _metaPill(Icons.schedule, '$prep мин'),
                            if (distance != null)
                              _metaPill(
                                Icons.near_me_outlined,
                                _formatDistance(distance),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusPill(bool closed) {
    final color = closed ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
    final bg = closed ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            closed ? 'Жабык' : 'Ачык',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.5, color: AppColors.textSecondary),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _enterpriseLogo(Enterprise e) {
    final logo = e.logoData;
    if (logo != null && logo.isNotEmpty && logo.startsWith('http')) {
      return Image.network(
        logo,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _enterpriseLogoFallback(),
      );
    }
    return _enterpriseLogoFallback();
  }

  Widget _enterpriseLogoFallback() {
    return Container(
      color: AppColors.primarySoft,
      child: const Icon(Icons.storefront, color: AppColors.primary, size: 30),
    );
  }
}
