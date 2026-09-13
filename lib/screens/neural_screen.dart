import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/neural_service.dart';
import '../theme/app_theme.dart';

class NeuralScreen extends StatefulWidget {
  const NeuralScreen({super.key});

  @override
  State<NeuralScreen> createState() => _NeuralScreenState();
}

class _NeuralScreenState extends State<NeuralScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  File? _image;

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.length < 2 && _image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Опишите, какой зуб болит и как именно.')),
      );
      return;
    }
    final image = _image;
    _text.clear();
    setState(() => _image = null);
    try {
      await context.read<NeuralService>().send(text: text, image: image);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<NeuralService>();
    final bubbles = [
      ...ai.messages,
      if (ai.pendingUser != null) ai.pendingUser!,
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ИИ-стоматолог', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text(
                      'Один чат — одна история. Врач с многолетним стажем помнит предыдущие сообщения.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: ai.sending
                    ? null
                    : () async {
                        await ai.newChat();
                        setState(() => _image = null);
                      },
                child: const Text('Новый чат'),
              ),
            ],
          ),
        ),
        Expanded(
          child: bubbles.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Напишите, где и как болит. Можно прикрепить фото. Следующие вопросы пойдут в этот же разговор.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, height: 1.4),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: bubbles.length + (ai.sending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= bubbles.length) {
                      return const Padding(
                        padding: EdgeInsets.only(left: 8, bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Врач печатает…', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                        ),
                      );
                    }
                    final message = bubbles[index];
                    final mine = message.isUser;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        constraints: const BoxConstraints(maxWidth: 340),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: mine ? AppColors.outgoingBubble : AppColors.incomingBubble,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mine ? 'Вы' : 'Врач (ИИ)',
                              style: const TextStyle(fontSize: 11, color: AppColors.accent),
                            ),
                            const SizedBox(height: 4),
                            Text(message.text, style: const TextStyle(height: 1.35)),
                            if (message.imagePath != null && File(message.imagePath!).existsSync()) ...[
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(File(message.imagePath!), height: 140, fit: BoxFit.cover),
                              ),
                            ],
                            if (message.createdAt != null)
                              Text(
                                DateFormat('HH:mm').format(message.createdAt!.toLocal()),
                                style: const TextStyle(fontSize: 11, color: AppColors.muted),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_image != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_image!, width: 56, height: 56, fit: BoxFit.cover),
                ),
                IconButton(
                  onPressed: () => setState(() => _image = null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: ai.sending
                      ? null
                      : () async {
                          final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
                          if (file == null) return;
                          setState(() => _image = File(file.path));
                        },
                  icon: const Icon(Icons.photo_outlined),
                ),
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 5,
                    enabled: !ai.sending,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => ai.sending ? null : _send(),
                    decoration: const InputDecoration(hintText: 'Сообщение ИИ-врачу'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: ai.sending ? null : _send,
                  style: IconButton.styleFrom(backgroundColor: AppColors.accent),
                  icon: const Icon(Icons.send, color: Color(0xFF06221C)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
