// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:frontend/core/config.dart';
import 'package:frontend/core/theme/app_colors.dart';

class OrderPaymentSheet extends StatefulWidget {
  const OrderPaymentSheet({
    super.key,
    required this.token,
    required this.orderId,
    required this.enterpriseId,
    required this.amount,
  });

  final String token;
  final int orderId;
  final int enterpriseId;
  final double amount;

  @override
  State<OrderPaymentSheet> createState() => _OrderPaymentSheetState();
}

class _OrderPaymentSheetState extends State<OrderPaymentSheet> {
  String? _paymentQrUrl;
  File? _screenshot;
  bool _loadingQr = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQr();
  }

  Future<void> _loadQr() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/enterprises/${widget.enterpriseId}/payment-qr'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _paymentQrUrl = body['payment_qr_url'] as String?;
          _loadingQr = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingQr = false);
  }

  Future<void> _pickScreenshot(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (picked != null) {
      setState(() {
        _screenshot = File(picked.path);
        _error = null;
      });
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Галерея'),
              onTap: () {
                Navigator.pop(context);
                _pickScreenshot(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Камера'),
              onTap: () {
                Navigator.pop(context);
                _pickScreenshot(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadScreenshot(File file) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/topup/upload-screenshot');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${widget.token}'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode == 200) {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return decoded['url'] as String?;
    }
    final detail = (jsonDecode(body) as Map<String, dynamic>)['detail'];
    throw Exception(detail ?? 'Скриншот жүктөлгөн жок');
  }

  Future<void> _submit() async {
    if (_screenshot == null) {
      setState(() => _error = 'Төлөмдүн скриншотун тандаңыз');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final screenshotUrl = await _uploadScreenshot(_screenshot!);
      if (screenshotUrl == null) throw Exception('URL алынган жок');

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/enterprise-portal/payments'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'order_id': widget.orderId,
          'amount': widget.amount,
          'screenshot_url': screenshotUrl,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Төлөм ийгиликтүү жөнөтүлдү. Ишкана тастыктайт.'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }
      final decoded = jsonDecode(response.body);
      final detail = decoded is Map ? decoded['detail'] : null;
      throw Exception(detail ?? 'Ката болду');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Заказ түзүлдү — Төлөм жүргүзүңүз',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Сумма: ${widget.amount.toStringAsFixed(0)} сом',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_loadingQr)
              const Center(child: CircularProgressIndicator())
            else if (_paymentQrUrl != null)
              _buildQrImage(_paymentQrUrl!)
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'QR код жүктөлгөн жок. Ишкана менен байланышыңыз.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              'Төлөмдүн скриншотун жүктөңүз',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            _buildScreenshotPicker(),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Тастыктоо',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text(
                'Кийинчерек жөнөтөмүн',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrImage(String dataUrl) {
    try {
      final comma = dataUrl.indexOf(',');
      final bytes = base64Decode(comma >= 0 ? dataUrl.substring(comma + 1) : dataUrl);
      return Center(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE0E0E0)),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(8),
          child: Image.memory(bytes, width: 200, height: 200, fit: BoxFit.contain),
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildScreenshotPicker() {
    if (_screenshot != null) {
      return GestureDetector(
        onTap: _showImageSourceSheet,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            _screenshot!,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: _showImageSourceSheet,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_outlined, size: 32, color: Colors.grey),
            SizedBox(height: 6),
            Text(
              'Скриншот тандаңыз',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
