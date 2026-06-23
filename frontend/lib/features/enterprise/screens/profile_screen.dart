import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/map_picker.dart';
import 'order_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _me;
  Map<String, dynamic>? _report;
  int _reportDays = 7;
  bool _loading = true;
  bool _togglingOpen = false;
  bool _uploadingLogo = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getMe(),
        ApiService.getReports(days: _reportDays),
      ]);
      if (mounted) {
        setState(() {
          _me = results[0];
          _report = results[1];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadReport() async {
    try {
      final r = await ApiService.getReports(days: _reportDays);
      if (mounted) setState(() => _report = r);
    } catch (_) {}
  }

  /// [target] = true → force open, false → force closed, null → auto (working hours).
  Future<void> _setOpenStatus(bool? target) async {
    setState(() => _togglingOpen = true);
    try {
      await ApiService.setOpenStatus(target);
      await _load();
    } catch (_) {
      if (mounted) setState(() => _togglingOpen = false);
    }
  }

  /// 3-state selector: Авто (null) / Ачык (true) / Жабык (false).
  Widget _openStatusSelector(bool? current) {
    Widget seg(String label, bool? value, Color activeColor) {
      final selected = current == value;
      return Expanded(
        child: GestureDetector(
          onTap: _togglingOpen || selected ? null : () => _setOpenStatus(value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? activeColor : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          seg('🟢 Ачык', true, const Color(0xFF16A34A)),
          seg('🔴 Жабык', false, const Color(0xFFDC2626)),
          seg('⏰ Авто', null, const Color(0xFF2563EB)),
        ],
      ),
    );
  }

  Future<void> _uploadLogo() async {
    final enterpriseId = (_me?['id'] as num?)?.toInt();
    if (enterpriseId == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;

    setState(() => _uploadingLogo = true);
    try {
      final logoData = await ApiService.uploadEnterpriseLogo(
        enterpriseId,
        picked,
      );
      if (!mounted) return;
      setState(() {
        _me = {...?_me, 'logo_data': logoData};
        _uploadingLogo = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Логотип жаңыланды'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadingLogo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Логотип жүктөөдө ката кетти'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сырсөздү өзгөртүү'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Учурдагы сырсөз',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Жаңы сырсөз',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Жаңы сырсөздү тастыктоо',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Жок'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
            ),
            child: const Text('Сактоо', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (newCtrl.text != confirmCtrl.text) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сырсөздөр дал келбейт'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
      return;
    }
    try {
      await ApiService.changePassword(
        currentCtrl.text.trim(),
        newCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Сырсөз ийгиликтүү өзгөртүлдү'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('туура эмес')
            ? 'Учурдагы сырсөз туура эмес'
            : 'Ката кетти';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _updateLocation() async {
    final currentLat = (_me?['lat'] as num?)?.toDouble();
    final currentLon = (_me?['lon'] as num?)?.toDouble();

    final result = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerPage(
          needAddress: false,
          initialLat: currentLat,
          initialLon: currentLon,
        ),
      ),
    );
    if (result == null) return;

    try {
      await ApiService.updateLocation(result.lat, result.lon);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Жайгашкан жер жаңыланды'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ката кетти'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _uploadPaymentQr() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    try {
      await ApiService.uploadPaymentQr(picked);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Төлөм QR коду жүктөлдү'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ката кетти'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _deletePaymentQr() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR кодду өчүрүү'),
        content: const Text('Төлөм QR кодун өчүрүүнү каалайсызбы?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Жок'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Өчүрүү', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deletePaymentQr();
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR код өчүрүлдү'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Чыгуу'),
        content: const Text('Системадан чыгууну каалайсызбы?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Жок'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Чыгуу', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await AuthService.deleteToken();
      widget.onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _me;
    final isOpen = e?['is_open_override'] as bool?;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        toolbarHeight: 48,
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        title: const Text(
          'Профиль',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  // Enterprise card
                  if (e != null) _enterpriseCard(e, isOpen),
                  const SizedBox(height: 14),

                  // Report period selector
                  _reportSection(),
                  const SizedBox(height: 14),

                  // Payment QR section
                  _qrSection(e),
                  const SizedBox(height: 14),

                  // History link
                  _menuTile(
                    icon: Icons.history,
                    label: 'Заказдар тарыхы',
                    color: const Color(0xFF2563EB),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const _HistoryScreen()),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Location update
                  _menuTile(
                    icon: Icons.location_on_outlined,
                    label: 'Жайгашкан жерди өзгөртүү',
                    color: const Color(0xFF0891B2),
                    onTap: _updateLocation,
                  ),
                  const SizedBox(height: 8),

                  // Change password
                  _menuTile(
                    icon: Icons.lock_outline,
                    label: 'Сырсөздү өзгөртүү',
                    color: const Color(0xFF7C3AED),
                    onTap: _changePassword,
                  ),
                  const SizedBox(height: 8),

                  // Logout
                  _menuTile(
                    icon: Icons.logout,
                    label: 'Системадан чыгуу',
                    color: const Color(0xFFDC2626),
                    onTap: _logout,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _enterpriseCard(Map<String, dynamic> e, bool? isOpen) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _logoBox(e['logo_data'] as String?),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e['name'] as String? ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      e['category'] as String? ?? '',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                    if (e['address'] != null)
                      Text(
                        e['address'] as String,
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _uploadingLogo ? null : _uploadLogo,
              icon: _uploadingLogo
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_camera_outlined, size: 18),
              label: Text(
                _uploadingLogo
                    ? 'Жүктөлүүдө...'
                    : (e['logo_data'] == null
                          ? 'Логотип жүктөө'
                          : 'Логотипти алмаштыруу'),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF16A34A),
                side: const BorderSide(color: Color(0xFF16A34A)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const Divider(height: 20),
          Row(
            children: [
              const Text(
                'Ишкана статусу:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (_togglingOpen)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _openStatusSelector(isOpen),
          if (isOpen == null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Авто режимде жумуш сааты боюнча автоматтык ачылып-жабылат',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ),
          if (e['open_time'] != null || e['close_time'] != null) ...[
            const SizedBox(height: 6),
            Text(
              'Иш убактысы: ${e['open_time'] ?? '?'} – ${e['close_time'] ?? '?'}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _logoBox(String? logoData) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 64,
            height: 64,
            color: const Color(0xFF16A34A).withValues(alpha: 0.1),
            child: logoData != null && logoData.isNotEmpty
                ? _buildInlineImage(logoData)
                : const Icon(
                    Icons.storefront,
                    color: Color(0xFF16A34A),
                    size: 30,
                  ),
          ),
        ),
        Positioned(
          right: 3,
          bottom: 3,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.edit, color: Colors.white, size: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineImage(String data) {
    if (data.startsWith('data:')) {
      final commaIdx = data.indexOf(',');
      if (commaIdx == -1) return const SizedBox.shrink();
      try {
        final bytes = base64Decode(data.substring(commaIdx + 1));
        return Image.memory(bytes, width: 64, height: 64, fit: BoxFit.cover);
      } catch (_) {
        return const Icon(Icons.storefront, color: Color(0xFF16A34A), size: 30);
      }
    }
    return Image.network(
      AppConfig.mediaUrl(data) ?? data,
      width: 64,
      height: 64,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.storefront, color: Color(0xFF16A34A), size: 30),
    );
  }

  Widget _qrSection(Map<String, dynamic>? e) {
    final qrUrl = e?['payment_qr_url'] as String?;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '💳 Төлөм QR коду',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const Spacer(),
              if (qrUrl != null)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                  onPressed: _deletePaymentQr,
                  tooltip: 'QR кодду өчүрүү',
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (qrUrl != null && qrUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _buildQrImage(qrUrl),
            ),
            const SizedBox(height: 8),
          ] else ...[
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'QR код жок',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _uploadPaymentQr,
              icon: const Icon(Icons.upload_outlined, size: 18),
              label: Text(
                qrUrl != null ? 'QR кодду алмаштыруу' : 'QR код жүктөө',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF16A34A),
                side: const BorderSide(color: Color(0xFF16A34A)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrImage(String url) {
    if (url.startsWith('data:')) {
      final commaIdx = url.indexOf(',');
      if (commaIdx == -1) return const SizedBox.shrink();
      try {
        final bytes = base64Decode(url.substring(commaIdx + 1));
        return Image.memory(
          bytes,
          width: double.infinity,
          height: 180,
          fit: BoxFit.contain,
        );
      } catch (_) {
        return const SizedBox.shrink();
      }
    }
    return Image.network(
      AppConfig.mediaUrl(url) ?? url,
      width: double.infinity,
      height: 180,
      fit: BoxFit.contain,
    );
  }

  Widget _reportSection() {
    final r = _report;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '📊 Отчёт',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const Spacer(),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 1,
                    label: Text('1к', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: 7,
                    label: Text('7к', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: 30,
                    label: Text('30к', style: TextStyle(fontSize: 11)),
                  ),
                ],
                selected: {_reportDays},
                onSelectionChanged: (s) {
                  setState(() => _reportDays = s.first);
                  _loadReport();
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? const Color(0xFF16A34A)
                        : null,
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? Colors.white
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (r != null) ...[
            _reportRow(
              'Жалпы заказ',
              '${r['total_orders'] ?? 0}',
              const Color(0xFF2563EB),
            ),
            _reportRow(
              'Аяктаган',
              '${r['completed_orders'] ?? 0}',
              const Color(0xFF16A34A),
            ),
            _reportRow(
              'Жокко чыгарылган',
              '${r['cancelled_orders'] ?? 0}',
              const Color(0xFFDC2626),
            ),
            _reportRow(
              'Жалпы киреше',
              '${(r['total_revenue'] as num?)?.toStringAsFixed(0) ?? 0} сом',
              const Color(0xFF7C3AED),
            ),
            const Divider(height: 16),
            _reportRow(
              'Онлайн заказ',
              '${r['online_orders'] ?? 0}',
              const Color(0xFF0891B2),
            ),
            _reportRow(
              'Жергиликтүү',
              '${r['local_orders'] ?? 0}',
              const Color(0xFFF59E0B),
            ),
            _reportRow(
              'Стол',
              '${r['dine_in_orders'] ?? 0}',
              const Color(0xFF7C3AED),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _reportRow(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: color,
          ),
        ),
      ],
    ),
  );

  static Widget _menuTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
        ],
      ),
    ),
  );
}

// ─── History Screen ───────────────────────────────────────────────────────────

class _HistoryScreen extends StatefulWidget {
  const _HistoryScreen();
  @override
  State<_HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<_HistoryScreen> {
  List<dynamic> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getHistory();
      if (mounted) {
        setState(() {
          _history = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteOne(int orderId) async {
    try {
      await ApiService.deleteHistoryOrder(orderId);
      setState(() => _history.removeWhere((o) => o['id'] == orderId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ката кетти'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Тарыхты тазалоо'),
        content: const Text('Бардык тарыхты тазалайсызбы?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Жок'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Тазалоо', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.clearHistory();
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Тарых тазаланды'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        toolbarHeight: 48,
        title: const Text(
          'Заказдар тарыхы',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, size: 20),
              tooltip: 'Баарын тазалоо',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _history.isEmpty
                  ? const Center(
                      child: Text(
                        'Тарых жок',
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: _history.length,
                      itemBuilder: (_, i) {
                        final o = _history[i] as Map<String, dynamic>;
                        final status = o['status'] as String? ?? '';
                        final id = o['id'] as int;
                        final to = o['to_address'] ?? '';
                        final total =
                            (o['items_total'] as num?)?.toStringAsFixed(0) ??
                            (o['price'] as num?)?.toStringAsFixed(0) ??
                            '0';
                        final createdAt = o['created_at'] as String? ?? '';
                        final isCompleted =
                            status == 'COMPLETED' || status == 'DELIVERED';

                        return Dismissible(
                          key: ValueKey(id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          confirmDismiss: (_) async {
                            await _deleteOne(id);
                            return false;
                          },
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () async {
                                final changed = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrderDetailScreen(order: o),
                                  ),
                                );
                                if (changed == true && mounted) {
                                  _load();
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color:
                                            (isCompleted
                                                    ? const Color(0xFF16A34A)
                                                    : const Color(0xFFDC2626))
                                                .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isCompleted
                                            ? Icons.check_circle_outline
                                            : Icons.cancel_outlined,
                                        color: isCompleted
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFFDC2626),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Заказ #$id',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            to.toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF6B7280),
                                            ),
                                          ),
                                          if (createdAt.length >= 16)
                                            Text(
                                              createdAt
                                                  .replaceAll('T', ' ')
                                                  .substring(0, 16),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF9CA3AF),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '$total сом',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.touch_app_outlined,
                                              size: 14,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                            SizedBox(width: 6),
                                            Icon(
                                              Icons.swipe_left_outlined,
                                              size: 14,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
