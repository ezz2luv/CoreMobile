import 'ai_prompts.dart';

/// OpenRouter: отдельный ИИ-разбор, не бэкенд консультаций.
class OpenRouterConfig {
  OpenRouterConfig._();

  /// Ключ не хранится в git. Задаётся через --dart-define=OPENROUTER_API_KEY=...
  /// или файл `.openrouter_key` в корне проекта (см. .gitignore).
  static const String apiKeyFromEnv = String.fromEnvironment('OPENROUTER_API_KEY');
  static String baseUrl = 'https://openrouter.ai/api/v1';
  static String model = 'deepseek/deepseek-v4-flash';

  static String get chatCompletions => '$baseUrl/chat/completions';

  static const systemPrompt = kDentalAiSystemPrompt;
}
