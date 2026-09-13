import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../models/models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient()
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
            headers: const {'Accept': 'application/json'},
          ),
        );

  final Dio _dio;
  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  Options _options({bool multipart = false}) {
    return Options(
      headers: {
        if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
        if (!multipart) 'Content-Type': 'application/json',
      },
    );
  }

  Future<T> get<T>(String url) async {
    return _run(() => _dio.get<T>(url, options: _options()));
  }

  Future<T> post<T>(String url, {dynamic data, bool multipart = false}) async {
    return _run(
      () => _dio.post<T>(url, data: data, options: _options(multipart: multipart)),
    );
  }

  Future<T> put<T>(String url, {dynamic data}) async {
    return _run(() => _dio.put<T>(url, data: data, options: _options()));
  }

  Future<T> _run<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      return response.data as T;
    } on DioException catch (error) {
      throw ApiException(_messageFrom(error), statusCode: error.response?.statusCode);
    }
  }

  String _messageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final picked = pick(map, ['message', 'error', 'title', 'detail']);
      if (picked != null && picked.toString().trim().isNotEmpty) {
        return picked.toString();
      }
    }
    if (data is String && data.trim().isNotEmpty) return data;
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Не удалось подключиться к серверу (${ApiConfig.apiBaseUrl}).';
    }
    return error.message ?? 'Ошибка запроса';
  }
}
