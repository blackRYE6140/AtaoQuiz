import 'dart:convert';

import 'package:atao_quiz/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChallengeAttempt {
  final String id;
  final String participantName;
  final int score;
  final int totalQuestions;
  final int? completionDurationMs;
  final DateTime completedAt;

  const ChallengeAttempt({
    required this.id,
    required this.participantName,
    required this.score,
    required this.totalQuestions,
    this.completionDurationMs,
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
      'id': id,
      'participantName': participantName,
      'score': score,
      'totalQuestions': totalQuestions,
      'completionDurationMs': completionDurationMs,
      'completedAt': completedAt.toIso8601String(),
    };
  }

  factory ChallengeAttempt.fromJson(Map<String, dynamic> json) {
    return ChallengeAttempt(
      id: json['id']?.toString() ?? '',
      participantName: json['participantName']?.toString() ?? 'Joueur',
      score: int.tryParse('${json['score']}') ?? 0,
      totalQuestions: int.tryParse('${json['totalQuestions']}') ?? 0,
      completionDurationMs: int.tryParse('${json['completionDurationMs']}'),
      completedAt:
          DateTime.tryParse(json['completedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  ChallengeAttempt copyWith({
    String? id,
    String? participantName,
    int? score,
    int? totalQuestions,
    int? completionDurationMs,
    DateTime? completedAt,
  }) {
    return ChallengeAttempt(
      id: id ?? this.id,
      participantName: participantName ?? this.participantName,
      score: score ?? this.score,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      completionDurationMs: completionDurationMs ?? this.completionDurationMs,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class ChallengeSession {
  final String id;
  final String name;
  final String quizId;
  final String quizTitle;
  final int questionCount;
  final String? networkSessionId;
  final DateTime createdAt;
  final List<ChallengeAttempt> attempts;

  const ChallengeSession({
    required this.id,
    required this.name,
    required this.quizId,
    required this.quizTitle,
    required this.questionCount,
    this.networkSessionId,
    required this.createdAt,
    required this.attempts,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quizId': quizId,
      'quizTitle': quizTitle,
      'questionCount': questionCount,
      'networkSessionId': networkSessionId,
      'createdAt': createdAt.toIso8601String(),
      'attempts': attempts.map((entry) => entry.toJson()).toList(),
    };
  }

  factory ChallengeSession.fromJson(Map<String, dynamic> json) {
    final attemptsRaw = json['attempts'];
    final attempts = <ChallengeAttempt>[];
    if (attemptsRaw is List) {
      for (final item in attemptsRaw) {
        if (item is Map<String, dynamic>) {
          attempts.add(ChallengeAttempt.fromJson(item));
        } else if (item is Map) {
          attempts.add(
            ChallengeAttempt.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return ChallengeSession(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Challenge',
      quizId: json['quizId']?.toString() ?? '',
      quizTitle: json['quizTitle']?.toString() ?? 'Quiz',
      questionCount: int.tryParse('${json['questionCount']}') ?? 0,
      networkSessionId: json['networkSessionId']?.toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      attempts: attempts,
    );
  }

  ChallengeSession copyWith({
    String? id,
    String? name,
    String? quizId,
    String? quizTitle,
    int? questionCount,
    String? networkSessionId,
    DateTime? createdAt,
    List<ChallengeAttempt>? attempts,
  }) {
    return ChallengeSession(
      id: id ?? this.id,
      name: name ?? this.name,
      quizId: quizId ?? this.quizId,
      quizTitle: quizTitle ?? this.quizTitle,
      questionCount: questionCount ?? this.questionCount,
      networkSessionId: networkSessionId ?? this.networkSessionId,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
    );
  }
}

class LeaderboardEntry {
  final int rank;
  final String playerName;
  final int points;
  final int level;
  final int pointsIntoLevel;
  final int pointsForNextLevel;
  final int challengeWins;
  final int challengesPlayed;
  final int practiceRuns;
  final double averageSuccessRate;
  final int? averageCompletionDurationMs;

  const LeaderboardEntry({
    required this.rank,
    required this.playerName,
    required this.points,
    required this.level,
    required this.pointsIntoLevel,
    required this.pointsForNextLevel,
    required this.challengeWins,
    required this.challengesPlayed,
    required this.practiceRuns,
    required this.averageSuccessRate,
    required this.averageCompletionDurationMs,
  });

  double get levelProgress {
    if (pointsForNextLevel <= 0) {
      return 1;
    }
    return pointsIntoLevel / pointsForNextLevel;
  }
}

class ChallengeService {
  static final ChallengeService _instance = ChallengeService._internal();
  factory ChallengeService() => _instance;
  ChallengeService._internal();

  static const String _sessionsKey = 'challenge_sessions_v1';
  static const String _localPlayerNameKey = 'challenge_local_player_name_v1';
  static const String _defaultLocalPlayerName = 'Moi';

  final StorageService _storageService = StorageService();

  Future<String> getLocalPlayerName() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_localPlayerNameKey);
    if (value == null || value.trim().isEmpty) {
      return _defaultLocalPlayerName;
    }
    return _normalizePlayerName(value);
  }

  Future<void> setLocalPlayerName(String value) async {
    final normalized = _normalizePlayerName(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localPlayerNameKey, normalized);
  }

  Future<List<ChallengeSession>> getSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_sessionsKey) ?? [];

    final sessions = <ChallengeSession>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map<String, dynamic>) {
          sessions.add(ChallengeSession.fromJson(decoded));
        } else if (decoded is Map) {
          sessions.add(
            ChallengeSession.fromJson(Map<String, dynamic>.from(decoded)),
          );
        }
      } catch (_) {
        // Ignore corrupted entries.
      }
    }

    sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions;
  }

  Future<ChallengeSession?> getSessionById(String sessionId) async {
    final sessions = await getSessions();
    for (final session in sessions) {
      if (session.id == sessionId) {
        return session;
      }
    }
    return null;
  }

  Future<ChallengeSession> createSession({
    required Quiz quiz,
    String? sessionName,
    String? networkSessionId,
  }) async {
    final sessions = await getSessions();
    final now = DateTime.now();
    final cleanName = sessionName?.trim() ?? '';

    final session = ChallengeSession(
      id: _createId(),
      name: cleanName.isEmpty ? 'Challenge ${quiz.title}' : cleanName,
      quizId: quiz.id,
      quizTitle: quiz.title,
      questionCount: quiz.questionCount,
      networkSessionId: networkSessionId,
      createdAt: now,
      attempts: const [],
    );

    sessions.insert(0, session);
    await _saveSessions(sessions);
    return session;
  }

  Future<ChallengeSession?> getSessionByNetworkSessionId(
    String networkSessionId,
  ) async {
    final sessions = await getSessions();
    for (final session in sessions) {
      if (session.networkSessionId == networkSessionId) {
        return session;
      }
    }
    return null;
  }

  Future<ChallengeSession> createOrGetNetworkSession({
    required String networkSessionId,
    required Quiz quiz,
    String? sessionName,
  }) async {
    final existing = await getSessionByNetworkSessionId(networkSessionId);
    if (existing != null) {
      return existing;
    }

    return createSession(
      quiz: quiz,
      sessionName: sessionName,
      networkSessionId: networkSessionId,
    );
  }

  Future<ChallengeSession> linkSessionToNetworkSession({
    required String sessionId,
    required String networkSessionId,
  }) async {
    final sessions = await getSessions();
    final index = sessions.indexWhere((session) => session.id == sessionId);
    if (index < 0) {
      throw StateError('Session introuvable.');
    }
    final updated = sessions[index].copyWith(
      networkSessionId: networkSessionId,
    );
    sessions[index] = updated;
    await _saveSessions(sessions);
    return updated;
  }

  Future<void> deleteSession(String sessionId) async {
    final sessions = await getSessions();
    sessions.removeWhere((session) => session.id == sessionId);
    await _saveSessions(sessions);
  }

  Future<void> clearSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionsKey);
  }

  Future<void> addAttempt({
    required String sessionId,
    required String participantName,
    required int score,
    required int totalQuestions,
    int? completionDurationMs,
  }) async {
    if (totalQuestions <= 0) {
      throw const FormatException('totalQuestions doit etre > 0.');
    }
    if (score < 0 || score > totalQuestions) {
      throw const FormatException('Score invalide pour ce quiz.');
    }

    final normalizedName = _normalizePlayerName(participantName);
    final sessions = await getSessions();
    final index = sessions.indexWhere((session) => session.id == sessionId);
    if (index < 0) {
      throw StateError('Challenge introuvable.');
    }

    final session = sessions[index];
    final updatedAttempts = List<ChallengeAttempt>.from(session.attempts)
      ..add(
        ChallengeAttempt(
          id: _createId(),
          participantName: normalizedName,
          score: score,
          totalQuestions: totalQuestions,
          completionDurationMs: completionDurationMs,
          completedAt: DateTime.now(),
        ),
      );

    sessions[index] = session.copyWith(attempts: updatedAttempts);
    await _saveSessions(sessions);
  }

  Future<void> upsertAttemptBySessionId({
    required String sessionId,
    required String participantName,
    required int score,
    required int totalQuestions,
    int? completionDurationMs,
    DateTime? completedAt,
  }) async {
    if (totalQuestions <= 0) {
      throw const FormatException('totalQuestions doit etre > 0.');
    }
    if (score < 0 || score > totalQuestions) {
      throw const FormatException('Score invalide pour ce quiz.');
    }

    final normalizedName = _normalizePlayerName(participantName);
    final sessions = await getSessions();
    final index = sessions.indexWhere((session) => session.id == sessionId);
    if (index < 0) {
      throw StateError('Challenge introuvable.');
    }

    final incoming = ChallengeAttempt(
      id: _createId(),
      participantName: normalizedName,
      score: score,
      totalQuestions: totalQuestions,
      completionDurationMs: completionDurationMs,
      completedAt: completedAt ?? DateTime.now(),
    );

    sessions[index] = _upsertAttemptInSession(sessions[index], incoming);
    await _saveSessions(sessions);
  }

  Future<void> upsertAttemptByNetworkSessionId({
    required String networkSessionId,
    required String participantName,
    required int score,
    required int totalQuestions,
    int? completionDurationMs,
    DateTime? completedAt,
  }) async {
    final sessions = await getSessions();
    final index = sessions.indexWhere(
      (session) => session.networkSessionId == networkSessionId,
    );
    if (index < 0) {
      return;
    }

    final incoming = ChallengeAttempt(
      id: _createId(),
      participantName: _normalizePlayerName(participantName),
      score: score,
      totalQuestions: totalQuestions,
      completionDurationMs: completionDurationMs,
      completedAt: completedAt ?? DateTime.now(),
    );

    sessions[index] = _upsertAttemptInSession(sessions[index], incoming);
    await _saveSessions(sessions);
  }

  List<ChallengeAttempt> rankAttempts(ChallengeSession session) {
    final bestByPlayer = <String, ChallengeAttempt>{};

    for (final attempt in session.attempts) {
      final key = _playerKey(attempt.participantName);
      final existing = bestByPlayer[key];
      if (existing == null || _isBetterAttempt(attempt, existing)) {
        bestByPlayer[key] = attempt;
      }
    }

    final ranked = bestByPlayer.values.toList()
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) {
          return byScore;
        }
        final byDuration = _compareDurationAsc(
          a.completionDurationMs,
          b.completionDurationMs,
        );
        if (byDuration != 0) {
          return byDuration;
        }
        final byRate = b.successRate.compareTo(a.successRate);
        if (byRate != 0) {
          return byRate;
        }
        return a.completedAt.compareTo(b.completedAt);
      });

    return ranked;
  }

  Future<List<LeaderboardEntry>> getLeaderboard() async {
    final localPlayerName = await getLocalPlayerName();
    final sessions = await getSessions();

    final statsByPlayer = <String, _PlayerStats>{};
    _PlayerStats statsFor(String playerName) {
      final key = _playerKey(playerName);
      return statsByPlayer.putIfAbsent(
        key,
        () => _PlayerStats(playerName: playerName),
      );
    }

    for (final session in sessions) {
      final ranked = rankAttempts(session);
      for (int i = 0; i < ranked.length; i++) {
        final attempt = ranked[i];
        final stats = statsFor(attempt.participantName);
        stats.playerName = attempt.participantName;
        stats.challengesPlayed += 1;
        stats.successRateSum += attempt.successRate;
        stats.successRateCount += 1;
        if (attempt.completionDurationMs != null &&
            attempt.completionDurationMs! > 0) {
          stats.durationSumMs += attempt.completionDurationMs!;
          stats.durationCount += 1;
        }

        final basePoints = 30 + (attempt.successRate * 70).round();
        final bonus = i == 0
            ? 30
            : i == 1
            ? 20
            : i == 2
            ? 10
            : 0;
        stats.points += basePoints + bonus;
        if (i == 0) {
          stats.challengeWins += 1;
        }
      }
    }

    final localStats = statsFor(localPlayerName);
    final quizzes = await _storageService.getQuizzes();
    for (final quiz in quizzes) {
      final score = quiz.score;
      if (score == null || quiz.questionCount <= 0) {
        continue;
      }

      final rate = (score / quiz.questionCount).clamp(0, 1).toDouble();
      localStats.practiceRuns += 1;
      localStats.successRateSum += rate;
      localStats.successRateCount += 1;
      localStats.points += 10 + (rate * 40).round();
    }

    final sorted = statsByPlayer.values.toList()
      ..sort((a, b) {
        final byPoints = b.points.compareTo(a.points);
        if (byPoints != 0) {
          return byPoints;
        }
        final byWins = b.challengeWins.compareTo(a.challengeWins);
        if (byWins != 0) {
          return byWins;
        }
        final byRate = b.averageSuccessRate.compareTo(a.averageSuccessRate);
        if (byRate != 0) {
          return byRate;
        }
        final byDuration = _compareDurationAsc(
          a.averageCompletionDurationMs,
          b.averageCompletionDurationMs,
        );
        if (byDuration != 0) {
          return byDuration;
        }
        return a.playerName.toLowerCase().compareTo(b.playerName.toLowerCase());
      });

    final leaderboard = <LeaderboardEntry>[];
    for (int index = 0; index < sorted.length; index++) {
      final item = sorted[index];
      final level = _computeLevel(item.points);
      leaderboard.add(
        LeaderboardEntry(
          rank: index + 1,
          playerName: item.playerName,
          points: item.points,
          level: level.level,
          pointsIntoLevel: level.pointsIntoLevel,
          pointsForNextLevel: level.pointsForNextLevel,
          challengeWins: item.challengeWins,
          challengesPlayed: item.challengesPlayed,
          practiceRuns: item.practiceRuns,
          averageSuccessRate: item.averageSuccessRate,
          averageCompletionDurationMs: item.averageCompletionDurationMs,
        ),
      );
    }

    return leaderboard;
  }

  Future<void> _saveSessions(List<ChallengeSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = sessions
        .map((session) => jsonEncode(session.toJson()))
        .toList();
    await prefs.setStringList(_sessionsKey, encoded);
  }

  bool _isBetterAttempt(ChallengeAttempt candidate, ChallengeAttempt current) {
    if (candidate.score != current.score) {
      return candidate.score > current.score;
    }
    final byDuration = _compareDurationAsc(
      candidate.completionDurationMs,
      current.completionDurationMs,
    );
    if (byDuration != 0) {
      return byDuration < 0;
    }
    if (candidate.successRate != current.successRate) {
      return candidate.successRate > current.successRate;
    }
    return candidate.completedAt.isBefore(current.completedAt);
  }

  ChallengeSession _upsertAttemptInSession(
    ChallengeSession session,
    ChallengeAttempt incoming,
  ) {
    final updatedAttempts = List<ChallengeAttempt>.from(session.attempts);
    final incomingKey = _playerKey(incoming.participantName);
    final index = updatedAttempts.indexWhere(
      (item) => _playerKey(item.participantName) == incomingKey,
    );

    if (index < 0) {
      updatedAttempts.add(incoming);
      return session.copyWith(attempts: updatedAttempts);
    }

    final existing = updatedAttempts[index];
    if (_isBetterAttempt(incoming, existing)) {
      updatedAttempts[index] = incoming;
    }
    return session.copyWith(attempts: updatedAttempts);
  }

  int _compareDurationAsc(int? a, int? b) {
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return 1;
    }
    if (b == null) {
      return -1;
    }
    return a.compareTo(b);
  }

  String _normalizePlayerName(String name) {
    final cleaned = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) {
      return _defaultLocalPlayerName;
    }
    if (cleaned.length == 1) {
      return cleaned.toUpperCase();
    }
    return '${cleaned[0].toUpperCase()}${cleaned.substring(1)}';
  }

  String _playerKey(String name) => name.trim().toLowerCase();

  String _createId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'ch_$now';
  }

  _LevelData _computeLevel(int points) {
    int level = 1;
    int remaining = points;
    int threshold = 120;

    while (remaining >= threshold) {
      remaining -= threshold;
      level += 1;
      threshold = (threshold * 1.18).round();
    }

    return _LevelData(
      level: level,
      pointsIntoLevel: remaining,
      pointsForNextLevel: threshold,
    );
  }
}

class _PlayerStats {
  String playerName;
  int points = 0;
  int challengeWins = 0;
  int challengesPlayed = 0;
  int practiceRuns = 0;
  double successRateSum = 0;
  int successRateCount = 0;
  int durationSumMs = 0;
  int durationCount = 0;

  _PlayerStats({required this.playerName});

  double get averageSuccessRate {
    if (successRateCount == 0) {
      return 0;
    }
    return successRateSum / successRateCount;
  }

  int? get averageCompletionDurationMs {
    if (durationCount == 0) {
      return null;
    }
    return (durationSumMs / durationCount).round();
  }
}

class _LevelData {
  final int level;
  final int pointsIntoLevel;
  final int pointsForNextLevel;

  const _LevelData({
    required this.level,
    required this.pointsIntoLevel,
    required this.pointsForNextLevel,
  });
}
