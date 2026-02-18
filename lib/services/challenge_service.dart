import 'dart:convert';

import 'package:atao_quiz/services/storage_service.dart';
import 'package:atao_quiz/services/user_profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChallengeMode {
  static const String friends = 'friends';
  static const String timed = 'timed';
}

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
  final String mode;
  final int? timeLimitSeconds;
  final String? networkSessionId;
  final DateTime createdAt;
  final List<ChallengeAttempt> attempts;

  const ChallengeSession({
    required this.id,
    required this.name,
    required this.quizId,
    required this.quizTitle,
    required this.questionCount,
    required this.mode,
    this.timeLimitSeconds,
    this.networkSessionId,
    required this.createdAt,
    required this.attempts,
  });

  bool get isTimed =>
      mode == ChallengeMode.timed && (timeLimitSeconds ?? 0) > 0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quizId': quizId,
      'quizTitle': quizTitle,
      'questionCount': questionCount,
      'mode': mode,
      'timeLimitSeconds': timeLimitSeconds,
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

    final parsedTimeLimit = _normalizeTimeLimitSeconds(
      int.tryParse('${json['timeLimitSeconds']}'),
    );
    final normalizedMode = _normalizeChallengeMode(
      json['mode']?.toString(),
      timeLimitSeconds: parsedTimeLimit,
    );

    return ChallengeSession(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Challenge',
      quizId: json['quizId']?.toString() ?? '',
      quizTitle: json['quizTitle']?.toString() ?? 'Quiz',
      questionCount: int.tryParse('${json['questionCount']}') ?? 0,
      mode: normalizedMode,
      timeLimitSeconds: normalizedMode == ChallengeMode.timed
          ? parsedTimeLimit
          : null,
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
    String? mode,
    int? timeLimitSeconds,
    String? networkSessionId,
    DateTime? createdAt,
    List<ChallengeAttempt>? attempts,
  }) {
    final normalizedTimeLimit = timeLimitSeconds == null
        ? this.timeLimitSeconds
        : _normalizeTimeLimitSeconds(timeLimitSeconds);
    final normalizedMode = _normalizeChallengeMode(
      mode ?? this.mode,
      timeLimitSeconds: normalizedTimeLimit,
    );

    return ChallengeSession(
      id: id ?? this.id,
      name: name ?? this.name,
      quizId: quizId ?? this.quizId,
      quizTitle: quizTitle ?? this.quizTitle,
      questionCount: questionCount ?? this.questionCount,
      mode: normalizedMode,
      timeLimitSeconds: normalizedMode == ChallengeMode.timed
          ? normalizedTimeLimit
          : null,
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
  final int timedChallengeWins;
  final int challengesPlayed;
  final int timedChallengesPlayed;
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
    required this.timedChallengeWins,
    required this.challengesPlayed,
    required this.timedChallengesPlayed,
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
  static const String _defaultLocalPlayerName = 'Moi';

  final StorageService _storageService = StorageService();
  final UserProfileService _profileService = UserProfileService();

  Future<String> getLocalPlayerName() async {
    return _profileService.getDisplayName();
  }

  Future<void> setLocalPlayerName(String value) async {
    final profile = await _profileService.getProfile();
    await _profileService.saveProfile(
      displayName: value,
      avatarIndex: profile.avatarIndex,
      markConfigured: profile.isConfigured,
    );
  }

  Future<void> renamePlayerInAllSessions({
    required String oldName,
    required String newName,
  }) async {
    final oldKey = _playerKey(oldName);
    final normalizedNewName = _normalizePlayerName(newName);
    final newKey = _playerKey(normalizedNewName);
    if (oldKey.isEmpty || newKey.isEmpty || oldKey == newKey) {
      return;
    }

    final sessions = await getSessions();
    bool hasChanges = false;
    final updatedSessions = sessions.map((session) {
      bool sessionChanged = false;
      final updatedAttempts = session.attempts.map((attempt) {
        if (_playerKey(attempt.participantName) != oldKey) {
          return attempt;
        }
        hasChanges = true;
        sessionChanged = true;
        return attempt.copyWith(participantName: normalizedNewName);
      }).toList();
      return sessionChanged
          ? session.copyWith(attempts: updatedAttempts)
          : session;
    }).toList();

    if (hasChanges) {
      await _saveSessions(updatedSessions);
    }
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
    String mode = ChallengeMode.friends,
    int? timeLimitSeconds,
  }) async {
    final sessions = await getSessions();
    final now = DateTime.now();
    final cleanName = sessionName?.trim() ?? '';
    final normalizedTimeLimit = _normalizeTimeLimitSeconds(timeLimitSeconds);
    final normalizedMode = _normalizeChallengeMode(
      mode,
      timeLimitSeconds: normalizedTimeLimit,
    );
    if (normalizedMode == ChallengeMode.timed && normalizedTimeLimit == null) {
      throw const FormatException(
        'La durée du challenge chronométré est invalide.',
      );
    }

    final session = ChallengeSession(
      id: _createId(),
      name: cleanName.isEmpty ? 'Challenge ${quiz.title}' : cleanName,
      quizId: quiz.id,
      quizTitle: quiz.title,
      questionCount: quiz.questionCount,
      mode: normalizedMode,
      timeLimitSeconds: normalizedMode == ChallengeMode.timed
          ? normalizedTimeLimit
          : null,
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
    String mode = ChallengeMode.friends,
    int? timeLimitSeconds,
  }) async {
    final normalizedTimeLimit = _normalizeTimeLimitSeconds(timeLimitSeconds);
    final normalizedMode = _normalizeChallengeMode(
      mode,
      timeLimitSeconds: normalizedTimeLimit,
    );

    final existing = await getSessionByNetworkSessionId(networkSessionId);
    if (existing != null) {
      if (existing.mode == normalizedMode &&
          existing.timeLimitSeconds == normalizedTimeLimit) {
        return existing;
      }

      final sessions = await getSessions();
      final index = sessions.indexWhere((session) => session.id == existing.id);
      if (index < 0) {
        return existing;
      }

      final updated = sessions[index].copyWith(
        mode: normalizedMode,
        timeLimitSeconds: normalizedMode == ChallengeMode.timed
            ? normalizedTimeLimit
            : null,
      );
      sessions[index] = updated;
      await _saveSessions(sessions);
      return updated;
    }

    if (normalizedMode == ChallengeMode.timed && normalizedTimeLimit == null) {
      throw const FormatException(
        'La durée du challenge chronométré est invalide.',
      );
    }

    return createSession(
      quiz: quiz,
      sessionName: sessionName,
      networkSessionId: networkSessionId,
      mode: normalizedMode,
      timeLimitSeconds: normalizedTimeLimit,
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
      final isTimedSession = session.isTimed;
      final ranked = rankAttempts(session);
      for (int i = 0; i < ranked.length; i++) {
        final attempt = ranked[i];
        final stats = statsFor(attempt.participantName);
        stats.playerName = attempt.participantName;
        stats.challengesPlayed += 1;
        if (isTimedSession) {
          stats.timedChallengesPlayed += 1;
        }
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
        int timedBonus = 0;
        if (isTimedSession) {
          timedBonus += 15;
          final limitSeconds = session.timeLimitSeconds;
          if (limitSeconds != null && limitSeconds > 0) {
            final limitMs = limitSeconds * 1000;
            final durationMs = attempt.completionDurationMs ?? limitMs;
            final clippedDuration = durationMs < 0
                ? 0
                : durationMs > limitMs
                ? limitMs
                : durationMs;
            final speedRatio = 1 - (clippedDuration / limitMs);
            timedBonus += (speedRatio * 10).round();
          }
        }

        stats.points += basePoints + bonus + timedBonus;
        if (i == 0) {
          stats.challengeWins += 1;
          if (isTimedSession) {
            stats.timedChallengeWins += 1;
          }
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
        final byTimedWins = b.timedChallengeWins.compareTo(
          a.timedChallengeWins,
        );
        if (byTimedWins != 0) {
          return byTimedWins;
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
          timedChallengeWins: item.timedChallengeWins,
          challengesPlayed: item.challengesPlayed,
          timedChallengesPlayed: item.timedChallengesPlayed,
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
    final normalized = UserProfileService.normalizeDisplayName(name);
    if (normalized.trim().isEmpty) {
      return _defaultLocalPlayerName;
    }
    return normalized;
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
  int timedChallengeWins = 0;
  int challengesPlayed = 0;
  int timedChallengesPlayed = 0;
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

String _normalizeChallengeMode(String? mode, {int? timeLimitSeconds}) {
  if (mode == ChallengeMode.timed && (timeLimitSeconds ?? 0) > 0) {
    return ChallengeMode.timed;
  }
  return ChallengeMode.friends;
}

int? _normalizeTimeLimitSeconds(int? value) {
  if (value == null || value <= 0) {
    return null;
  }
  return value;
}
