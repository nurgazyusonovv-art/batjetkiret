// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/core/config.dart';
import 'package:frontend/core/theme/app_colors.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key, required this.token});

  final String token;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();

  bool _oldVisible = false;
  bool _newVisible = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _oldPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/auth/change-password').replace(
        queryParameters: {
          'old_password': _oldPasswordCtrl.text.trim(),
          'new_password': _newPasswordCtrl.text.trim(),
        },
      );

      final response = await http.post(
        uri,
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сырсөз ийгиликтүү өзгөртүлдү'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        final body = jsonDecode(response.body);
        setState(() {
          _error = (body['detail'] ?? 'Ката чыкты').toString();
        });
      }
    } catch (e) {
      setState(() { _error = 'Серверге туташуу мүмкүн болгон жок'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
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
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Сырсөздү өзгөртүү',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                const Text(
                  'Учурдагы сырсөз',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _oldPasswordCtrl,
                  obscureText: !_oldVisible,
                  decoration: InputDecoration(
                    hintText: 'Учурдагы сырсөздү жазыңыз',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    suffixIcon: IconButton(
                      icon: Icon(_oldVisible ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textSecondary, size: 20),
                      onPressed: () => setState(() => _oldVisible = !_oldVisible),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Талаа бош болбосун' : null,
                ),

                const SizedBox(height: 16),

                const Text(
                  'Жаңы сырсөз',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _newPasswordCtrl,
                  obscureText: !_newVisible,
                  decoration: InputDecoration(
                    hintText: 'Жаңы сырсөздү жазыңыз',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    suffixIcon: IconButton(
                      icon: Icon(_newVisible ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textSecondary, size: 20),
                      onPressed: () => setState(() => _newVisible = !_newVisible),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Талаа бош болбосун';
                    if (v.length < 6) return 'Кеминде 6 белги болушу керек';
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Сырсөздү өзгөртүү',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
