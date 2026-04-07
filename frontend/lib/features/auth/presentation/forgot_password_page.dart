// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/auth_api.dart';
import '../../../core/theme/app_colors.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _api = AuthApi();

  // Step 0 = phone input, Step 1 = code + new password
  int _step = 0;

  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscurePass = true;

  bool _loading = false;
  String? _error;
  String? _phone; // saved after step 0

  // 60-second resend countdown
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds <= 0) {
        t.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  String get _fullPhone {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    return '+996$digits';
  }

  Future<void> _sendCode() async {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) {
      setState(() => _error = 'Телефон номерин толук жазыңыз');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await _api.forgotPassword(phone: _fullPhone);
      _phone = _fullPhone;
      _startResendTimer();
      setState(() { _step = 1; _loading = false; });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _resendCode() async {
    if (_resendSeconds > 0) return;
    setState(() { _loading = true; _error = null; });
    try {
      await _api.forgotPassword(phone: _phone!);
      _startResendTimer();
      setState(() { _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Код кайра жөнөтүлдү')),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    final code = _codeController.text.trim();
    final pass = _passController.text;
    if (code.length < 4) {
      setState(() => _error = 'Кодду толук жазыңыз');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Сырсөз 6+ символ болушу керек');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await _api.resetPassword(phone: _phone!, code: code, newPassword: pass);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сырсөз ийгиликтүү жаңыланды'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Сырсөздү калыбына келтирүү',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 420 : double.infinity),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Step indicator
                _buildStepRow(),
                const SizedBox(height: 28),

                if (_step == 0) _buildStep0(),
                if (_step == 1) _buildStep1(),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFCC1010), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFFCC1010), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow() {
    return Row(
      children: List.generate(2, (i) {
        final active = _step == i;
        final done = _step > i;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 1 ? 6 : 0),
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: done || active ? AppColors.primary : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Step 0: Phone number ─────────────────────────────────────────────────
  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: const Column(
            children: [
              Icon(Icons.phone_android_rounded, size: 40, color: AppColors.primary),
              SizedBox(height: 12),
              Text(
                'Телефон номериңизди жазыңыз',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Каттоодо колдонгон номерди жазыңыз. Код жөнөтүлөт.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\-\(\) ]'))],
          onChanged: (_) => setState(() => _error = null),
          decoration: InputDecoration(
            labelText: 'Телефон номери',
            hintText: '700 55 22 11',
            prefixText: '+996 ',
            prefixStyle: const TextStyle(
              fontSize: 15,
              color: Color(0xFF374151),
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const Icon(Icons.phone_android_rounded, color: AppColors.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _sendCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE5A0A0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text(
                    'Код жөнөтүү',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }

  // ── Step 1: Code + new password ──────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Column(
            children: [
              Icon(Icons.mark_email_read_outlined, size: 40, color: Colors.amber.shade700),
              const SizedBox(height: 12),
              const Text(
                'Код жөнөтүлдү',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Телефон номериңизге байланышкан каналдан кодду алыңыз.',
                style: TextStyle(fontSize: 13, color: Colors.amber.shade800),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Code field
        TextFormField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 8,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() => _error = null),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 10,
            color: AppColors.primary,
          ),
          decoration: InputDecoration(
            labelText: 'Код',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // New password field
        TextFormField(
          controller: _passController,
          obscureText: _obscurePass,
          onChanged: (_) => setState(() => _error = null),
          decoration: InputDecoration(
            labelText: 'Жаңы сырсөз',
            hintText: '6+ символ',
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: const Color(0xFF9CA3AF),
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Submit button
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _resetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE5A0A0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text(
                    'Сырсөздү жаңылоо',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        const SizedBox(height: 12),

        // Resend + back
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => setState(() {
                _step = 0;
                _error = null;
                _codeController.clear();
                _resendTimer?.cancel();
              }),
              child: const Text('← Артка'),
            ),
            TextButton(
              onPressed: (_resendSeconds > 0 || _loading) ? null : _resendCode,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                disabledForegroundColor: Colors.grey,
              ),
              child: Text(
                _resendSeconds > 0
                    ? 'Кайра жөнөтүү ($_resendSeconds с)'
                    : 'Кодду кайра жөнөтүү',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
