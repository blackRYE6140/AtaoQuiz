import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:atao_quiz/services/storage_service.dart';

class QuizTransferService {
  static const int defaultPort = 4040;
  static const String _protocol = 'atao_quiz.quiz_transfer';
  static const int _version = 1;

  Future<List<String>> getLocalIpv4Addresses() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );

    final addresses = <String>{};
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (address.isLoopback) {
          continue;
        }
        if (address.address.startsWith('169.254.')) {
          continue;
        }
        addresses.add(address.address);
      }
    }

    return addresses.toList()..sort();
  }

  Future<ServerSocket> startServer({required int port}) {
    return ServerSocket.bind(InternetAddress.anyIPv4, port);
  }

  Future<void> sendQuiz(Socket socket, Quiz quiz) async {
    final payload = jsonEncode({
      'protocol': _protocol,
      'version': _version,
      'sentAt': DateTime.now().toIso8601String(),
      'quiz': quiz.toJson(),
    });

    socket.add(utf8.encode(payload));
    await socket.flush();
  }

  Future<Quiz> receiveQuiz({
    required String host,
    required int port,
    Duration connectTimeout = const Duration(seconds: 12),
    Duration readTimeout = const Duration(seconds: 20),
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: connectTimeout);
      final buffer = <int>[];
      final done = Completer<void>();

      socket.listen(
        buffer.addAll,
        onDone: () => done.complete(),
        onError: done.completeError,
        cancelOnError: true,
      );

      await done.future.timeout(readTimeout);

      if (buffer.isEmpty) {
        throw const FormatException('Aucune donnée reçue.');
      }

      final rawPayload = utf8.decode(buffer);
      return _decodeQuiz(rawPayload);
    } on TimeoutException {
      throw const SocketException('Délai dépassé pendant le transfert.');
    } finally {
      socket?.destroy();
    }
  }

  Quiz _decodeQuiz(String payload) {
    final dynamic decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Format de transfert invalide.');
    }

    final Map<String, dynamic> map = decoded;
    final dynamic payloadQuiz = map['quiz'];

    if (map['protocol'] == _protocol &&
        map['version'] == _version &&
        payloadQuiz is Map<String, dynamic>) {
      return Quiz.fromJson(payloadQuiz);
    }

    // Compatibilité: accepte un JSON de quiz direct sans enveloppe.
    if (map.containsKey('questions') && map.containsKey('title')) {
      return Quiz.fromJson(map);
    }

    throw const FormatException('Fichier quiz non reconnu.');
  }
}
