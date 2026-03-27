import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import 'cubit/auth_cubit.dart';
import 'cubit/auth_state.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, this.onAuthSuccess});

  final ValueChanged<String>? onAuthSuccess;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  AuthCubit get _authCubit => context.read<AuthCubit>();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await _authCubit.submit(
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
    );
  }

  Future<void> _forgotPassword() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Телефон номерин киргизиңиз (10+)')),
      );
      return;
    }

    try {
      final message = await _authCubit.forgotPassword(phone);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  void _toggleMode(bool isLogin) {
    _authCubit.toggleMode(isLogin);
  }

  Widget _buildHeader(bool isLogin) {
    if (isLogin) {
      return Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.of(context).maybePop();
            },
            icon: const Icon(Icons.arrow_back),
          ),
          const Expanded(
            child: Text(
              'BATKEN EXPRESS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      );
    }

    return const Column(
      children: [
        Text(
          'BATKEN EXPRESS',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 42,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (previous, current) =>
          previous.token != current.token && current.token != null,
      listener: (context, state) {
        final token = state.token;
        if (token != null && token.isNotEmpty) {
          widget.onAuthSuccess?.call(token);
        }
      },
      builder: (context, state) => Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 26,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(state.isLogin),
                      const SizedBox(height: 18),
                      Text(
                        state.isLogin ? 'Кирүү' : 'Каттоо',
                        textAlign: state.isLogin
                            ? TextAlign.left
                            : TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 42,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.isLogin
                            ? 'Улантуу үчүн кириңиз'
                            : 'Жаңы аккаунт түзүңүз',
                        textAlign: state.isLogin
                            ? TextAlign.left
                            : TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (!state.isLogin) ...[
                        const Text(
                          'Аты-жөнү',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AppTextField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          hintText: 'Толук атыңызды жазыңыз',
                          prefixIcon: const Icon(Icons.person),
                          validator: (value) {
                            if (!state.isLogin &&
                                (value == null || value.trim().length < 2)) {
                              return 'Аты-жөнү 2+ символ болушу керек';
                            }
                            return null;
                          },
                      ),
                      ],
                      const Text(
                        'Телефон номери',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppTextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        hintText: '+996 (___) __-__-__',
                        prefixIcon: const Icon(Icons.phone_android),
                        validator: (value) {
                          if (value == null || value.trim().length < 10) {
                            return 'Телефон 10+ символ болушу керек';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Сыр сөз',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppTextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        hintText: state.isLogin ? 'Сыр сөз' : 'Пароль түзүңүз',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Сыр сөз 6+ символ болушу керек';
                          }
                          return null;
                        },
                      ),
                      if (state.isLogin) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: state.isLoading ? null : _forgotPassword,
                            child: const Text('Сыр сөздү унуттуңузбу?'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      AppButton.primary(
                        onPressed: state.isLoading ? null : _submit,
                        isLoading: state.isLoading,
                        label: state.isLogin ? 'Кирүү' : 'Катталуу',
                      ),
                      if (state.error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          state.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ],
                      if (state.success != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF9EE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            state.success!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.success),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            state.isLogin
                                ? 'Аккаунтуңуз жокпу? '
                                : 'Аккаунтуңуз барбы? ',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          TextButton(
                            onPressed: state.isLoading
                                ? null
                                : () {
                                    _toggleMode(!state.isLogin);
                                  },
                            child: Text(state.isLogin ? 'Катталуу' : 'Кирүү'),
                          ),
                        ],
                      ),
                      if (state.isLogin) ...[
                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'ЖЕ БОЛБОСО',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: AppButton.secondary(
                                onPressed: null,
                                label: 'Google',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppButton.secondary(
                                onPressed: null,
                                label: 'Apple',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Кирүү менен сиз биздин Тейлөө шарттарыбызга жана Купуялык саясатыбызга макул болосуз',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ), ),
    );
  }
}
