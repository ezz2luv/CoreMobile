import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/auth_controller.dart';
import '../services/cases_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/brand.dart';
import 'case_chat_screen.dart';

class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key});

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  late Future<List<ConsultationCase>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ConsultationCase>> _load() {
    final userId = context.read<AuthController>().user?.id;
    return context.read<CasesRepository>().list(userId: userId);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ConsultationCase>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }
        if (snapshot.hasError) {
          return _ErrorState(message: snapshot.error.toString(), onRetry: _reload);
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 80),
                Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.muted),
                SizedBox(height: 16),
                Text(
                  'Пока нет обращений',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'Создайте консультацию с врачом или отправьте симптомы зубной боли в нейросеть.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          color: AppColors.accent,
          onRefresh: _reload,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final date = item.createdAt == null
                  ? null
                  : DateFormat('dd.MM.yyyy HH:mm').format(item.createdAt!.toLocal());
              return AppCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(item.subject ?? 'Обращение #${item.id}'),
                  subtitle: Text(
                    [
                      if (item.dentistName != null) 'Врач: ${item.dentistName}',
                      if (item.status != null) item.status!,
                      ?date,
                    ].join(' · '),
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => CaseChatScreen(caseId: item.id)),
                    );
                    _reload();
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}
