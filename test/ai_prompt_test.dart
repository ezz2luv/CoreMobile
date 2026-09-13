import 'package:core/config/ai_prompts.dart';
import 'package:core/config/openrouter_config.dart';
import 'package:core/models/models.dart';
import 'package:core/services/neural_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reserved doctor system prompt is used by OpenRouter', () {
    expect(OpenRouterConfig.systemPrompt, kDentalAiSystemPrompt);
    expect(kDentalAiSystemPrompt, contains('многолетним клиническим стажем'));
    expect(kDentalAiSystemPrompt, contains('Не ставь окончательный диагноз'));
    expect(OpenRouterConfig.model, 'deepseek/deepseek-v4-flash');
    expect(OpenRouterConfig.baseUrl, 'https://openrouter.ai/api/v1');
  });

  test('one chat payload keeps system prompt and prior turns', () {
    final history = [
      const AiChatMessage(role: 'user', text: 'Болит шестёрка справа на холодное'),
      const AiChatMessage(role: 'assistant', text: 'Похоже на воспаление нерва. Уточните, есть ли ночная боль?'),
      const AiChatMessage(role: 'user', text: 'Да, ночью не спал'),
    ];

    final payload = NeuralService.buildChatPayload(history);

    expect(payload.first['role'], 'system');
    expect(payload.first['content'], kDentalAiSystemPrompt);
    expect(payload.length, 4);
    expect(payload[1]['role'], 'user');
    expect(payload[1]['content'], contains('шестёрка'));
    expect(payload[2]['role'], 'assistant');
    expect(payload[2]['content'], contains('нерва'));
    expect(payload[3]['role'], 'user');
    expect(payload[3]['content'], contains('ночью'));
  });
}
