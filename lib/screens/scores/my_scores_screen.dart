import 'package:atao_quiz/components/profile_avatar.dart';
import 'package:atao_quiz/services/challenge_service.dart';
import 'package:atao_quiz/services/storage_service.dart';
import 'package:atao_quiz/services/user_profile_service.dart';
import 'package:atao_quiz/theme/colors.dart';
import 'package:flutter/material.dart';

class MyScoresScreen extends StatefulWidget {
  const MyScoresScreen({super.key});

  @override
  State<MyScoresScreen> createState() => _MyScoresScreenState();
}

class _MyScoresScreenState extends State<MyScoresScreen> {
  final ChallengeService _challengeService = ChallengeService();
  final StorageService _storageService = StorageService();
  final UserProfileService _profileService = UserProfileService();

  UserProfile _profile = const UserProfile(
    displayName: UserProfileService.defaultDisplayName,
    avatarIndex: 0,
    isConfigured: false,
  );
  bool _isLoading = true;
  List<_QuizHistoryEntry> _quizHistory = [];
  List<_ChallengeHistoryEntry> _friendsHistory = [];
  List<_ChallengeHistoryEntry> _timedHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _profileService.getProfile();
      final quizzes = await _storageService.getQuizzes();
      final sessions = await _challengeService.getSessions();
      final profileKey = profile.displayName.trim().toLowerCase();

      final quizHistory =
          quizzes
              .where((quiz) => quiz.score != null && quiz.questionCount > 0)
              .map(
                (quiz) => _QuizHistoryEntry(
                  quizTitle: quiz.title,
                  score: quiz.score!,
                  totalQuestions: quiz.questionCount,
                  playedAt: quiz.playedAt ?? quiz.createdAt,
                ),
              )
              .toList()
            ..sort((a, b) => b.playedAt.compareTo(a.playedAt));

      final friendsHistory = <_ChallengeHistoryEntry>[];
      final timedHistory = <_ChallengeHistoryEntry>[];

      for (final session in sessions) {
        for (final attempt in session.attempts) {
          final participantKey = attempt.participantName.trim().toLowerCase();
          if (participantKey != profileKey) {
            continue;
          }
          final entry = _ChallengeHistoryEntry(
            sessionName: session.name,
            quizTitle: session.quizTitle,
            score: attempt.score,
            totalQuestions: attempt.totalQuestions,
            completionDurationMs: attempt.completionDurationMs,
            completedAt: attempt.completedAt,
            isTimed: session.isTimed,
            timeLimitSeconds: session.timeLimitSeconds,
            isNetwork: session.networkSessionId != null,
          );
          if (session.isTimed) {
            timedHistory.add(entry);
          } else {
            friendsHistory.add(entry);
          }
        }
      }

      friendsHistory.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      timedHistory.sort((a, b) => b.completedAt.compareTo(a.completedAt));

      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _quizHistory = quizHistory;
        _friendsHistory = friendsHistory;
        _timedHistory = timedHistory;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String _formatDuration(int? durationMs) {
    if (durationMs == null || durationMs <= 0) {
      return '--';
    }
    final minutes = durationMs ~/ 60000;
    final seconds = (durationMs % 60000) ~/ 1000;
    final centiseconds = (durationMs % 1000) ~/ 10;
    if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '$seconds.${centiseconds.toString().padLeft(2, '0')}s';
  }

  String _formatDurationFromSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) {
      return '$minutes min';
    }
    return '${minutes}m ${remainingSeconds}s';
  }

  BoxDecoration _cardDecoration(bool isDark, Color primaryColor) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      border: Border.all(color: primaryColor.withValues(alpha: 0.30)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppColors.accentYellow
        : AppColors.primaryBlue;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final secondaryTextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: primaryColor),
          title: Text(
            'Mes Scores',
            style: TextStyle(
              color: primaryColor,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
          bottom: TabBar(
            indicatorColor: primaryColor,
            dividerColor: Colors.transparent,
            labelColor: primaryColor,
            unselectedLabelColor: secondaryTextColor,
            tabs: const [
              Tab(text: 'Quiz'),
              Tab(text: 'Défis amis'),
              Tab(text: 'Défis chrono'),
            ],
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: primaryColor))
            : RefreshIndicator(
                onRefresh: _loadHistory,
                color: primaryColor,
                child: TabBarView(
                  children: [
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: _cardDecoration(isDark, primaryColor),
                          child: Row(
                            children: [
                              ProfileAvatar(
                                avatarIndex: _profile.avatarIndex,
                                imageBase64: _profile.profileImageBase64,
                                radius: 18,
                                accentColor: primaryColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${_profile.displayName} • ${_quizHistory.length} quiz résolu(s)',
                                  style: TextStyle(
                                    color: textColor,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_quizHistory.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: _cardDecoration(isDark, primaryColor),
                            child: Text(
                              'Aucun historique de quiz pour le moment.',
                              style: TextStyle(color: secondaryTextColor),
                            ),
                          )
                        else
                          ..._quizHistory.map((entry) {
                            final percent =
                                (entry.score / entry.totalQuestions * 100)
                                    .toStringAsFixed(0);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: _cardDecoration(isDark, primaryColor),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: primaryColor.withValues(
                                    alpha: 0.18,
                                  ),
                                  child: Icon(
                                    Icons.quiz_outlined,
                                    color: primaryColor,
                                  ),
                                ),
                                title: Text(
                                  entry.quizTitle,
                                  style: TextStyle(
                                    color: textColor,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${entry.score}/${entry.totalQuestions} • $percent%\n${_formatDate(entry.playedAt)}',
                                  style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                                isThreeLine: true,
                              ),
                            );
                          }),
                      ],
                    ),
                    _buildChallengeHistoryTab(
                      context: context,
                      entries: _friendsHistory,
                      emptyMessage: 'Aucun historique de défi entre amis.',
                      primaryColor: primaryColor,
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                      isDark: isDark,
                    ),
                    _buildChallengeHistoryTab(
                      context: context,
                      entries: _timedHistory,
                      emptyMessage: 'Aucun historique de défi chrono.',
                      primaryColor: primaryColor,
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildChallengeHistoryTab({
    required BuildContext context,
    required List<_ChallengeHistoryEntry> entries,
    required String emptyMessage,
    required Color primaryColor,
    required Color textColor,
    required Color secondaryTextColor,
    required bool isDark,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardDecoration(isDark, primaryColor),
            child: Text(
              emptyMessage,
              style: TextStyle(color: secondaryTextColor),
            ),
          )
        else
          ...entries.map((entry) {
            final percent = (entry.score / entry.totalQuestions * 100)
                .toStringAsFixed(0);
            final modeDetails =
                entry.isTimed && (entry.timeLimitSeconds ?? 0) > 0
                ? 'Chrono ${_formatDurationFromSeconds(entry.timeLimitSeconds!)}'
                : 'Défi entre amis';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: _cardDecoration(isDark, primaryColor),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: primaryColor.withValues(alpha: 0.18),
                  child: Icon(
                    entry.isTimed ? Icons.timer_outlined : Icons.groups,
                    color: primaryColor,
                  ),
                ),
                title: Text(
                  entry.sessionName,
                  style: TextStyle(
                    color: textColor,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '$modeDetails • ${entry.isNetwork ? 'Réseau' : 'Local'}\n'
                  '${entry.score}/${entry.totalQuestions} • $percent% • Temps: ${_formatDuration(entry.completionDurationMs)}\n'
                  '${entry.quizTitle} • ${_formatDate(entry.completedAt)}',
                  style: TextStyle(color: secondaryTextColor, fontSize: 12),
                ),
                isThreeLine: true,
              ),
            );
          }),
      ],
    );
  }
}

class _QuizHistoryEntry {
  final String quizTitle;
  final int score;
  final int totalQuestions;
  final DateTime playedAt;

  const _QuizHistoryEntry({
    required this.quizTitle,
    required this.score,
    required this.totalQuestions,
    required this.playedAt,
  });
}

class _ChallengeHistoryEntry {
  final String sessionName;
  final String quizTitle;
  final int score;
  final int totalQuestions;
  final int? completionDurationMs;
  final DateTime completedAt;
  final bool isTimed;
  final int? timeLimitSeconds;
  final bool isNetwork;

  const _ChallengeHistoryEntry({
    required this.sessionName,
    required this.quizTitle,
    required this.score,
    required this.totalQuestions,
    required this.completionDurationMs,
    required this.completedAt,
    required this.isTimed,
    required this.timeLimitSeconds,
    required this.isNetwork,
  });
}
