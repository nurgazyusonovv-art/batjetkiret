import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'forgot_password_page.dart';
import 'cubit/auth_cubit.dart';
import 'cubit/auth_state.dart';

class _KyrgyzPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldDigits = digitsOnly(oldValue.text);
    final newRaw = digitsOnly(newValue.text);

    String digits;
    if (newValue.text.length < oldValue.text.length &&
        newRaw.length == oldDigits.length) {
      digits = oldDigits.isEmpty
          ? ''
          : oldDigits.substring(0, oldDigits.length - 1);
    } else {
      String clean = newRaw;
      if (clean.startsWith('996') && clean.length > 9) {
        clean = clean.substring(3);
      } else if (clean.startsWith('0') && clean.length > 9) {
        clean = clean.substring(1);
      }
      digits = clean.length > 9 ? clean.substring(0, 9) : clean;
    }

    final formatted = _applyMask(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String _applyMask(String digits) {
    if (digits.isEmpty) return '';
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 0) buf.write('(');
      buf.write(digits[i]);
      if (i == 2) {
        buf.write(')');
        if (digits.length > 3) buf.write('-');
      } else if (i == 4 && digits.length > 5) {
        buf.write('-');
      } else if (i == 6 && digits.length > 7) {
        buf.write('-');
      }
    }
    return buf.toString();
  }

  static String digitsOnly(String masked) =>
      masked.replaceAll(RegExp(r'\D'), '');
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, this.onAuthSuccess, this.onContinueAsGuest});
  final ValueChanged<String>? onAuthSuccess;
  final VoidCallback? onContinueAsGuest;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    _animController.dispose();
    super.dispose();
  }

  String get _fullPhone {
    String digits = _KyrgyzPhoneFormatter.digitsOnly(_phoneController.text);
    if (digits.startsWith('996') && digits.length > 9) {
      digits = digits.substring(3);
    } else if (digits.startsWith('0') && digits.length > 9) {
      digits = digits.substring(1);
    }
    if (digits.length > 9) {
      digits = digits.substring(digits.length - 9);
    }
    return '+996$digits';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AuthCubit>().submit(
      phone: _fullPhone,
      password: _passwordController.text,
      name: _nameController.text.trim(),
      referralCode: _referralController.text,
    );
  }

  void _switchMode(bool isLogin) {
    _animController.reset();
    context.read<AuthCubit>().toggleMode(isLogin);
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (prev, cur) => prev.token != cur.token && cur.token != null,
      listener: (context, state) {
        if (state.token != null && state.token!.isNotEmpty) {
          final onAuthSuccess = widget.onAuthSuccess;
          if (onAuthSuccess != null) {
            onAuthSuccess(state.token!);
          } else if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(state.token!);
          }
        }
      },
      builder: (context, state) {
        final isWide = MediaQuery.of(context).size.width >= 800;
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: isWide ? _buildWideLayout(state) : _buildNarrowLayout(state),
        );
      },
    );
  }

  // ── Wide layout (desktop/tablet): split screen ───────────────────────────
  Widget _buildWideLayout(AuthState state) {
    return Row(
      children: [
        // Left panel — branding
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFCC1010), Color(0xFF8B0000)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 160,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'БАТКЕН ЭКСПРЕСС',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Тез жеткирүү кызматы',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Right panel — form
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 40,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: _buildForm(state),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Narrow layout (mobile): stacked ─────────────────────────────────────
  Widget _buildNarrowLayout(AuthState state) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFCC1010), Color(0xFF8B0000)],
          stops: [0.0, 0.38],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top branding
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'БАТКЕН ЭКСПРЕСС',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Тез жеткирүү кызматы',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Bottom form card
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: _buildForm(state),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared form ───────────────────────────────────────────────────────────
  Widget _buildForm(AuthState state) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Text(
              state.isLogin ? 'Кош келиңиз!' : 'Каттоо',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              state.isLogin ? 'Аккаунтуңузга кириңиз' : 'Жаңы аккаунт түзүңүз',
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 28),

            // Name field (register only)
            if (!state.isLogin) ...[
              _buildLabel('Аты-жөнү'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _nameController,
                hint: 'Толук атыңызды жазыңыз',
                icon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().length < 2) {
                    return 'Аты-жөнү 2+ символ болушу керек';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],

            // Phone field
            _buildLabel('Телефон номери'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _phoneController,
              hint: '(700)-55-22-11',
              icon: Icons.phone_android_rounded,
              prefixText: '+996 ',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [_KyrgyzPhoneFormatter()],
              validator: (v) {
                final d = _KyrgyzPhoneFormatter.digitsOnly(v ?? '');
                if (d.length < 9) return 'Телефон номерин толук жазыңыз';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password field
            _buildLabel('Сыр сөз'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _passwordController,
              hint: state.isLogin
                  ? 'Сыр сөзүңүздү жазыңыз'
                  : 'Жаңы сыр сөз түзүңүз',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmit: (_) => _submit(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF9CA3AF),
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) {
                if (v == null || v.length < 6) {
                  return 'Сыр сөз 6+ символ болушу керек';
                }
                return null;
              },
            ),

            // Invite code (register only) — a friend's code credits them a
            // bonus. Optional: a wrong or empty code never blocks signup.
            if (!state.isLogin) ...[
              const SizedBox(height: 16),
              _buildLabel('Досуңуздун коду (милдеттүү эмес)'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _referralController,
                hint: 'Мисалы: BJ000123',
                icon: Icons.card_giftcard_rounded,
                textInputAction: TextInputAction.done,
                onSubmit: (_) => _submit(),
              ),
              const SizedBox(height: 6),
              Text(
                'Досуңуз сизди чакырган болсо, анын кодун жазыңыз — '
                'ага бонус түшөт.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Colors.grey[600],
                ),
              ),
            ],

            // Forgot password
            if (state.isLogin) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: state.isLoading
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordPage(),
                          ),
                        ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFCC1010),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Сыр сөздү унуттуңузбу?',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: state.isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC1010),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE5A0A0),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: state.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        state.isLogin ? 'Кирүү' : 'Катталуу',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),

            // Error message
            if (state.error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFCC1010),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: const TextStyle(
                          color: Color(0xFFCC1010),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Success message
            if (state.success != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  state.success!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontSize: 13,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Switch mode
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  state.isLogin ? 'Аккаунтуңуз жокпу?' : 'Аккаунтуңуз барбы?',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                  ),
                ),
                TextButton(
                  onPressed: state.isLoading
                      ? null
                      : () => _switchMode(!state.isLogin),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFCC1010),
                    padding: const EdgeInsets.only(left: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    state.isLogin ? 'Катталуу' : 'Кирүү',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: Color(0xFFE5E7EB)),
            const SizedBox(height: 12),

            // Continue as Guest button
            OutlinedButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () {
                      if (widget.onContinueAsGuest != null) {
                        widget.onContinueAsGuest!();
                      } else {
                        Navigator.pop(context);
                      }
                    },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(
                Icons.explore_outlined,
                size: 20,
                color: Color(0xFF4B5563),
              ),
              label: const Text(
                'Конок катары көрүү (Кирбестен)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF374151),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    String? prefixText,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onSubmit,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      validator: validator,
      onFieldSubmitted: onSubmit,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefixText,
        prefixStyle: const TextStyle(
          fontSize: 15,
          color: Color(0xFF374151),
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 15),
        prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCC1010), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCC1010)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCC1010), width: 2),
        ),
        errorStyle: const TextStyle(fontSize: 12),
      ),
    );
  }
}
