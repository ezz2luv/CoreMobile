import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/brand.dart';
import 'cases_screen.dart';
import 'create_case_screen.dart';
import 'login_screen.dart';
import 'neural_screen.dart';
import 'profile_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    final pages = [
      const CasesScreen(),
      const CreateCaseScreen(),
      const NeuralScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppHeader(
        trailing: PopupMenuButton<String>(
          tooltip: 'Аккаунт',
          color: AppColors.surface,
          onSelected: (value) async {
            if (value == 'logout') {
              await auth.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'logout', child: Text('Выйти')),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(auth.user?.displayName ?? 'Пациент', style: const TextStyle(fontSize: 12)),
          ),
        ),
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.header,
        indicatorColor: AppColors.accent.withValues(alpha: 0.18),
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: 'Обращения'),
          NavigationDestination(icon: Icon(Icons.add_box_outlined), selectedIcon: Icon(Icons.add_box), label: 'К врачу'),
          NavigationDestination(icon: Icon(Icons.psychology_outlined), selectedIcon: Icon(Icons.psychology), label: 'Нейросеть'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Профиль'),
        ],
      ),
    );
  }
}
