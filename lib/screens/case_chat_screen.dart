import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/auth_controller.dart';
import '../services/cases_hub.dart';
import '../services/cases_repository.dart';
import '../theme/app_theme.dart';

class CaseChatScreen extends StatefulWidget {
  const CaseChatScreen({super.key, required this.caseId});

  final int caseId;

  @override
  State<CaseChatScreen> createState() => _CaseChatScreenState();
}

class _CaseChatScreenState extends State<CaseChatScreen> {
  final _text = TextEditingController();
  final _hub = CasesHub();
  ConsultationCase? _case;
  String? _error;
  bool _loading = true;
  bool _sending = false;
  File? _image;

  @override
  void initState() {
    super.initState();
    _load(connectHub: true);
  }

  @override
  void dispose() {
    _text.dispose();
    _hub.disconnect();
    super.dispose();
  }

  Future<void> _load({bool connectHub = false}) async {
    setState(() {
      _loading = _case == null;
      _error = null;
    });
    try {
      final auth = context.read<AuthController>();
      final details = await context.read<CasesRepository>().details(
            widget.caseId,
            userId: auth.user?.id,
          );
      setState(() => _case = details);
      if (connectHub && auth.session != null) {
        try {
          await _hub.connect(
            accessToken: auth.session!.accessToken,
            caseId: widget.caseId,
            currentUserId: auth.user?.id,
            onMessage: (message) {
              if (!mounted) return;
              setState(() {
                final current = _case;
                if (current == null) return;
                if (current.messages.any((item) => item.id == message.id && message.id != 0)) {
                  return;
                }
                _case = ConsultationCase(
                  id: current.id,
                  subject: current.subject,
                  status: current.status,
                  statusId: current.statusId,
                  description: current.description,
                  dentistName: current.dentistName,
                  patientName: current.patientName,
                  createdAt: current.createdAt,
                  messages: [...current.messages, message],
                );
              });
            },
          );
        } catch (_) {
          // Чат остаётся на REST, если хаб недоступен.
        }
      }
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty && _image == null) return;
    setState(() => _sending = true);
    try {
      await context.read<CasesRepository>().sendMessage(
            caseId: widget.caseId,
            text: text,
            image: _image,
          );
      _text.clear();
      setState(() => _image = null);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _case;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item?.subject ?? 'Обращение #${widget.caseId}'),
            if (item?.status != null)
              Text(
                item!.status!,
                style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w400),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: item?.messages.length ?? 0,
                    itemBuilder: (context, index) {
                      final message = item!.messages[index];
                      final mine = message.isMine;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          constraints: const BoxConstraints(maxWidth: 320),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: mine ? AppColors.outgoingBubble : AppColors.incomingBubble,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (message.senderName != null)
                                Text(
                                  message.senderName!,
                                  style: const TextStyle(fontSize: 11, color: AppColors.accent),
                                ),
                              if (message.text.isNotEmpty) Text(message.text),
                              if (message.imageUrl != null) ...[
                                const SizedBox(height: 6),
                                Image.network(message.imageUrl!, height: 140, fit: BoxFit.cover),
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
                    onPressed: () async {
                      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
                      if (file == null) return;
                      setState(() => _image = File(file.path));
                    },
                    icon: const Icon(Icons.photo_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      decoration: const InputDecoration(hintText: 'Сообщение врачу'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(backgroundColor: AppColors.accent),
                    icon: const Icon(Icons.send, color: Color(0xFF06221C)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
