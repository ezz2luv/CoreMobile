import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/openrouter_config.dart';
import '../models/models.dart';
import 'api_client.dart';

/// ИИ-чат: один диалог, вся история уходит в OpenRouter вместе с системным промптом врача.
class NeuralService extends ChangeNotifier {
  NeuralService()
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 90),
          ),
        );

  static const _storageKey = 'core.ai.chat.v1';
  static const _maxTurns = 40;

  final Dio _dio;
  final List<AiChatMessage> messages = [];
  AiChatMessage? pendingUser;
  bool sending = false;
  bool ready = false;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw);
        if (list is List) {
          messages
            ..clear()
            ..addAll(
              list.whereType<Map>().map((item) => AiChatMessage.fromJson(Map<String, dynamic>.from(item))),
            );
        }
      } catch (_) {
        await prefs.remove(_storageKey);
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> newChat() async {
    messages.clear();
    pendingUser = null;
    sending = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<NeuralResult> send({required String text, File? image}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && image == null) {
      throw ApiException('Напишите, что беспокоит.');
    }
    final userMessage = AiChatMessage(
      role: 'user',
      text: trimmed.isEmpty ? 'Пациент прислал фото без текста.' : trimmed,
      imagePath: image?.path,
      createdAt: DateTime.now(),
    );
    sending = true;
    pendingUser = userMessage;
    notifyListeners();

    try {
      final history = [...messages, userMessage];
      final result = await _complete(await _openRouterMessages(history));
      messages
        ..add(userMessage)
        ..add(
          AiChatMessage(
            role: 'assistant',
            text: result.summary,
            createdAt: DateTime.now(),
          ),
        );
      await _persist();
      return result;
    } finally {
      sending = false;
      pendingUser = null;
      notifyListeners();
    }
  }

  /// Совместимость: одно сообщение в том же чате (история не сбрасывается).
  Future<NeuralResult> analyzePain({
    required String description,
    File? image,
    String? token,
  }) {
    return send(text: description, image: image);
  }

  /// Сборка payload: системный промпт врача + вся история этого чата.
  static List<Map<String, dynamic>> buildChatPayload(List<AiChatMessage> history) {
    final clipped = history.length <= _maxTurns ? history : history.sublist(history.length - _maxTurns);
    final lastUserIndex = clipped.lastIndexWhere((item) => item.isUser);
    return [
      {'role': 'system', 'content': OpenRouterConfig.systemPrompt},
      for (var i = 0; i < clipped.length; i++)
        {
          'role': clipped[i].isUser ? 'user' : 'assistant',
          'content': _textContent(clipped[i], includeImageHint: clipped[i].imagePath != null && i != lastUserIndex),
        },
    ];
  }

  Future<List<Map<String, dynamic>>> _openRouterMessages(List<AiChatMessage> history) async {
    final payload = buildChatPayload(history);
    final lastUser = history.lastWhere((item) => item.isUser, orElse: () => history.last);
    if (lastUser.imagePath == null) return payload;

    final file = File(lastUser.imagePath!);
    if (!file.existsSync()) return payload;

    try {
      final bytes = await file.readAsBytes();
      final mime = _mimeFor(lastUser.imagePath!);
      final lastUserPayloadIndex = payload.lastIndexWhere((item) => item['role'] == 'user');
      if (lastUserPayloadIndex >= 0) {
        payload[lastUserPayloadIndex] = {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': _userText(lastUser.text, hasImage: true)},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:$mime;base64,${base64Encode(bytes)}'},
            },
          ],
        };
      }
    } catch (_) {}
    return payload;
  }

  Future<String> _resolveApiKey() async {
    if (OpenRouterConfig.apiKeyFromEnv.isNotEmpty) {
      return OpenRouterConfig.apiKeyFromEnv;
    }
    if (!kIsWeb) {
      try {
        final file = File('.openrouter_key');
        if (await file.exists()) {
          final value = (await file.readAsString()).trim();
          if (value.isNotEmpty) return value;
        }
      } catch (_) {}
    }
    throw ApiException(
      'Нет ключа OpenRouter. Положите его в файл .openrouter_key в корне проекта или запустите с --dart-define=OPENROUTER_API_KEY=...',
    );
  }

  Future<NeuralResult> _complete(List<Map<String, dynamic>> chatMessages) async {
    final apiKey = await _resolveApiKey();
    try {
      final response = await _dio.post<dynamic>(
        OpenRouterConfig.chatCompletions,
        data: {
          'model': OpenRouterConfig.model,
          'temperature': 0.4,
          'messages': chatMessages,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://core.local',
            'X-Title': 'Core Dental',
          },
        ),
      );
      final map = asMap(response.data);
      final text = _contentFrom(map);
      if (text.trim().isEmpty) {
        throw ApiException('Модель вернула пустой ответ.');
      }
      return NeuralResult(summary: text, raw: map);
    } on DioException catch (error) {
      final payload = chatMessages.map((item) => item['content']).toList();
      final hadImage = payload.any((item) => item is List);
      if (hadImage && (error.response?.statusCode == 400 || error.response?.statusCode == 415 || error.response?.statusCode == 422)) {
        final textOnly = [
          for (final item in chatMessages)
            {
              'role': item['role'],
              'content': item['content'] is List
                  ? _flattenContent(item['content'])
                  : item['content'],
            },
        ];
        return _complete(textOnly);
      }
      throw ApiException(_openRouterMessage(error), statusCode: error.response?.statusCode);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(messages.map((item) => item.toJson()).toList()),
    );
  }

  static String _textContent(AiChatMessage message, {required bool includeImageHint}) {
    if (!message.isUser) return message.text;
    return _userText(message.text, hasImage: includeImageHint || message.imagePath != null);
  }

  static String _userText(String description, {required bool hasImage}) {
    final buffer = StringBuffer()
      ..writeln('Пациент описывает зубную боль / стоматологическую жалобу.')
      ..writeln()
      ..writeln(description.trim());
    if (hasImage) {
      buffer
        ..writeln()
        ..writeln('К этому сообщению приложено фото.');
    }
    return buffer.toString();
  }

  String _flattenContent(dynamic content) {
    if (content is String) return content;
    if (content is List) {
      return content
          .map((part) {
            if (part is Map) {
              return asString(pick(Map<String, dynamic>.from(part), ['text', 'content']));
            }
            return '';
          })
          .where((part) => part.trim().isNotEmpty)
          .join('\n');
    }
    return asString(content);
  }

  String _contentFrom(Map<String, dynamic> json) {
    final choices = asList(pick(json, ['choices']));
    if (choices.isEmpty) return asString(pick(json, ['error', 'message']));
    final message = asMap(pick(asMap(choices.first), ['message']));
    final content = pick(message, ['content']);
    if (content is String) return content;
    if (content is List) {
      return content
          .map((part) {
            if (part is Map) {
              return asString(pick(Map<String, dynamic>.from(part), ['text', 'content']));
            }
            return part.toString();
          })
          .where((part) => part.trim().isNotEmpty)
          .join('\n');
    }
    return asString(content);
  }

  String _openRouterMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final nested = pick(asMap(pick(map, ['error'])), ['message']);
      final picked = nested ?? pick(map, ['message', 'error', 'title']);
      if (picked != null && picked.toString().trim().isNotEmpty) {
        return picked.toString();
      }
    }
    if (error.type == DioExceptionType.connectionError || error.type == DioExceptionType.connectionTimeout) {
      return 'Не удалось подключиться к OpenRouter.';
    }
    return error.message ?? 'Ошибка запроса к ИИ.';
  }

  String _mimeFor(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }
}
