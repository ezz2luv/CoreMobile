import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/brand.dart';
import 'register_screen.dart';
import 'shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().login(
            email: _email.text,
            password: _password.text,
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ShellScreen()),
      );
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final banner = context.watch<AuthController>().banner;
    final wide = MediaQuery.sizeOf(context).width >= 820;

    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Вход', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Один экран для пациента. Врач работает в десктоп-приложении.',
            style: TextStyle(color: AppColors.muted, height: 1.35),
          ),
          const SizedBox(height: 22),
          const Text('Email', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(hintText: 'you@email.com'),
            validator: (value) {
              if (value == null || !value.contains('@')) return 'Введите email';
              return null;
            },
          ),
          const SizedBox(height: 14),
          const Text('Пароль', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'минимум 8 символов'),
            validator: (value) {
              if (value == null || value.length < 8) return 'Минимум 8 символов';
              return null;
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? 'Входим…' : 'Войти'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              );
            },
            child: const Text('Зарегистрироваться', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: const AppHeader(),
      body: Column(
        children: [
          if (banner != null) StatusBanner(text: banner),
          if (_error != null) StatusBanner(text: _error!, tone: BannerTone.error),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: wide
                    ? Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF141B22),
                                borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
                              ),
                              child: const Center(child: CoreLogo()),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
                              child: form,
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                        children: [
                          const CoreLogo(size: 132),
                          const SizedBox(height: 28),
                          form,
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
