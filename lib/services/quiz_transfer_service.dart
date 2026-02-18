import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:atao_quiz/services/challenge_service.dart';
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

class LiveChallengePlayerResult {
  final String playerName;
  final int score;
  final int totalQuestions;
  final int completionDurationMs;
  final DateTime completedAt;

  const LiveChallengePlayerResult({
    required this.playerName,
    required this.score,
    required this.totalQuestions,
    required this.completionDurationMs,
    required this.completedAt,
  });

  double get successRate {
    if (totalQuestions <= 0) {
      return 0;
    }
    return score / totalQuestions;
  }

  Map<String, dynamic> toJson() {
    return {
      'playerName': playerName,
      'score': score,
      'totalQuestions': totalQuestions,
      'completionDurationMs': completionDurationMs,
      'completedAt': completedAt.toIso8601String(),
    };
  }

  factory LiveChallengePlayerResult.fromJson(Map<String, dynamic> json) {
    return LiveChallengePlayerResult(
      playerName: json['playerName']?.toString() ?? 'Joueur',
      score: int.tryParse('${json['score']}') ?? 0,
      totalQuestions: int.tryParse('${json['totalQuestions']}') ?? 0,
      completionDurationMs:
          int.tryParse('${json['completionDurationMs']}') ?? 0,
      completedAt:
          DateTime.tryParse(json['completedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class LiveChallengeSessionState {
  final String networkSessionId;
  final String name;
  final String quizTitle;
  final int questionCount;
  final String? localSessionId;
  final String? localQuizId;
  final DateTime startedAt;
  final bool startedLocally;
  final List<LiveChallengePlayerResult> results;

  const LiveChallengeSessionState({
    required this.networkSessionId,
    required this.name,
    required this.quizTitle,
    required this.questionCount,
    required this.localSessionId,
    required this.localQuizId,
    required this.startedAt,
    required this.startedLocally,
    required this.results,
  });

  LiveChallengeSessionState copyWith({
    String? networkSessionId,
    String? name,
    String? quizTitle,
    int? questionCount,
    String? localSessionId,
    String? localQuizId,
    DateTime? startedAt,
    bool? startedLocally,
    List<LiveChallengePlayerResult>? results,
  }) {
    return LiveChallengeSessionState(
      networkSessionId: networkSessionId ?? this.networkSessionId,
      name: name ?? this.name,
      quizTitle: quizTitle ?? this.quizTitle,
      questionCount: questionCount ?? this.questionCount,
      localSessionId: localSessionId ?? this.localSessionId,
      localQuizId: localQuizId ?? this.localQuizId,
      startedAt: startedAt ?? this.startedAt,
      startedLocally: startedLocally ?? this.startedLocally,
      results: results ?? this.results,
    );
  }
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
  final ChallengeService _challengeService = ChallengeService();
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

  final Map<String, Socket> _peerSockets = {};
  final Map<String, StreamSubscription<String>> _peerLineSubscriptions = {};

  final Map<String, LiveChallengeSessionState> _liveChallenges = {};
  String? _activeLiveChallengeId;

  TransferConnectionState get connectionState => _connectionState;
  String get statusMessage => _statusMessage;
  List<String> get localIps => List.unmodifiable(_localIps);
  int get activePort => _activePort;
  bool get isSendingBatch => _isSendingBatch;
  String? get connectedPeer => _connectedPeer;
  List<String> get connectedPeers =>
      List.unmodifiable(_peerSockets.keys.toList());
  int get connectedPeersCount => _peerSockets.length;
  bool get isConnected => _peerSockets.isNotEmpty;
  bool get isHosting => _serverSocket != null;
  bool get canReconnect =>
      _lastConnectedHost != null &&
      _connectionState != TransferConnectionState.connected;
  List<TransferHistoryEntry> get history => List.unmodifiable(_history);
  bool get canStartLiveChallenge => isConnected;

  List<LiveChallengeSessionState> get liveChallengeSessions {
    final values = _liveChallenges.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return List.unmodifiable(values);
  }

  LiveChallengeSessionState? get activeLiveChallenge {
    final id = _activeLiveChallengeId;
    if (id == null) {
      return null;
    }
    return _liveChallenges[id];
  }

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
      _updateConnectionStatus();
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
    } else {
      _updateConnectionStatus();
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

    if (_serverSocket != null) {
      await stopHosting(keepConnection: false, addLog: false);
    } else {
      await disconnect(addLog: false);
    }

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
      notifyListeners();
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
    final subscriptions = _peerLineSubscriptions.values.toList();
    final sockets = _peerSockets.values.toList();
    _peerLineSubscriptions.clear();
    _peerSockets.clear();

    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    for (final socket in sockets) {
      socket.destroy();
    }

    _connectedPeer = null;
    _updateConnectionStatus(reasonIfNoServer: 'Connexion fermée.');

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

    _isSendingBatch = true;
    _statusMessage =
        'Envoi de ${quizzes.length} quiz vers ${_peerSockets.length} pair(s)...';
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
        await _sendMessageToAll(payload);
        _appendHistory(
          direction: TransferDirection.sent,
          status: TransferStatus.success,
          title: cleanQuiz.title,
          message: 'Quiz envoyé à ${_peerSockets.length} pair(s).',
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
    _updateConnectionStatus();
    notifyListeners();
  }

  Future<String> startLiveChallenge({
    required ChallengeSession session,
    required Quiz quiz,
    required String hostPlayerName,
  }) async {
    if (!isConnected) {
      throw StateError('Aucun pair connecté.');
    }

    final networkSessionId =
        session.networkSessionId ?? _createNetworkChallengeId();
    if (session.networkSessionId == null) {
      await _challengeService.linkSessionToNetworkSession(
        sessionId: session.id,
        networkSessionId: networkSessionId,
      );
    }

    final cleanQuiz = _sanitizeOutgoingQuiz(quiz);
    final startedAt = DateTime.now();

    _liveChallenges[networkSessionId] = LiveChallengeSessionState(
      networkSessionId: networkSessionId,
      name: session.name,
      quizTitle: session.quizTitle,
      questionCount: session.questionCount,
      localSessionId: session.id,
      localQuizId: quiz.id,
      startedAt: startedAt,
      startedLocally: true,
      results: _liveChallenges[networkSessionId]?.results ?? const [],
    );
    _activeLiveChallengeId = networkSessionId;

    await _sendMessageToAll({
      'type': 'challenge_start',
      'networkSessionId': networkSessionId,
      'sessionName': session.name,
      'quizTitle': session.quizTitle,
      'questionCount': session.questionCount,
      'hostPlayerName': hostPlayerName.trim(),
      'startedAt': startedAt.toIso8601String(),
      'quiz': cleanQuiz.toJson(),
    });

    _appendHistory(
      direction: TransferDirection.system,
      status: TransferStatus.info,
      title: 'Challenge',
      message:
          'Challenge réseau "${session.name}" lancé pour ${_peerSockets.length} pair(s).',
    );
    _statusMessage = 'Challenge réseau actif: ${session.name}';
    notifyListeners();
    return networkSessionId;
  }

  Future<void> submitLiveChallengeResult({
    required String networkSessionId,
    required String participantName,
    required int score,
    required int totalQuestions,
    required int completionDurationMs,
  }) async {
    if (totalQuestions <= 0) {
      throw const FormatException('Le quiz doit contenir au moins 1 question.');
    }
    if (score < 0 || score > totalQuestions) {
      throw const FormatException('Score invalide.');
    }
    if (completionDurationMs < 0) {
      throw const FormatException('Durée invalide.');
    }

    final normalizedName = participantName.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('Nom joueur vide.');
    }

    final result = LiveChallengePlayerResult(
      playerName: normalizedName,
      score: score,
      totalQuestions: totalQuestions,
      completionDurationMs: completionDurationMs,
      completedAt: DateTime.now(),
    );

    _upsertLiveResult(networkSessionId, result);
    await _persistLiveResult(networkSessionId, result);

    if (_serverSocket != null) {
      await _broadcastLiveLeaderboard(networkSessionId);
    } else {
      await _sendMessageToAll({
        'type': 'challenge_result',
        'networkSessionId': networkSessionId,
        'result': result.toJson(),
      });
    }

    notifyListeners();
  }

  LiveChallengeSessionState? getLiveChallengeByNetworkId(
    String networkSessionId,
  ) {
    return _liveChallenges[networkSessionId];
  }

  List<LiveChallengePlayerResult> getRankedResultsForNetworkSession(
    String networkSessionId,
  ) {
    final session = _liveChallenges[networkSessionId];
    if (session == null) {
      return const [];
    }
    return _sortLiveResults(session.results);
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
    final peerLabel = '${client.remoteAddress.address}:${client.remotePort}';
    await _attachSocket(client, peerLabel: peerLabel);
    _appendHistory(
      direction: TransferDirection.system,
      status: TransferStatus.info,
      title: 'Connexion',
      message: 'Pair connecté: $peerLabel',
    );
    notifyListeners();
  }

  Future<void> _attachSocket(Socket socket, {required String peerLabel}) async {
    final existingSubscription = _peerLineSubscriptions.remove(peerLabel);
    final existingSocket = _peerSockets.remove(peerLabel);
    await existingSubscription?.cancel();
    existingSocket?.destroy();

    _peerSockets[peerLabel] = socket;
    _connectedPeer = _peerSockets.keys.first;
    _updateConnectionStatus();

    _peerLineSubscriptions[peerLabel] = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) => unawaited(_handleIncomingLine(peerLabel, line)),
          onError: (Object error) {
            _appendHistory(
              direction: TransferDirection.system,
              status: TransferStatus.failed,
              title: 'Connexion',
              message: 'Erreur socket ($peerLabel): $error',
            );
            unawaited(_onPeerDisconnected(peerLabel, 'Erreur socket: $error'));
          },
          onDone: () {
            unawaited(_onPeerDisconnected(peerLabel, 'Pair déconnecté.'));
          },
          cancelOnError: true,
        );

    await _sendMessageToPeer(peerLabel, {
      'type': 'hello',
      'device': 'AtaoQuiz',
    });

    await _sendActiveLiveChallengeToNewPeer(peerLabel);
    notifyListeners();
  }

  Future<void> _onPeerDisconnected(String peerLabel, String reason) async {
    final subscription = _peerLineSubscriptions.remove(peerLabel);
    await subscription?.cancel();
    final socket = _peerSockets.remove(peerLabel);
    socket?.destroy();

    _connectedPeer = _peerSockets.isEmpty ? null : _peerSockets.keys.first;
    _updateConnectionStatus(reasonIfNoServer: reason);

    _appendHistory(
      direction: TransferDirection.system,
      status: TransferStatus.info,
      title: 'Connexion',
      message: '$peerLabel: $reason',
    );
    notifyListeners();
  }

  Future<void> _handleIncomingLine(String peerLabel, String line) async {
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
        message: 'Message invalide ($peerLabel): $e',
      );
      return;
    }

    if (envelope['protocol'] != _protocol || envelope['version'] != _version) {
      _appendHistory(
        direction: TransferDirection.system,
        status: TransferStatus.failed,
        title: 'Réception',
        message: 'Protocole incompatible depuis $peerLabel.',
      );
      return;
    }

    final type = envelope['type']?.toString();
    switch (type) {
      case 'hello':
        _updateConnectionStatus();
        notifyListeners();
        return;
      case 'ack':
        _appendHistory(
          direction: TransferDirection.system,
          status: TransferStatus.info,
          title: 'Accusé',
          message:
              '[$peerLabel] ${envelope['message']?.toString() ?? 'Accusé reçu.'}',
        );
        return;
      case 'quiz':
        await _handleIncomingQuiz(peerLabel, envelope);
        return;
      case 'challenge_start':
        await _handleIncomingChallengeStart(peerLabel, envelope);
        return;
      case 'challenge_result':
        await _handleIncomingChallengeResult(peerLabel, envelope);
        return;
      case 'challenge_leaderboard':
        await _handleIncomingChallengeLeaderboard(peerLabel, envelope);
        return;
      default:
        _appendHistory(
          direction: TransferDirection.system,
          status: TransferStatus.failed,
          title: 'Réception',
          message: 'Type inconnu depuis $peerLabel: $type',
        );
    }
  }

  Future<void> _handleIncomingQuiz(
    String peerLabel,
    Map<String, dynamic> envelope,
  ) async {
    final transferId =
        envelope['transferId']?.toString() ?? _createTransferId();
    final quizRaw = envelope['quiz'];
    if (quizRaw is! Map<String, dynamic>) {
      await _sendMessageToPeer(peerLabel, {
        'type': 'ack',
        'transferId': transferId,
        'ok': false,
        'message': 'Payload quiz invalide.',
      });
      _appendHistory(
        direction: TransferDirection.received,
        status: TransferStatus.failed,
        title: 'Quiz invalide',
        message: 'Payload quiz invalide depuis $peerLabel.',
      );
      return;
    }

    try {
      final incomingQuiz = Quiz.fromJson(quizRaw);
      final preparedQuiz = await _prepareReceivedQuiz(incomingQuiz);
      await _storageService.saveQuiz(preparedQuiz);

      await _sendMessageToPeer(peerLabel, {
        'type': 'ack',
        'transferId': transferId,
        'ok': true,
        'message': 'Quiz reçu: ${preparedQuiz.title}',
      });

      _appendHistory(
        direction: TransferDirection.received,
        status: TransferStatus.success,
        title: preparedQuiz.title,
        message: 'Quiz importé depuis $peerLabel.',
        receivedQuizId: preparedQuiz.id,
      );
      _statusMessage = 'Quiz reçu: ${preparedQuiz.title}';
      notifyListeners();
    } catch (e) {
      await _sendMessageToPeer(peerLabel, {
        'type': 'ack',
        'transferId': transferId,
        'ok': false,
        'message': 'Erreur import: $e',
      });
      _appendHistory(
        direction: TransferDirection.received,
        status: TransferStatus.failed,
        title: 'Erreur import',
        message: 'Impossible d\'importer le quiz depuis $peerLabel: $e',
      );
    }
  }

  Future<void> _handleIncomingChallengeStart(
    String peerLabel,
    Map<String, dynamic> envelope,
  ) async {
    final networkSessionId = envelope['networkSessionId']?.toString() ?? '';
    final sessionName =
        envelope['sessionName']?.toString() ?? 'Challenge réseau';
    final quizRaw = envelope['quiz'];
    if (networkSessionId.isEmpty || quizRaw is! Map<String, dynamic>) {
      _appendHistory(
        direction: TransferDirection.system,
        status: TransferStatus.failed,
        title: 'Challenge',
        message: 'Challenge réseau invalide reçu depuis $peerLabel.',
      );
      return;
    }

    try {
      final incomingQuiz = Quiz.fromJson(quizRaw);
      final preparedQuiz = await _prepareReceivedQuiz(incomingQuiz);
      await _storageService.saveQuiz(preparedQuiz);

      final session = await _challengeService.createOrGetNetworkSession(
        networkSessionId: networkSessionId,
        quiz: preparedQuiz,
        sessionName: sessionName,
      );

      final startedAt =
          DateTime.tryParse(envelope['startedAt']?.toString() ?? '') ??
          DateTime.now();

      _liveChallenges[networkSessionId] = LiveChallengeSessionState(
        networkSessionId: networkSessionId,
        name: session.name,
        quizTitle: session.quizTitle,
        questionCount: session.questionCount,
        localSessionId: session.id,
        localQuizId: preparedQuiz.id,
        startedAt: startedAt,
        startedLocally: false,
        results: _liveChallenges[networkSessionId]?.results ?? const [],
      );
      _activeLiveChallengeId = networkSessionId;

      await _sendMessageToPeer(peerLabel, {
        'type': 'ack',
        'ok': true,
        'message': 'Challenge reçu: ${session.name}',
      });

      _appendHistory(
        direction: TransferDirection.system,
        status: TransferStatus.success,
        title: 'Challenge',
        message: 'Challenge réseau reçu: ${session.name}',
      );
      _statusMessage = 'Challenge reçu: ${session.name}';
      notifyListeners();
    } catch (e) {
      await _sendMessageToPeer(peerLabel, {
        'type': 'ack',
        'ok': false,
        'message': 'Erreur challenge_start: $e',
      });
      _appendHistory(
        direction: TransferDirection.system,
        status: TransferStatus.failed,
        title: 'Challenge',
        message: 'Erreur import challenge depuis $peerLabel: $e',
      );
    }
  }

  Future<void> _handleIncomingChallengeResult(
    String peerLabel,
    Map<String, dynamic> envelope,
  ) async {
    if (_serverSocket == null) {
      return;
    }

    final networkSessionId = envelope['networkSessionId']?.toString() ?? '';
    final resultRaw = envelope['result'];
    if (networkSessionId.isEmpty || resultRaw is! Map<String, dynamic>) {
      return;
    }

    final result = LiveChallengePlayerResult.fromJson(resultRaw);
    _upsertLiveResult(networkSessionId, result);
    await _persistLiveResult(networkSessionId, result);
    await _broadcastLiveLeaderboard(networkSessionId);

    _appendHistory(
      direction: TransferDirection.system,
      status: TransferStatus.info,
      title: 'Challenge',
      message:
          'Résultat reçu de ${result.playerName} (${result.score}/${result.totalQuestions}).',
    );
    notifyListeners();
  }

  Future<void> _handleIncomingChallengeLeaderboard(
    String peerLabel,
    Map<String, dynamic> envelope,
  ) async {
    final networkSessionId = envelope['networkSessionId']?.toString() ?? '';
    if (networkSessionId.isEmpty) {
      return;
    }

    final resultsRaw = envelope['results'];
    final parsedResults = <LiveChallengePlayerResult>[];
    if (resultsRaw is List) {
      for (final item in resultsRaw) {
        if (item is Map<String, dynamic>) {
          parsedResults.add(LiveChallengePlayerResult.fromJson(item));
        } else if (item is Map) {
          parsedResults.add(
            LiveChallengePlayerResult.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final existing = _liveChallenges[networkSessionId];
    final startedAt =
        DateTime.tryParse(envelope['startedAt']?.toString() ?? '') ??
        existing?.startedAt ??
        DateTime.now();

    final merged = _mergeLiveResults(
      existing?.results ?? const [],
      parsedResults,
    );
    _liveChallenges[networkSessionId] = LiveChallengeSessionState(
      networkSessionId: networkSessionId,
      name:
          envelope['sessionName']?.toString() ??
          existing?.name ??
          'Challenge réseau',
      quizTitle:
          envelope['quizTitle']?.toString() ?? existing?.quizTitle ?? 'Quiz',
      questionCount:
          int.tryParse('${envelope['questionCount']}') ??
          existing?.questionCount ??
          0,
      localSessionId: existing?.localSessionId,
      localQuizId: existing?.localQuizId,
      startedAt: startedAt,
      startedLocally: existing?.startedLocally ?? false,
      results: _sortLiveResults(merged),
    );
    _activeLiveChallengeId = networkSessionId;

    await _persistLiveLeaderboard(
      networkSessionId,
      _liveChallenges[networkSessionId]!.results,
    );

    _appendHistory(
      direction: TransferDirection.system,
      status: TransferStatus.info,
      title: 'Challenge',
      message: 'Classement challenge mis à jour depuis $peerLabel.',
    );
    notifyListeners();
  }

  Future<void> _sendMessageToPeer(
    String peerLabel,
    Map<String, dynamic> payload,
  ) async {
    final socket = _peerSockets[peerLabel];
    if (socket == null) {
      throw StateError('Pair déconnecté: $peerLabel');
    }
    final envelope = {'protocol': _protocol, 'version': _version, ...payload};
    socket.add(utf8.encode('${jsonEncode(envelope)}\n'));
    await socket.flush();
  }

  Future<void> _sendMessageToAll(
    Map<String, dynamic> payload, {
    String? exceptPeerLabel,
  }) async {
    final peerLabels = _peerSockets.keys.toList(growable: false);
    if (peerLabels.isEmpty) {
      throw StateError('Aucun pair connecté.');
    }

    for (final peerLabel in peerLabels) {
      if (exceptPeerLabel != null && peerLabel == exceptPeerLabel) {
        continue;
      }
      try {
        await _sendMessageToPeer(peerLabel, payload);
      } catch (e) {
        await _onPeerDisconnected(peerLabel, 'Envoi impossible: $e');
      }
    }
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

  void _upsertLiveResult(
    String networkSessionId,
    LiveChallengePlayerResult incoming,
  ) {
    final existing = _liveChallenges[networkSessionId];
    final merged = _mergeLiveResults(existing?.results ?? const [], [incoming]);

    _liveChallenges[networkSessionId] = LiveChallengeSessionState(
      networkSessionId: networkSessionId,
      name: existing?.name ?? 'Challenge réseau',
      quizTitle: existing?.quizTitle ?? 'Quiz',
      questionCount: existing?.questionCount ?? incoming.totalQuestions,
      localSessionId: existing?.localSessionId,
      localQuizId: existing?.localQuizId,
      startedAt: existing?.startedAt ?? DateTime.now(),
      startedLocally: existing?.startedLocally ?? false,
      results: _sortLiveResults(merged),
    );
    _activeLiveChallengeId = networkSessionId;
  }

  List<LiveChallengePlayerResult> _mergeLiveResults(
    List<LiveChallengePlayerResult> current,
    List<LiveChallengePlayerResult> incoming,
  ) {
    final byPlayer = <String, LiveChallengePlayerResult>{};
    for (final item in current) {
      byPlayer[_playerKey(item.playerName)] = item;
    }
    for (final item in incoming) {
      final key = _playerKey(item.playerName);
      final existing = byPlayer[key];
      if (existing == null || _isBetterLiveResult(item, existing)) {
        byPlayer[key] = item;
      }
    }
    return byPlayer.values.toList();
  }

  List<LiveChallengePlayerResult> _sortLiveResults(
    List<LiveChallengePlayerResult> results,
  ) {
    final sorted = List<LiveChallengePlayerResult>.from(results)
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) {
          return byScore;
        }
        final byDuration = a.completionDurationMs.compareTo(
          b.completionDurationMs,
        );
        if (byDuration != 0) {
          return byDuration;
        }
        final byCompletedAt = a.completedAt.compareTo(b.completedAt);
        if (byCompletedAt != 0) {
          return byCompletedAt;
        }
        return a.playerName.toLowerCase().compareTo(b.playerName.toLowerCase());
      });
    return sorted;
  }

  bool _isBetterLiveResult(
    LiveChallengePlayerResult candidate,
    LiveChallengePlayerResult current,
  ) {
    if (candidate.score != current.score) {
      return candidate.score > current.score;
    }
    if (candidate.completionDurationMs != current.completionDurationMs) {
      return candidate.completionDurationMs < current.completionDurationMs;
    }
    return candidate.completedAt.isBefore(current.completedAt);
  }

  Future<void> _persistLiveResult(
    String networkSessionId,
    LiveChallengePlayerResult result,
  ) async {
    final state = _liveChallenges[networkSessionId];
    try {
      if (state?.localSessionId != null) {
        await _challengeService.upsertAttemptBySessionId(
          sessionId: state!.localSessionId!,
          participantName: result.playerName,
          score: result.score,
          totalQuestions: result.totalQuestions,
          completionDurationMs: result.completionDurationMs,
          completedAt: result.completedAt,
        );
      } else {
        await _challengeService.upsertAttemptByNetworkSessionId(
          networkSessionId: networkSessionId,
          participantName: result.playerName,
          score: result.score,
          totalQuestions: result.totalQuestions,
          completionDurationMs: result.completionDurationMs,
          completedAt: result.completedAt,
        );
      }
    } catch (e) {
      _appendHistory(
        direction: TransferDirection.system,
        status: TransferStatus.failed,
        title: 'Challenge',
        message: 'Erreur persistance score challenge: $e',
      );
    }
  }

  Future<void> _persistLiveLeaderboard(
    String networkSessionId,
    List<LiveChallengePlayerResult> results,
  ) async {
    for (final result in results) {
      await _persistLiveResult(networkSessionId, result);
    }
  }

  Future<void> _broadcastLiveLeaderboard(String networkSessionId) async {
    final state = _liveChallenges[networkSessionId];
    if (state == null) {
      return;
    }

    final sorted = _sortLiveResults(state.results);
    _liveChallenges[networkSessionId] = state.copyWith(results: sorted);

    await _sendMessageToAll({
      'type': 'challenge_leaderboard',
      'networkSessionId': networkSessionId,
      'sessionName': state.name,
      'quizTitle': state.quizTitle,
      'questionCount': state.questionCount,
      'startedAt': state.startedAt.toIso8601String(),
      'results': sorted.map((item) => item.toJson()).toList(),
    });
  }

  Future<void> _sendActiveLiveChallengeToNewPeer(String peerLabel) async {
    if (_serverSocket == null) {
      return;
    }

    final activeId = _activeLiveChallengeId;
    if (activeId == null) {
      return;
    }

    final active = _liveChallenges[activeId];
    if (active == null || !active.startedLocally) {
      return;
    }

    final localQuizId = active.localQuizId;
    if (localQuizId == null) {
      return;
    }

    final quizzes = await _storageService.getQuizzes();
    Quiz? quiz;
    for (final item in quizzes) {
      if (item.id == localQuizId) {
        quiz = item;
        break;
      }
    }
    if (quiz == null) {
      return;
    }

    final cleanQuiz = _sanitizeOutgoingQuiz(quiz);
    await _sendMessageToPeer(peerLabel, {
      'type': 'challenge_start',
      'networkSessionId': active.networkSessionId,
      'sessionName': active.name,
      'quizTitle': active.quizTitle,
      'questionCount': active.questionCount,
      'hostPlayerName': 'Hôte',
      'startedAt': active.startedAt.toIso8601String(),
      'quiz': cleanQuiz.toJson(),
    });

    if (active.results.isEmpty) {
      return;
    }

    final sorted = _sortLiveResults(active.results);
    await _sendMessageToPeer(peerLabel, {
      'type': 'challenge_leaderboard',
      'networkSessionId': active.networkSessionId,
      'sessionName': active.name,
      'quizTitle': active.quizTitle,
      'questionCount': active.questionCount,
      'startedAt': active.startedAt.toIso8601String(),
      'results': sorted.map((item) => item.toJson()).toList(),
    });
  }

  void _updateConnectionStatus({String? reasonIfNoServer}) {
    if (_peerSockets.isNotEmpty) {
      _connectionState = TransferConnectionState.connected;
      _connectedPeer = _peerSockets.keys.first;
      if (_serverSocket != null) {
        _statusMessage =
            'Serveur actif sur le port $_activePort • ${_peerSockets.length} pair(s) connecté(s).';
      } else {
        _statusMessage = _peerSockets.length == 1
            ? 'Connecté à ${_connectedPeer ?? 'pair'}'
            : '${_peerSockets.length} pairs connectés.';
      }
      return;
    }

    _connectedPeer = null;
    if (_serverSocket != null) {
      _connectionState = TransferConnectionState.hosting;
      _statusMessage =
          'Serveur actif sur le port $_activePort. En attente d\'un pair.';
      return;
    }

    _connectionState = TransferConnectionState.disconnected;
    _statusMessage = reasonIfNoServer ?? 'Aucune connexion active.';
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
  }

  String _playerKey(String name) => name.trim().toLowerCase();

  String _createNetworkChallengeId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = _random.nextInt(900000) + 100000;
    return 'net_$now$random';
  }

  String _createTransferId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = _random.nextInt(900000) + 100000;
    return '$now$random';
  }
}
