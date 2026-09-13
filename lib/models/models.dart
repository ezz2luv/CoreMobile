dynamic pick(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key) && json[key] != null) return json[key];
  }
  final lower = {
    for (final entry in json.entries) entry.key.toLowerCase(): entry.value,
  };
  for (final key in keys) {
    final value = lower[key.toLowerCase()];
    if (value != null) return value;
  }
  return null;
}

int? asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String asString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  return value.toString();
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

List<dynamic> asList(dynamic value) {
  if (value is List) return value;
  return const [];
}

DateTime? asDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

class UserAccount {
  const UserAccount({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.roleId,
    this.roleName,
  });

  final int id;
  final String email;
  final String? firstName;
  final String? lastName;
  final int? roleId;
  final String? roleName;

  String get displayName {
    final parts = [firstName, lastName].where((e) => (e ?? '').trim().isNotEmpty);
    if (parts.isNotEmpty) return parts.join(' ');
    return email;
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      id: asInt(pick(json, ['id', 'userId'])) ?? 0,
      email: asString(pick(json, ['email'])),
      firstName: pick(json, ['firstName', 'name', 'givenName'])?.toString(),
      lastName: pick(json, ['lastName', 'surname', 'familyName'])?.toString(),
      roleId: asInt(pick(json, ['roleId', 'role'])),
      roleName: pick(json, ['roleName'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'roleId': roleId,
        'roleName': roleName,
      };
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.user,
    this.expiresIn,
  });

  final String accessToken;
  final UserAccount user;
  final int? expiresIn;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final userRaw = pick(json, ['user', 'account']);
    return AuthSession(
      accessToken: asString(pick(json, ['accessToken', 'token', 'jwt'])),
      expiresIn: asInt(pick(json, ['expiresIn', 'expires', 'lifetime'])),
      user: UserAccount.fromJson(asMap(userRaw)),
    );
  }
}

class Dentist {
  const Dentist({
    required this.id,
    required this.name,
    this.specializations = const [],
  });

  final int id;
  final String name;
  final List<String> specializations;

  factory Dentist.fromJson(Map<String, dynamic> json) {
    final specs = asList(pick(json, ['specializations', 'specialization']));
    return Dentist(
      id: asInt(pick(json, ['id', 'dentistId'])) ?? 0,
      name: asString(
        pick(json, ['name', 'fullName', 'displayName']) ??
            [
              pick(json, ['firstName']),
              pick(json, ['lastName']),
            ].where((e) => e != null).join(' '),
      ),
      specializations: specs
          .map((item) {
            if (item is Map) {
              return asString(pick(Map<String, dynamic>.from(item), ['name', 'title']));
            }
            return item.toString();
          })
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }
}

class CaseSubject {
  const CaseSubject({required this.id, required this.name});

  final int id;
  final String name;

  bool get looksLikePain {
    final lower = name.toLowerCase();
    return lower.contains('боль') || lower.contains('pain');
  }

  factory CaseSubject.fromJson(Map<String, dynamic> json) {
    return CaseSubject(
      id: asInt(pick(json, ['id', 'subjectId'])) ?? 0,
      name: asString(pick(json, ['name', 'title', 'subject'])),
    );
  }
}

class CaseFormData {
  const CaseFormData({this.dentists = const [], this.subjects = const []});

  final List<Dentist> dentists;
  final List<CaseSubject> subjects;

  factory CaseFormData.fromJson(Map<String, dynamic> json) {
    return CaseFormData(
      dentists: asList(pick(json, ['dentists', 'doctors']))
          .whereType<Map>()
          .map((e) => Dentist.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      subjects: asList(pick(json, ['subjects', 'topics', 'themes']))
          .whereType<Map>()
          .map((e) => CaseSubject.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class CaseMessage {
  const CaseMessage({
    required this.id,
    required this.text,
    this.imageUrl,
    this.senderId,
    this.senderName,
    this.createdAt,
    this.isMine = false,
  });

  final int id;
  final String text;
  final String? imageUrl;
  final int? senderId;
  final String? senderName;
  final DateTime? createdAt;
  final bool isMine;

  CaseMessage copyWith({bool? isMine}) => CaseMessage(
        id: id,
        text: text,
        imageUrl: imageUrl,
        senderId: senderId,
        senderName: senderName,
        createdAt: createdAt,
        isMine: isMine ?? this.isMine,
      );

  factory CaseMessage.fromJson(Map<String, dynamic> json, {int? currentUserId}) {
    final sender = asMap(pick(json, ['sender', 'user', 'author']));
    final senderId = asInt(pick(json, ['senderId', 'userId', 'authorId'])) ??
        asInt(pick(sender, ['id']));
    return CaseMessage(
      id: asInt(pick(json, ['id', 'messageId'])) ?? 0,
      text: asString(pick(json, ['text', 'message', 'content', 'body'])),
      imageUrl: pick(json, ['imageUrl', 'image', 'photoUrl'])?.toString(),
      senderId: senderId,
      senderName: pick(json, ['senderName'])?.toString() ??
          pick(sender, ['firstName', 'name', 'email'])?.toString(),
      createdAt: asDate(pick(json, ['createdAt', 'created', 'sentAt', 'date'])),
      isMine: currentUserId != null && senderId == currentUserId,
    );
  }
}

class ConsultationCase {
  const ConsultationCase({
    required this.id,
    this.subject,
    this.status,
    this.statusId,
    this.description,
    this.dentistName,
    this.patientName,
    this.createdAt,
    this.messages = const [],
  });

  final int id;
  final String? subject;
  final String? status;
  final int? statusId;
  final String? description;
  final String? dentistName;
  final String? patientName;
  final DateTime? createdAt;
  final List<CaseMessage> messages;

  factory ConsultationCase.fromJson(
    Map<String, dynamic> json, {
    int? currentUserId,
  }) {
    final dentist = asMap(pick(json, ['dentist', 'doctor']));
    final patient = asMap(pick(json, ['patient', 'user']));
    final subject = asMap(pick(json, ['subject', 'topic']));
    final status = asMap(pick(json, ['status']));
    return ConsultationCase(
      id: asInt(pick(json, ['id', 'caseId'])) ?? 0,
      subject: pick(json, ['subjectName', 'title'])?.toString() ??
          pick(subject, ['name', 'title'])?.toString(),
      status: pick(json, ['statusName'])?.toString() ??
          pick(status, ['name', 'title'])?.toString() ??
          pick(json, ['status'])?.toString(),
      statusId: asInt(pick(json, ['statusId'])) ?? asInt(pick(status, ['id'])),
      description: pick(json, ['description', 'text'])?.toString(),
      dentistName: pick(json, ['dentistName'])?.toString() ??
          pick(dentist, ['name', 'fullName', 'email'])?.toString(),
      patientName: pick(json, ['patientName'])?.toString() ??
          pick(patient, ['name', 'fullName', 'email'])?.toString(),
      createdAt: asDate(pick(json, ['createdAt', 'created', 'date'])),
      messages: asList(pick(json, ['messages', 'chat']))
          .whereType<Map>()
          .map(
            (e) => CaseMessage.fromJson(
              Map<String, dynamic>.from(e),
              currentUserId: currentUserId,
            ),
          )
          .toList(),
    );
  }
}

class AiChatMessage {
  const AiChatMessage({
    required this.role,
    required this.text,
    this.imagePath,
    this.createdAt,
  });

  final String role;
  final String text;
  final String? imagePath;
  final DateTime? createdAt;

  bool get isUser => role == 'user';

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
        'imagePath': imagePath,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    return AiChatMessage(
      role: asString(pick(json, ['role']), 'user'),
      text: asString(pick(json, ['text', 'content'])),
      imagePath: pick(json, ['imagePath'])?.toString(),
      createdAt: asDate(pick(json, ['createdAt'])),
    );
  }
}

class NeuralResult {
  const NeuralResult({
    required this.summary,
    this.urgency,
    this.advice,
    this.raw,
    this.isStub = false,
  });

  final String summary;
  final String? urgency;
  final String? advice;
  final Map<String, dynamic>? raw;
  final bool isStub;

  factory NeuralResult.fromJson(Map<String, dynamic> json) {
    return NeuralResult(
      summary: asString(
        pick(json, ['summary', 'result', 'diagnosis', 'message']),
        'Нейросеть вернула ответ без текста.',
      ),
      urgency: pick(json, ['urgency', 'priority'])?.toString(),
      advice: pick(json, ['advice', 'recommendation'])?.toString(),
      raw: json,
    );
  }
}
