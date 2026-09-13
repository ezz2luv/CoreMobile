import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../config/api_config.dart';
import '../models/models.dart';
import 'api_client.dart';

class CasesRepository {
  CasesRepository(this._api);

  final ApiClient _api;

  Future<CaseFormData> formData() async {
    final data = await _api.get<dynamic>(ApiConfig.casesFormData);
    return CaseFormData.fromJson(asMap(data));
  }

  Future<List<ConsultationCase>> list({int? userId}) async {
    final data = await _api.get<dynamic>(ApiConfig.cases);
    return asList(data)
        .whereType<Map>()
        .map((e) => ConsultationCase.fromJson(Map<String, dynamic>.from(e), currentUserId: userId))
        .toList();
  }

  Future<ConsultationCase> details(int id, {int? userId}) async {
    final data = await _api.get<dynamic>(ApiConfig.caseById(id));
    return ConsultationCase.fromJson(asMap(data), currentUserId: userId);
  }

  Future<ConsultationCase> create({
    required int dentistId,
    required int subjectId,
    required String description,
    File? image,
    int? userId,
  }) async {
    final form = FormData.fromMap({
      'DentistId': dentistId,
      'SubjectId': subjectId,
      'Description': description,
      if (image != null)
        'Image': await MultipartFile.fromFile(
          image.path,
          filename: p.basename(image.path),
        ),
    });
    final data = await _api.post<dynamic>(ApiConfig.cases, data: form, multipart: true);
    if (data is Map) {
      return ConsultationCase.fromJson(Map<String, dynamic>.from(data), currentUserId: userId);
    }
    return ConsultationCase(id: asInt(data) ?? 0, description: description);
  }

  Future<void> sendMessage({
    required int caseId,
    String? text,
    File? image,
  }) async {
    final form = FormData.fromMap({
      if (text != null && text.trim().isNotEmpty) 'Text': text.trim(),
      if (image != null)
        'Image': await MultipartFile.fromFile(
          image.path,
          filename: p.basename(image.path),
        ),
    });
    await _api.post<dynamic>(ApiConfig.caseMessages(caseId), data: form, multipart: true);
  }
}
