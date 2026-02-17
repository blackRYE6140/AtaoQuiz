import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:atao_quiz/services/storage_service.dart';
import 'package:flutter/foundation.dart';

enum TransferConnectionState { disconnected, hosting, connecting, connected }

enum TransferDirection { sent, received, system }

enum TransferStatus { success, failed, info }

class TransferHistoryEntry {
  final String id;
  final TransferDirection direction;
  final TransferStatus status;
  final String title;
  final String message;
  final DateTime timestamp;
  final String? receivedQuizId;

  const TransferHistoryEntry({
    required this.id,
    required this.direction,
    required this.status,
    required this.title,
    required this.message,
    required this.timestamp,
    this.receivedQuizId,
  });
}

class TransferTarget {
  final String host;
  final int port;

  const TransferTarget({required this.host, required this.port});
}

class QuizTransferService extends ChangeNotifier {
  static const int defaultPort = 4040;
  static const String _protocol = 'atao_quiz.live_transfer';
  static const int _version = 2;
  static const int _maxHistoryItems = 120;

  static final QuizTransferService _instance = QuizTransferService._internal();
  factory QuizTransferService() => _instance;
  QuizTransferService._internal();

  final StorageService _storageService = StorageService();
  final Random _random = Random();

  TransferConnectionState _connectionState =
      TransferConnectionState.disconnected;
  String _statusMessage = 'Aucune connexion active.';
  List<String> _localIps = [];
  int _activePort = defaultPort;
  bool _isSendingBatch = false;
  String? _connectedPeer;
  String? _lastConnectedHost;
  final List<TransferHistoryEntry> _history = [];

  ServerSocket? _serverSocket;
  StreamSubscription<Socket>? _serverSubscription;
  Socket? _socket;
  StreamSubscription<String>? _socketLineSubscription;

  TransferConnectionState get connectionState => _connectionState;
  String get statusMessage => _statusMessage;
  List<String> get localIps => List.unmodifiable(_localIps);
  int get activePort => _activePort;
  bool get isSendingBatch => _isSendingBatch;
  String? get connectedPeer => _connectedPeer;
  bool get isConnected =>
      _connectionState == TransferConnectionState.connected && _socket != null;
  bool get isHosting => _connectionState == TransferConnectionState.hosting;
  bool get canReconnect =>
      _lastConnectedHost != null &&
      _connectionState != TransferConnectionState.connected;
  List<TransferHistoryEntry> get history => List.unmodifiable(_history);

  Future<void> initialize() async {
    await refreshLocalIps();
  }

  Future<void> refreshLocalIps() async {
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

    _localIps = addresses.toList()..sort();
    notifyListeners();
  }

  String? buildQrPayload() {
    final host = _localIps.isNotEmpty ? _localIps.first : null;
    if (host == null) {
      return null;
    }

    final uri = Uri(
      scheme: 'ataoquiz',
      host: 'transfer',
      queryParameters: {
        'protocol': _protocol,
        'v': '$_version',
        'host': host,
        'port': '$_activePort',
      },
    );
    return uri.toString();
  }

  TransferTarget? parseTransferPayload(String payload) {
    final raw = payload.trim();
    if (raw.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(raw);
    if (uri != null &&
        uri.scheme == 'ataoquiz' &&
        uri.host == 'transfer' &&
        uri.queryParameters.containsKey('host')) {
      final host = uri.queryParameters['host'];
      final portRaw = uri.queryParameters['port'];
      final port = int.tryParse(portRaw ?? '');
      if (host != null && host.isNotEmpty && port != null) {
        return TransferTarget(host: host, port: port);
      }
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final host = decoded['host']?.toString();
        final port = int.tryParse(decoded['port']?.toString() ?? '');
        if (host != null && host.isNotEmpty && port != null) {
          return TransferTarget(host: host, port: port);
        }
      }
    } catch (_) {
      // Ignore parsing error, null is returned below.
    }

    return null;
  }

  Future<void> startHosting({required int port}) async {
    if (port < 1 || port > 65535) {
      throw const FormatException('Port invalide (1..65535).');
    }

    await stopHosting(keepConnection: false, addLog: false);
    _activePort = port;
    _statusMessage = 'Démarrage du serveur en cours...';
    _connectionState = TransferConnectionState.hosting;
    notifyListeners();

    try {
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _serverSocket = server;
      _serverSubscription = server.listen(
        _onClientIncoming,
        onError: (Object error) {
          _appendHistory(
            direction: TransferDirection.system,
            status: TransferStatus.failed,
            title: 'Serveur',
            message: 'Erreur serveur: $error',
          );
          _statusMessage = 'Erreur serveur: $error';
          _connectionState = TransferConnectionState.disconnected;
          notifyListeners();
        },
      );

      await refreshLocalIps();
      _statusMessage =
          'Serveur actif sur le port $port. Partagez le QR au second téléphone.';
      _appendHistory(
        direction: TransferDirection.system,
        status: TransferStatus.info,
        title: 'Serveur',
        message: 'Serveur prêt sur le port $port.',
      );
      notifyListeners();
    } catch (e) {
      _connectionState = TransferConnectionState.disconnected;
      _statusMessage = 'Impossible de démarrer le serveur: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stopHosting({
    bool keepConnection = true,
    bool addLog = true,
  }) async {
    await _serverSubscription?.cancel();
    _serverSubscription = null;
    await _serverSocket?.close();
    _serverSocket = null;

    if (!keepConnection) {
      await disconnect(addLog: false);
    }

    if (!isConnected) {
      _connectionState = TransferConnectionState.disconnected;
      _statusMessage = 'Serveur arrêté.';
    }

    if (addLog) {
      _appendHistory(
        direction: TransferDirection.system,
        status: TransferStatus.info,
        title: 'Serveur',
        message: 'Serveur arrêté.',
      );
    }

    notifyListeners();
  }

  Future<void> connectToPeer({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (host.trim().isEmpty) {
      throw const FormatException('Adresse IP vide.');
    }
    if (port < 1 || port > 65535) {
      throw const FormatException('Port invalide (1..65535).');
    }

    await disconnect(addLog: false);
    _connectionState = TransferConnectionState.connecting;
    _statusMessage = 'Connexion vers $host:$port...';
    notifyListeners();

    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      _lastConnectedHost = host;
      _activePort = port;
      await _attachSocket(socket, peerLabel: '$host:$port');
      _appendHistory(
        direction: TransferDirection.system,
        status: TransferStatus.info,
        title: 'Connexion',
        message: 'Connecté à $host:$port',
      );
    } catch (e) {
      _connectionState = TransferConnectionState.disconnected;
      _statusMessage = 'Échec connexion: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> reconnectLastPeer() async {
    final host = _lastConnectedHost;
    if (host == null) {
      throw StateError('Aucun pair précédent.');
    }
    await connectToPeer(host: host, port: _activePort);
  }

  Future<void> disconnect({bool addLog = true}) async {
    await _socketLineSubscription?.cancel();
    _socketLineSubscription = null;
    _socket?.destroy();
    _socket = null;
    _connectedPeer = null;

    if (_serverSocket != null) {
      _connectionState = TransferConnectionState.hosting;
      _statusMessage =
          'Serveur actif sur le port $_activePort. En attente d\'un pair.';
    } else {
      _connectionState = TransferConnectionState.disconnected;
      _statusMessage = 'Connexion fermée.';
    }

    if (addLog) {
      _appendHistory(
        direction: TransferDirection.system,
        status: TransferStatus.info,
        title: 'Connexion',
        message: 'Connexion fermée.',
      );
    }

    notifyListeners();
  }

  Future<void> sendQuizzes(List<Quiz> quizzes) async {
    if (!isConnected) {
      throw StateError('Aucun pair connecté.');
    }
    if (quizzes.isEmpty) {
      throw StateError('Aucun quiz sélectionné.');
    }

    final socket = _socket;
    if (socket == null) {
      throw StateError('Socket indisponible.');
    }

    _isSendingBatch = true;
    _statusMessage = 'Envoi de ${quizzes.length} quiz en cours...';
    notifyListeners();

    for (final quiz in quizzes) {
      final transferId = _createTransferId();
      final cleanQuiz = _sanitizeOutgoingQuiz(quiz);
      final payload = {
        'type': 'quiz',
        'transferId': transferId,
        'sentAt': DateTime.now().toIso8601String(),
        'quiz': cleanQuiz.toJson(),
      };

      try {
        await _sendMessage(socket, payload);
        _appendHistory(
          direction: TransferDirection.sent,
          status: TransferStatus.success,
          title: cleanQuiz.title,
          message: 'Quiz envoyé.',
        );
      } catch (e) {
        _appendHistory(
          direction: TransferDirection.sent,
          status: TransferStatus.failed,
          title: cleanQuiz.title,
          message: 'Échec d\'envoi: $e',
        );
      }
    }

    _isSendingBatch = false;
    _statusMessage = 'Envoi terminé.';
    notifyListeners();
  }

  Future<void> removeHistoryEntry(TransferHistoryEntry entry) async {
    if (entry.receivedQuizId != null) {
      await _storageService.deleteQuiz(entry.receivedQuizId!);
    }
    _history.removeWhere((item) => item.id == entry.id);
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  Future<void> _onClientIncoming(Socket client) async {
    if (_socket != null) {
      client.destroy();
      _appendHistory(
        direction: TransferDirection.system,
        status: TransferStatus.info,
        title: 'Connexion',
        message: 'Nouveau pair refusé: connexion déjà active.',
      );
      return;
    }

    await _attachSocket(
      client,
      peerLabel: '${client.remoteAddress.address}:${client.remotePort}',
    );
    _appendHistory(
      direction: TransferDirection.system,
      status: TransferStatus.info,
      title: 'Connexion',
      message: 'Pair connecté: ${client.remoteAddress.address}',
    );
  }

  Future<void> _attachSocket(Socket socket, {required String peerLabel}) async {
    await _socketLineSubscription?.cancel();
    _socket?.destroy();

    _socket = socket;
    _connectedPeer = peerLabel;
    _connectionState = TransferConnectionState.connected;
    _statusMessage = 'Connecté à $peerLabel';
    notifyListeners();

    _socketLineSubscription = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) => unawaited(_handleIncomingLine(line)),
          onError: (Object error) {
            _appendHistory(
              direction: TransferDirection.system,
              status: TransferStatus.failed,
              title: 'Connexion',
              message: 'Erreur socket: $error',
            );
            unawaited(_onSocketDisconnected('Erreur socket: $error'));
          },
          onDone: () {
            unawaited(_onSocketDisconnected('Pair déconnecté.'));
          },
          cancelOnError: true,
        );

    await _sendMessage(socket, {'type': 'hello', 'device': 'AtaoQuiz'});
  }

  Future<void> _onSocketDisconnected(String reason) async {
    await _socketLineSubscription?.cancel();
    _socketLineSubscription = null;
    _socket?.destroy();
    _socket = null;
    _connectedPeer = null;

    if (_serverSocket != null) {
      _connectionState = TransferConnectionState.hosting;
      _statusMessage =
          'Pair déconnecté. Serveur toujours actif sur le port $_activePort.';
    } else {
      _connectionState = TransferConnectionState.disconnected;
      _statusMessage = reason;
    }

    _appendHistory(
      direction: TransferDirection.system,
      status: TransferStatus.info,
      title: 'Connexion',
      message: reason,
    );
    notifyListeners();
  }

  Future<void> _handleIncomingLine(String line) async {
    if (line.trim().isEmpty) {
      return;
    }

    Map<String, dynamic> envelope;
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Envelope non-JSON.');
      }
      envelope = decoded;
    } catch (e) {
      _appendHistory(
        direction: TransferDirection.system,
        status: TransferStatus.failed,
        title: 'Réception',
        message: 'Message invalide: $e',
      );
      return;
    }

    if (envelope['protocol'] != _protocol || envelope['version'] != _version) {
      _appendHistory(
        direction: TransferDirection.system,
        status: TransferStatus.failed,
        title: 'Réception',
        message: 'Protocole incompatible.',
      );
      return;
    }

    final type = envelope['type']?.toString();
    switch (type) {
      case 'hello':
        _statusMessage = 'Connexion active avec le pair.';
        notifyListeners();
        return;
      case 'ack':
        _appendHistory(
          direction: TransferDirection.system,
          status: TransferStatus.info,
          title: 'Accusé',
          message: envelope['message']?.toString() ?? 'Accusé reçu.',
        );
        return;
      case 'quiz':
        await _handleIncomingQuiz(envelope);
        return;
      default:
        _appendHistory(
          direction: TransferDirection.system,
          status: TransferStatus.failed,
          title: 'Réception',
          message: 'Type de message inconnu: $type',
        );
    }
  }

  Future<void> _handleIncomingQuiz(Map<String, dynamic> envelope) async {
    final socket = _socket;
    if (socket == null) {
      return;
    }

    final transferId =
        envelope['transferId']?.toString() ?? _createTransferId();
    final quizRaw = envelope['quiz'];
    if (quizRaw is! Map<String, dynamic>) {
      await _sendMessage(socket, {
        'type': 'ack',
        'transferId': transferId,
        'ok': false,
        'message': 'Payload quiz invalide.',
      });
      _appendHistory(
        direction: TransferDirection.received,
        status: TransferStatus.failed,
        title: 'Quiz invalide',
        message: 'Payload quiz invalide.',
      );
      return;
    }

    try {
      final incomingQuiz = Quiz.fromJson(quizRaw);
      final preparedQuiz = await _prepareReceivedQuiz(incomingQuiz);
      await _storageService.saveQuiz(preparedQuiz);

      await _sendMessage(socket, {
        'type': 'ack',
        'transferId': transferId,
        'ok': true,
        'message': 'Quiz reçu: ${preparedQuiz.title}',
      });

      _appendHistory(
        direction: TransferDirection.received,
        status: TransferStatus.success,
        title: preparedQuiz.title,
        message: 'Quiz importé.',
        receivedQuizId: preparedQuiz.id,
      );
      _statusMessage = 'Quiz reçu: ${preparedQuiz.title}';
      notifyListeners();
    } catch (e) {
      await _sendMessage(socket, {
        'type': 'ack',
        'transferId': transferId,
        'ok': false,
        'message': 'Erreur import: $e',
      });
      _appendHistory(
        direction: TransferDirection.received,
        status: TransferStatus.failed,
        title: 'Erreur import',
        message: 'Impossible d\'importer le quiz: $e',
      );
    }
  }

  Future<void> _sendMessage(Socket socket, Map<String, dynamic> payload) async {
    final envelope = {'protocol': _protocol, 'version': _version, ...payload};
    socket.add(utf8.encode('${jsonEncode(envelope)}\n'));
    await socket.flush();
  }

  Future<Quiz> _prepareReceivedQuiz(Quiz incomingQuiz) async {
    final existingQuizzes = await _storageService.getQuizzes();
    final existingIds = existingQuizzes.map((quiz) => quiz.id).toSet();

    var newId = incomingQuiz.id;
    var newTitle = incomingQuiz.title;
    if (existingIds.contains(newId)) {
      newId = '${incomingQuiz.id}_${DateTime.now().millisecondsSinceEpoch}';
      newTitle = '${incomingQuiz.title} (copie)';
    }

    final copiedQuestions = incomingQuiz.questions
        .map(
          (question) => Question(
            text: question.text,
            options: List<String>.from(question.options),
            correctIndex: question.correctIndex,
          ),
        )
        .toList();

    return incomingQuiz.copyWith(
      id: newId,
      title: newTitle,
      questions: copiedQuestions,
      questionCount: copiedQuestions.length,
      origin: 'transfer',
      receivedAt: DateTime.now(),
      clearScore: true,
      clearPlayedAt: true,
    );
  }

  Quiz _sanitizeOutgoingQuiz(Quiz quiz) {
    final cleanedQuestions = quiz.questions
        .map(
          (question) => Question(
            text: question.text,
            options: List<String>.from(question.options),
            correctIndex: question.correctIndex,
          ),
        )
        .toList();

    return quiz.copyWith(
      questions: cleanedQuestions,
      questionCount: cleanedQuestions.length,
      clearScore: true,
      clearPlayedAt: true,
    );
  }

  void _appendHistory({
    required TransferDirection direction,
    required TransferStatus status,
    required String title,
    required String message,
    String? receivedQuizId,
  }) {
    _history.insert(
      0,
      TransferHistoryEntry(
        id: _createTransferId(),
        direction: direction,
        status: status,
        title: title,
        message: message,
        timestamp: DateTime.now(),
        receivedQuizId: receivedQuizId,
      ),
    );

    if (_history.length > _maxHistoryItems) {
      _history.removeRange(_maxHistoryItems, _history.length);
    }
    notifyListeners();
  }

  String _createTransferId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = _random.nextInt(900000) + 100000;
    return '$now$random';
  }
}
