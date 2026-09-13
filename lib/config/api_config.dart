/// Глобальные адреса бэкенда. Меняйте только здесь.
class ApiConfig {
  ApiConfig._();

  /// Базовый URL REST API (без слэша в конце).
  static String apiBaseUrl = 'http://127.0.0.1:5000';

  static String get auth => '$apiBaseUrl/api/auth';
  static String get register => '$apiBaseUrl/api/auth/register';
  static String get cases => '$apiBaseUrl/api/cases';
  static String get casesFormData => '$apiBaseUrl/api/cases/form-data';
  static String caseById(Object id) => '$apiBaseUrl/api/cases/$id';
  static String caseMessages(Object id) => '$apiBaseUrl/api/cases/$id/messages';
  static String get casesHub => '$apiBaseUrl/hubs/cases';
}
