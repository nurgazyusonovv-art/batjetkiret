import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/config.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/advertisements/data/advertisement_api.dart';
import 'package:frontend/features/advertisements/data/advertisement_model.dart';
import 'package:frontend/features/profile/presentation/topup_page.dart';
import 'package:frontend/features/auth/presentation/auth_page.dart';
import 'package:url_launcher/url_launcher.dart';

class AdvertisementsPage extends StatefulWidget {
  const AdvertisementsPage({
    super.key,
    required this.token,
    this.mineOnly = false,
  });

  final String token;
  final bool mineOnly;

  @override
  State<AdvertisementsPage> createState() => _AdvertisementsPageState();
}

class _AdvertisementsPageState extends State<AdvertisementsPage> {
  final _api = AdvertisementApi();
  final Set<int> _registeredViews = {};
  bool _loading = true;
  String? _error;
  List<Advertisement> _activeAds = [];
  List<Advertisement> _myAds = [];
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final active = widget.mineOnly
          ? <Advertisement>[]
          : await _api.getActive();
      final mine = widget.mineOnly
          ? await _api.getMine(widget.token)
          : <Advertisement>[];
      if (!mounted) return;
      setState(() {
        _activeAds = active;
        _myAds = mine;
        _loading = false;
      });
      _registerVisibleAds(active);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<String> get _categories {
    final values = _activeAds
        .map((ad) => ad.category?.trim())
        .whereType<String>()
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  List<Advertisement> get _filteredAds {
    final selected = _selectedCategory;
    if (selected == null) return _activeAds;
    return _activeAds.where((ad) => ad.category?.trim() == selected).toList();
  }

  Future<void> _openCreate() async {
    if (widget.token.isEmpty) {
      final shouldLogin = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Кирүү талап кылынат', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Жарнама кошуу үчүн аккаунтуңузга кириңиз же катталыңыз.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Жокко чыгаруу', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Кирүү / Катталуу'),
            ),
          ],
        ),
      );
      if (shouldLogin == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AuthPage()),
        );
      }
      return;
    }

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdvertisementCreatePage(token: widget.token),
      ),
    );
    if (created == true) _load();
  }

  Future<void> _registerVisibleAds(List<Advertisement> ads) async {
    for (final ad in ads) {
      if (_registeredViews.contains(ad.id)) continue;
      _registeredViews.add(ad.id);
      try {
        final count = await _api.registerView(ad.id);
        if (!mounted || count <= 0) continue;
        setState(() {
          _activeAds = _activeAds
              .map(
                (item) =>
                    item.id == ad.id ? item.copyWith(viewCount: count) : item,
              )
              .toList();
        });
      } catch (_) {
        _registeredViews.remove(ad.id);
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String actionLabel,
    Color actionColor = AppColors.primary,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Жок'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: actionColor),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _stopAd(Advertisement ad) async {
    final confirmed = await _confirm(
      title: 'Жарнаманы токтотуу',
      message: '"${ad.title}" жарнамасы активдүү тизмеден алынат.',
      actionLabel: 'Токтотуу',
      actionColor: const Color(0xFFF59E0B),
    );
    if (!confirmed) return;

    try {
      await _api.stop(token: widget.token, id: ad.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Жарнама токтотулду')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _deleteAd(Advertisement ad) async {
    final isPending = ad.status.toUpperCase() == 'PENDING';
    final confirmed = await _confirm(
      title: 'Жарнаманы өчүрүү',
      message: isPending
          ? 'Текшериле элек жарнама өчүрүлөт жана төлөм балансыңызга кайтарылат.'
          : '"${ad.title}" жарнамасы тизмеден өчүрүлөт.',
      actionLabel: 'Өчүрүү',
      actionColor: const Color(0xFFDC2626),
    );
    if (!confirmed) return;

    try {
      await _api.delete(token: widget.token, id: ad.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPending
                ? 'Жарнама өчүрүлүп, төлөм кайтарылды'
                : 'Жарнама өчүрүлдү',
          ),
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mineOnly = widget.mineOnly;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          mineOnly ? 'Менин жарнамаларым' : 'Жарнамалар',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Жарнама'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _load)
          : mineOnly
          ? RefreshIndicator(
              onRefresh: _load,
              child: _AdList(
                ads: _myAds,
                emptyTitle: 'Сиз жарнама кошо элексиз',
                showStatus: true,
                onStop: _stopAd,
                onDelete: _deleteAd,
              ),
            )
          : Column(
              children: [
                _CategoryFilter(
                  categories: _categories,
                  selected: _selectedCategory,
                  onSelected: (category) {
                    setState(() => _selectedCategory = category);
                  },
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: _AdList(
                      ads: _filteredAds,
                      emptyTitle: _selectedCategory == null
                          ? 'Азырынча активдүү жарнама жок'
                          : 'Бул категорияда жарнама жок',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SizedBox(
        height: 64,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          scrollDirection: Axis.horizontal,
          itemCount: categories.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final category = index == 0 ? null : categories[index - 1];
            final isSelected = selected == category;
            return ChoiceChip(
              avatar: index == 0
                  ? const Icon(Icons.grid_view_rounded, size: 17)
                  : null,
              label: Text(category ?? 'Бардык категориялар'),
              selected: isSelected,
              onSelected: (_) => onSelected(category),
              showCheckmark: false,
              backgroundColor: const Color(0xFFF4F6F8),
              selectedColor: AppColors.primarySoft,
              side: BorderSide(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : AppColors.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AdList extends StatelessWidget {
  const _AdList({
    required this.ads,
    required this.emptyTitle,
    this.showStatus = false,
    this.onStop,
    this.onDelete,
  });

  final List<Advertisement> ads;
  final String emptyTitle;
  final bool showStatus;
  final ValueChanged<Advertisement>? onStop;
  final ValueChanged<Advertisement>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (ads.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.campaign_outlined, size: 64, color: Colors.grey[350]),
          const SizedBox(height: 14),
          Text(
            emptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: ads.length,
      itemBuilder: (context, index) {
        final ad = ads[index];
        return _AdCard(
          ad: ad,
          showStatus: showStatus,
          onStop: onStop,
          onDelete: onDelete,
        );
      },
    );
  }
}

class _AdCard extends StatelessWidget {
  const _AdCard({
    required this.ad,
    required this.showStatus,
    this.onStop,
    this.onDelete,
  });

  final Advertisement ad;
  final bool showStatus;
  final ValueChanged<Advertisement>? onStop;
  final ValueChanged<Advertisement>? onDelete;

  @override
  Widget build(BuildContext context) {
    final imageUrl = AppConfig.mediaUrl(ad.imageUrl);
    final status = ad.status.toUpperCase();
    final canStop = status == 'ACTIVE' && onStop != null;
    final canDelete = status != 'DELETED' && onDelete != null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdvertisementDetailPage(ad: ad),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1.18,
                      child: Container(
                        color: const Color(0xFFF3F4F6),
                        child: imageUrl == null
                            ? const Icon(
                                Icons.campaign_rounded,
                                color: Colors.grey,
                                size: 34,
                              )
                            : Image.network(imageUrl, fit: BoxFit.cover),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showStatus) ...[
                              _StatusPill(status: ad.status),
                              const SizedBox(height: 6),
                            ],
                            Text(
                              ad.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Expanded(
                              child: Text(
                                ad.description,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                if ((ad.category ?? '').isNotEmpty) ...[
                                  Expanded(
                                    child: Text(
                                      ad.category!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Icon(
                                  Icons.visibility_outlined,
                                  size: 14,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${ad.viewCount}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (canStop || canDelete)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Row(
                  children: [
                    if (canStop)
                      Expanded(
                        child: _CompactActionButton(
                          icon: Icons.pause_circle_outline,
                          label: 'Токтот',
                          onPressed: () => onStop?.call(ad),
                        ),
                      ),
                    if (canStop && canDelete) const SizedBox(width: 6),
                    if (canDelete)
                      Expanded(
                        child: _CompactActionButton(
                          icon: Icons.delete_outline,
                          label: 'Өчүр',
                          color: const Color(0xFFDC2626),
                          onPressed: () => onDelete?.call(ad),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.24)),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 15),
        label: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class AdvertisementDetailPage extends StatelessWidget {
  const AdvertisementDetailPage({super.key, required this.ad});

  final Advertisement ad;

  String _normalizePhoneForWhatsApp(String phone) {
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.startsWith('+')) return normalized.substring(1);
    return normalized;
  }

  String _normalizePhoneForCall(String phone) {
    final cleaned = phone.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return '';
    if (cleaned.startsWith('+')) {
      final digits = cleaned.substring(1).replaceAll(RegExp(r'[^0-9]'), '');
      return digits.isEmpty ? '' : '+$digits';
    }
    return cleaned.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _callOwner(BuildContext context) async {
    final phone = _normalizePhoneForCall(ad.contactPhone ?? '');
    if (phone.isEmpty) {
      _showSnack(context, 'Чалуу үчүн номер табылган жок');
      return;
    }

    final opened = await launchUrl(
      Uri(scheme: 'tel', path: phone),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      _showSnack(context, 'Чалуу ачылбай калды');
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final phone = _normalizePhoneForWhatsApp(ad.contactPhone ?? '');
    if (phone.isEmpty) {
      _showSnack(context, 'WhatsApp үчүн номер табылган жок');
      return;
    }

    final message = Uri.encodeComponent(
      'Салам! "${ad.title}" жарнамасы боюнча жазып жатам.',
    );
    final uri = Uri.parse('https://wa.me/$phone?text=$message');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      _showSnack(context, 'WhatsApp ачылбай калды');
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = AppConfig.mediaUrl(ad.imageUrl);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Жарнама'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 220,
              color: const Color(0xFFF3F4F6),
              child: imageUrl == null
                  ? const Icon(
                      Icons.campaign_rounded,
                      size: 70,
                      color: Colors.grey,
                    )
                  : Image.network(imageUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            ad.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(status: ad.status),
              if ((ad.category ?? '').isNotEmpty)
                _MetaChip(Icons.category_outlined, ad.category!),
              if ((ad.userName ?? '').isNotEmpty)
                _MetaChip(Icons.person_outline, ad.userName!),
              _MetaChip(Icons.visibility_outlined, '${ad.viewCount} көрүү'),
            ],
          ),
          const SizedBox(height: 18),
          _InfoBlock(title: 'Маалымат', text: ad.description),
          if ((ad.contactPhone ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoBlock(title: 'Байланыш', text: ad.contactPhone!),
            const SizedBox(height: 12),
            _AdvertisementContactActions(
              onCall: () => _callOwner(context),
              onWhatsApp: () => _openWhatsApp(context),
            ),
          ],
          if ((ad.rejectionReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoBlock(title: 'Себеп', text: ad.rejectionReason!),
          ],
        ],
      ),
    );
  }
}

class AdvertisementCreatePage extends StatefulWidget {
  const AdvertisementCreatePage({super.key, required this.token});

  final String token;

  @override
  State<AdvertisementCreatePage> createState() =>
      _AdvertisementCreatePageState();
}

class _AdvertisementContactActions extends StatelessWidget {
  const _AdvertisementContactActions({
    required this.onCall,
    required this.onWhatsApp,
  });

  final VoidCallback onCall;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onCall,
            icon: const Icon(Icons.call_outlined, size: 20),
            label: const Text('Чалуу'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onWhatsApp,
            icon: const Icon(Icons.chat_bubble_outline, size: 20),
            label: const Text('WhatsApp'),
          ),
        ),
      ],
    );
  }
}

class _AdvertisementCreatePageState extends State<AdvertisementCreatePage> {
  final _api = AdvertisementApi();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _customCategoryCtrl = TextEditingController();
  AdvertisementSettings? _settings;
  PlatformFile? _imageFile;
  String _selectedCategory = 'Сатылат';
  bool _loadingSettings = true;
  bool _submitting = false;
  String? _error;

  static const _categories = [
    'Сатылат',
    'Кызмат',
    'Жумуш',
    'Ижара',
    'Жоголду',
    'Башка',
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_onFormChanged);
    _descCtrl.addListener(_onFormChanged);
    _phoneCtrl.addListener(_onFormChanged);
    _customCategoryCtrl.addListener(_onFormChanged);
    _loadSettings();
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onFormChanged);
    _descCtrl.removeListener(_onFormChanged);
    _phoneCtrl.removeListener(_onFormChanged);
    _customCategoryCtrl.removeListener(_onFormChanged);
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _customCategoryCtrl.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _api.getSettings(widget.token);
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _loadingSettings = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loadingSettings = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _imageFile = result.files.first);
  }

  Future<void> _submit() async {
    final settings = _settings;
    if (settings == null || _submitting) return;
    final validation = _validationMessage(settings);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await _api.uploadImage(
          token: widget.token,
          file: _imageFile!,
        );
      }
      await _api.create(
        token: widget.token,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _categoryValue,
        contactPhone: _phoneCtrl.text.trim(),
        imageUrl: imageUrl,
        durationDays: settings.defaultDurationDays,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Жарнама админ текшерүүсүнө жөнөтүлдү')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _submitting = false;
      });
    }
  }

  String get _categoryValue {
    if (_selectedCategory == 'Башка') {
      return _customCategoryCtrl.text.trim();
    }
    return _selectedCategory;
  }

  String? _validationMessage(AdvertisementSettings settings) {
    if (_titleCtrl.text.trim().length < 3) {
      return 'Аталышын кеминде 3 белги кылып жазыңыз';
    }
    if (_descCtrl.text.trim().length < 10) {
      return 'Жарнама текстин кеминде 10 белги кылып жазыңыз';
    }
    if (_selectedCategory == 'Башка' &&
        _customCategoryCtrl.text.trim().isEmpty) {
      return 'Категорияны жазыңыз';
    }
    if (settings.currentBalance < settings.price) {
      return 'Баланс жетишсиз. Алгач балансты толуктаңыз';
    }
    return null;
  }

  bool get _hasEnoughContent =>
      _titleCtrl.text.trim().length >= 3 && _descCtrl.text.trim().length >= 10;

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final canSubmit =
        settings != null &&
        _hasEnoughContent &&
        settings.currentBalance >= settings.price;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Жаңы жарнама'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      bottomNavigationBar: _loadingSettings || settings == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${settings.price.toStringAsFixed(0)} сом',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${settings.defaultDurationDays} күн активдүү',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _submitting || !canSubmit ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.rocket_launch_rounded),
                        label: Text(_submitting ? 'Жөнөтүлүүдө' : 'Жарыялоо'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          disabledForegroundColor: Colors.grey[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: _loadingSettings
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                _CreateHero(settings: settings),
                const SizedBox(height: 16),
                _ImagePickerCard(file: _imageFile, onPick: _pickImage),
                const SizedBox(height: 16),
                _CreateSection(
                  title: 'Негизги маалымат',
                  icon: Icons.edit_note_rounded,
                  children: [
                    _EnhancedField(
                      controller: _titleCtrl,
                      label: 'Кыска аталыш',
                      hint: 'Мисалы: iPhone 13 сатылат',
                      icon: Icons.title_rounded,
                      maxLength: 80,
                    ),
                    const SizedBox(height: 12),
                    _EnhancedField(
                      controller: _descCtrl,
                      label: 'Толук маалымат',
                      hint: 'Баасы, абалы, жайгашкан жери же шарттарын жазыңыз',
                      icon: Icons.notes_rounded,
                      maxLines: 6,
                      maxLength: 700,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _CreateSection(
                  title: 'Категория',
                  icon: Icons.category_rounded,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((category) {
                        final selected = category == _selectedCategory;
                        return ChoiceChip(
                          label: Text(category),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = category),
                          selectedColor: AppColors.primarySoft,
                          labelStyle: TextStyle(
                            color: selected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w800,
                          ),
                          side: BorderSide(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.35)
                                : AppColors.border,
                          ),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      }).toList(),
                    ),
                    if (_selectedCategory == 'Башка') ...[
                      const SizedBox(height: 12),
                      _EnhancedField(
                        controller: _customCategoryCtrl,
                        label: 'Категориянын аты',
                        hint: 'Мисалы: Үй буюмдары',
                        icon: Icons.sell_outlined,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _CreateSection(
                  title: 'Байланыш',
                  icon: Icons.call_rounded,
                  children: [
                    _EnhancedField(
                      controller: _phoneCtrl,
                      label: 'Телефон же WhatsApp',
                      hint: '996 XXX XXX XXX',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (settings != null) _PublishSummary(settings: settings),
                const SizedBox(height: 16),
                _PreviewCard(
                  title: _titleCtrl.text.trim(),
                  description: _descCtrl.text.trim(),
                  category: _categoryValue,
                  file: _imageFile,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFB91C1C),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (settings != null &&
                    settings.currentBalance < settings.price) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TopupPage(token: widget.token),
                      ),
                    ),
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: const Text('Баланс толуктоо'),
                  ),
                ],
              ],
            ),
    );
  }
}

class _CreateHero extends StatelessWidget {
  const _CreateHero({required this.settings});

  final AdvertisementSettings? settings;

  @override
  Widget build(BuildContext context) {
    final subtitle = settings == null
        ? 'Маалымат жүктөлүүдө'
        : '${settings!.price.toStringAsFixed(0)} сом · ${settings!.defaultDurationDays} күн · админ текшерет';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Жарнамаңызды чыгарыңыз',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePickerCard extends StatelessWidget {
  const _ImagePickerCard({required this.file, required this.onPick});

  final PlatformFile? file;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final bytes = file?.bytes;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: file == null
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.border,
              width: file == null ? 1.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (bytes != null)
                  Image.memory(bytes, fit: BoxFit.cover)
                else
                  Container(
                    color: const Color(0xFFF9FAFB),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: AppColors.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_photo_alternate_rounded,
                            color: AppColors.primary,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Сүрөт кошуу',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Товар же кызмат көрүнүктүүрөөк болот',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.image_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          file == null ? 'Тандоо' : 'Алмаштыруу',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateSection extends StatelessWidget {
  const _CreateSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _EnhancedField extends StatelessWidget {
  const _EnhancedField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textInputAction: maxLines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: maxLines == 1 ? Icon(icon) : null,
        alignLabelWithHint: maxLines > 1,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        counterStyle: TextStyle(color: Colors.grey[500], fontSize: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _PublishSummary extends StatelessWidget {
  const _PublishSummary({required this.settings});

  final AdvertisementSettings settings;

  @override
  Widget build(BuildContext context) {
    final enough = settings.currentBalance >= settings.price;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: enough ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: enough ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        children: [
          Icon(
            enough
                ? Icons.verified_user_outlined
                : Icons.account_balance_wallet_outlined,
            color: enough ? const Color(0xFF16A34A) : const Color(0xFFD97706),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enough ? 'Жарыялоого даяр' : 'Баланс жетишсиз',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Баасы ${settings.price.toStringAsFixed(0)} сом · Баланс ${settings.currentBalance.toStringAsFixed(0)} сом',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.title,
    required this.description,
    required this.category,
    required this.file,
  });

  final String title;
  final String description;
  final String category;
  final PlatformFile? file;

  @override
  Widget build(BuildContext context) {
    final bytes = file?.bytes;
    final previewTitle = title.isEmpty ? 'Жарнаманын аталышы' : title;
    final previewText = description.isEmpty
        ? 'Бул жерде сиз жазган маалымат алдын ала көрүнөт.'
        : description;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Алдын ала көрүнүш',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              _MetaChip(
                Icons.category_outlined,
                category.isEmpty ? 'Категория' : category,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 86,
                  height: 86,
                  color: const Color(0xFFF3F4F6),
                  child: bytes == null
                      ? const Icon(Icons.campaign_rounded, color: Colors.grey)
                      : Image.memory(bytes, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      previewTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      previewText,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600], height: 1.25),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    final color = switch (normalized) {
      'ACTIVE' => const Color(0xFF16A34A),
      'PENDING' => const Color(0xFFF59E0B),
      'REJECTED' => const Color(0xFFDC2626),
      'STOPPED' => const Color(0xFF6B7280),
      'DELETED' => const Color(0xFF6B7280),
      'EXPIRED' => const Color(0xFF6B7280),
      _ => AppColors.primary,
    };
    final label = switch (normalized) {
      'ACTIVE' => 'Активдүү',
      'PENDING' => 'Күтүүдө',
      'REJECTED' => 'Четке',
      'STOPPED' => 'Токтотулган',
      'DELETED' => 'Өчүрүлгөн',
      'EXPIRED' => 'Бүттү',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(height: 1.35)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB91C1C)),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Кайра жүктөө'),
            ),
          ],
        ),
      ),
    );
  }
}
