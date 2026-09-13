import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';
import 'services/api_client.dart';
import 'services/auth_controller.dart';
import 'services/cases_repository.dart';
import 'services/neural_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CoreApp());
}

class CoreApp extends StatelessWidget {
  const CoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiClient();
    return MultiProvider(
      providers: [
        Provider.value(value: api),
        Provider(create: (_) => CasesRepository(api)),
        ChangeNotifierProvider(create: (_) => NeuralService()..restore()),
        ChangeNotifierProvider(create: (_) => AuthController(api)..restore()),
      ],
      child: MaterialApp(
        title: 'Core — консультация с врачом',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const _Gate(),
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (!auth.ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    return auth.isLoggedIn ? const ShellScreen() : const LoginScreen();
  }
}
