import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../config/api_config.dart';
import '../models/models.dart';

class CasesHub {
  HubConnection? _connection;

  Future<void> connect({
    required String accessToken,
    required int caseId,
    required ValueChanged<CaseMessage> onMessage,
    int? currentUserId,
  }) async {
    await disconnect();
    final connection = HubConnectionBuilder()
        .withUrl(
          '${ApiConfig.casesHub}?access_token=$accessToken',
          options: HttpConnectionOptions(
            accessTokenFactory: () async => accessToken,
          ),
        )
        .withAutomaticReconnect()
        .build();

    void handle(List<Object?>? args) {
      if (args == null || args.isEmpty) return;
      final raw = args.first;
      if (raw is Map) {
        onMessage(
          CaseMessage.fromJson(
            Map<String, dynamic>.from(raw),
            currentUserId: currentUserId,
          ),
        );
      }
    }

    connection.on('ReceiveMessage', handle);
    connection.on('CaseMessage', handle);
    connection.on('message', handle);

    await connection.start();
    try {
      await connection.invoke('JoinCase', args: [caseId]);
    } catch (_) {
      try {
        await connection.invoke('Join', args: [caseId]);
      } catch (_) {}
    }
    _connection = connection;
  }

  Future<void> disconnect() async {
    final connection = _connection;
    _connection = null;
    if (connection == null) return;
    try {
      await connection.stop();
    } catch (_) {}
  }
}
