import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:core/screens/login_screen.dart';
import 'package:core/services/api_client.dart';
import 'package:core/services/auth_controller.dart';
import 'package:core/theme/app_theme.dart';

void main() {
  testWidgets('Login screen shows Core branding', (tester) async {
    final api = ApiClient();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) {
          final auth = AuthController(api);
          auth.ready = true;
          return auth;
        },
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const LoginScreen(),
        ),
      ),
    );

    expect(find.text('Вход'), findsOneWidget);
    expect(find.text('CORE'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
  });
}
