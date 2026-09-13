import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/models.dart';
import 'api_client.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._api);

  static const _sessionKey = 'core.auth.session';

  final ApiClient _api;
  AuthSession? session;
  String? banner;
  bool ready = false;

  bool get isLoggedIn => session?.accessToken.isNotEmpty == true;
  UserAccount? get user => session?.user;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw != null) {
      try {
        session = AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        _api.setToken(session!.accessToken);
      } catch (_) {
        await prefs.remove(_sessionKey);
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    final data = await _api.post<dynamic>(
      ApiConfig.auth,
      data: {'email': email.trim(), 'password': password},
    );
    await _store(_parseSession(data));
    banner = null;
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final data = await _api.post<dynamic>(
      ApiConfig.register,
      data: {
        'email': email.trim(),
        'password': password,
        if (firstName != null && firstName.trim().isNotEmpty) 'firstName': firstName.trim(),
        if (lastName != null && lastName.trim().isNotEmpty) 'lastName': lastName.trim(),
      },
    );
    await _store(_parseSession(data));
    banner = 'Аккаунт создан. Добро пожаловать.';
    notifyListeners();
  }

  Future<void> logout() async {
    session = null;
    _api.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    banner = 'Вы вышли из аккаунта.';
    notifyListeners();
  }

  void clearBanner() {
    if (banner == null) return;
    banner = null;
    notifyListeners();
  }

  AuthSession _parseSession(dynamic data) {
    final map = asMap(data);
    final parsed = AuthSession.fromJson(map);
    if (parsed.accessToken.isEmpty) {
      throw ApiException('Сервер не вернул accessToken.');
    }
    return parsed;
  }

  Future<void> _store(AuthSession next) async {
    session = next;
    _api.setToken(next.accessToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionKey,
      jsonEncode({
        'accessToken': next.accessToken,
        'expiresIn': next.expiresIn,
        'user': next.user.toJson(),
      }),
    );
  }
}
