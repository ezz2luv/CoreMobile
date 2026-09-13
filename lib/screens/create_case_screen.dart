import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/auth_controller.dart';
import '../services/cases_repository.dart';
import '../services/neural_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand.dart';
import 'case_chat_screen.dart';

class CreateCaseScreen extends StatefulWidget {
  const CreateCaseScreen({super.key});

  @override
  State<CreateCaseScreen> createState() => _CreateCaseScreenState();
}

class _CreateCaseScreenState extends State<CreateCaseScreen> {
  final _description = TextEditingController();
  CaseFormData? _form;
  Object? _error;
  bool _loading = true;
  bool _saving = false;
  Dentist? _dentist;
  CaseSubject? _subject;
  File? _image;
  bool _alsoNeural = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<CasesRepository>().formData();
      setState(() {
        _form = data;
        _dentist = data.dentists.isEmpty ? null : data.dentists.first;
        _subject = data.subjects.isEmpty ? null : data.subjects.first;
        _alsoNeural = _subject?.looksLikePain ?? false;
      });
    } catch (error) {
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _image = File(file.path));
  }

  Future<void> _submit() async {
    if (_dentist == null || _subject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет справочников для создания обращения.')),
      );
      return;
    }
    if (_description.text.trim().length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Опишите проблему подробнее.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final auth = context.read<AuthController>();
      final cases = context.read<CasesRepository>();
      final neuralService = context.read<NeuralService>();
      final created = await cases.create(
            dentistId: _dentist!.id,
            subjectId: _subject!.id,
            description: _description.text.trim(),
            image: _image,
            userId: auth.user?.id,
          );
      NeuralResult? neural;
      if (_alsoNeural || _subject!.looksLikePain) {
        neural = await neuralService.send(
              text: _description.text.trim(),
              image: _image,
            );
      }
      if (!mounted) return;
      _description.clear();
      setState(() => _image = null);
      if (neural != null) {
        final reply = neural.summary;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('ИИ-стоматолог'),
            content: SingleChildScrollView(child: Text(reply)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Дальше')),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Обращение отправлено врачу.')),
        );
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CaseChatScreen(caseId: created.id)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error.toString(), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Повторить')),
            ],
          ),
        ),
      );
    }
    final form = _form!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Новое обращение', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text(
          'Пациент создаёт консультацию к стоматологу. Если болит зуб — можно параллельно отправить симптомы в нейросеть.',
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Стоматолог', style: TextStyle(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                initialValue: _dentist?.id,
                items: form.dentists
                    .map(
                      (dentist) => DropdownMenuItem(
                        value: dentist.id,
                        child: Text(
                          dentist.specializations.isEmpty
                              ? dentist.name
                              : '${dentist.name} · ${dentist.specializations.join(', ')}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _dentist = form.dentists.where((item) => item.id == value).firstOrNull;
                  });
                },
              ),
              const SizedBox(height: 14),
              const Text('Тема', style: TextStyle(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                initialValue: _subject?.id,
                items: form.subjects
                    .map((subject) => DropdownMenuItem(value: subject.id, child: Text(subject.name)))
                    .toList(),
                onChanged: (value) {
                  final selected = form.subjects.where((item) => item.id == value).firstOrNull;
                  setState(() {
                    _subject = selected;
                    if (selected?.looksLikePain == true) _alsoNeural = true;
                  });
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _description,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Описание',
                  hintText: 'Что беспокоит, как давно, есть ли отёк или температура',
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_outlined),
                    label: Text(_image == null ? 'Фото' : 'Фото выбрано'),
                  ),
                  if (_image != null) ...[
                    const SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_image!, width: 48, height: 48, fit: BoxFit.cover),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.accent,
                title: const Text('Отдельно отправить в нейросеть'),
                subtitle: const Text(
                  'Отдельный чат с ИИ-стоматологом. История этого разговора сохранится на вкладке «Нейросеть».',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                value: _alsoNeural,
                onChanged: (value) => setState(() => _alsoNeural = value),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: Text(_saving ? 'Отправляем…' : 'Создать обращение'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
