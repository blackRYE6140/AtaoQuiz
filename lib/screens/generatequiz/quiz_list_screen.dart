import 'package:atao_quiz/screens/generatequiz/generate_quiz_screen.dart';
import 'package:atao_quiz/screens/generatequiz/play_quiz_screen.dart';
import 'package:atao_quiz/screens/challenge/challenge_detail_screen.dart';
import 'package:atao_quiz/services/challenge_service.dart';
import 'package:flutter/material.dart';
import 'package:atao_quiz/services/storage_service.dart';
import 'package:atao_quiz/theme/colors.dart';

class QuizListScreen extends StatefulWidget {
  const QuizListScreen({super.key});

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _NoLineScrollBehavior extends MaterialScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _QuizListScreenState extends State<QuizListScreen> {
  final StorageService _storageService = StorageService();
  final ChallengeService _challengeService = ChallengeService();

  List<Quiz> _generatedQuizzes = [];
  List<Quiz> _transferredQuizzes = [];
  List<ChallengeSession> _friendChallenges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final quizzes = await _storageService.getQuizzes();
      final sessions = await _challengeService.getSessions();

      final generated = quizzes.where((quiz) => !quiz.isTransferred).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final transferred = quizzes.where((quiz) => quiz.isTransferred).toList()
        ..sort(
          (a, b) => (b.receivedAt ?? b.createdAt).compareTo(
            a.receivedAt ?? a.createdAt,
          ),
        );
      final friendChallenges =
          sessions
              .where((session) => session.mode == ChallengeMode.friends)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) {
        return;
      }
      setState(() {
        _generatedQuizzes = generated;
        _transferredQuizzes = transferred;
        _friendChallenges = friendChallenges;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteQuiz(String quizId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le quiz'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce quiz ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storageService.deleteQuiz(quizId);
      await _loadData();
    }
  }

  void _playQuiz(Quiz quiz) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PlayQuizScreen(quiz: quiz)),
    ).then((_) => _loadData());
  }

  void _openCreateQuiz() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GenerateQuizScreen()),
    ).then((_) => _loadData());
  }

  void _openFriendChallenge(ChallengeSession session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChallengeDetailScreen(sessionId: session.id),
      ),
    ).then((_) => _loadData());
  }

  BoxDecoration _cardDecoration(bool isDark) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  String _formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    return '$day/$month/$year';
  }

  Color _scoreColor(Quiz quiz, Color secondaryTextColor) {
    if (quiz.score == null) {
      return secondaryTextColor;
    }
    if (quiz.score! >= quiz.questionCount * 0.7) {
      return Colors.green;
    }
    if (quiz.score! >= quiz.questionCount * 0.5) {
      return Colors.orange;
    }
    return Colors.red;
  }

  TextStyle _listTitleStyle({
    required bool isDark,
    required Color primaryColor,
  }) {
    return TextStyle(
      fontFamily: 'Poppins',
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: primaryColor,
      shadows: [
        Shadow(
          color: (isDark ? Colors.black : Colors.black87).withValues(
            alpha: isDark ? 0.36 : 0.18,
          ),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildQuizList({
    required BuildContext context,
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color secondaryTextColor,
    required List<Quiz> quizzes,
    required String title,
    required String emptyMessage,
    required IconData emptyIcon,
    required bool transferredTab,
  }) {
    if (quizzes.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              title,
              style: _listTitleStyle(
                isDark: isDark,
                primaryColor: primaryColor,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(isDark),
            child: Column(
              children: [
                Icon(
                  emptyIcon,
                  size: 44,
                  color: primaryColor.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 8),
                Text(
                  emptyMessage,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            '$title (${quizzes.length})',
            style: _listTitleStyle(isDark: isDark, primaryColor: primaryColor),
          ),
        ),
        ...quizzes.map((quiz) {
          final scoreColor = _scoreColor(quiz, secondaryTextColor);
          final dateLabel = transferredTab
              ? _formatDate(quiz.receivedAt ?? quiz.createdAt)
              : _formatDate(quiz.createdAt);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: _cardDecoration(isDark),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              leading: CircleAvatar(
                backgroundColor: _getDifficultyColor(quiz.difficulty),
                child: Icon(
                  quiz.isTransferred ? Icons.download_done : Icons.quiz,
                  color: Colors.black,
                ),
              ),
              title: Text(
                quiz.title,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '${quiz.questionCount} questions • ${quiz.difficulty} • ${quiz.pdfFileName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${transferredTab ? 'Reçu le' : 'Créé le'} $dateLabel'
                    '${quiz.isTransferred ? ' • Transféré via Wi‑Fi' : ''}',
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                  if (quiz.score != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          Icon(Icons.score, size: 14, color: scoreColor),
                          const SizedBox(width: 4),
                          Text(
                            'Score: ${quiz.score}/${quiz.questionCount}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: scoreColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 72),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (quiz.score == null)
                      IconButton(
                        icon: Icon(Icons.play_arrow, color: primaryColor),
                        onPressed: () => _playQuiz(quiz),
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: primaryColor.withValues(alpha: 0.75),
                      ),
                      onPressed: () => _deleteQuiz(quiz.id),
                    ),
                  ],
                ),
              ),
              onTap: () => _playQuiz(quiz),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFriendChallengesList({
    required BuildContext context,
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    if (_friendChallenges.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Défis amis',
              style: _listTitleStyle(
                isDark: isDark,
                primaryColor: primaryColor,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(isDark),
            child: Column(
              children: [
                Icon(
                  Icons.groups_2_outlined,
                  size: 44,
                  color: primaryColor.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aucun défi entre amis pour le moment.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Défis amis (${_friendChallenges.length})',
            style: _listTitleStyle(isDark: isDark, primaryColor: primaryColor),
          ),
        ),
        ..._friendChallenges.map((session) {
          final ranked = _challengeService.rankAttempts(session);
          final leader = ranked.isNotEmpty ? ranked.first : null;
          final participants = ranked.length;
          final isNetwork = session.networkSessionId != null;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: _cardDecoration(isDark),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              leading: CircleAvatar(
                backgroundColor: primaryColor.withValues(alpha: 0.18),
                child: Icon(Icons.groups, color: primaryColor),
              ),
              title: Text(
                session.name,
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${isNetwork ? 'Réseau Wi‑Fi' : 'Local'} • ${session.quizTitle}\n'
                '${session.questionCount} questions • '
                '${leader == null ? 'Aucun score' : 'Leader: ${leader.participantName} (${leader.score}/${leader.totalQuestions})'}\n'
                '$participants participant(s) • ${_formatDate(session.createdAt)}',
                style: TextStyle(color: secondaryTextColor, fontSize: 12),
              ),
              isThreeLine: true,
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: primaryColor,
              ),
              onTap: () => _openFriendChallenge(session),
            ),
          );
        }),
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

    return ScrollConfiguration(
      behavior: _NoLineScrollBehavior(),
      child: DefaultTabController(
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
            centerTitle: true,
            iconTheme: IconThemeData(color: primaryColor),
            title: Text(
              'Mes Quiz',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
            ],
            bottom: TabBar(
              isScrollable: false,
              indicatorColor: primaryColor,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: primaryColor,
              unselectedLabelColor: secondaryTextColor,
              labelStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    color: Colors.black12,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              tabs: const [
                Tab(text: 'Quiz générés'),
                Tab(text: 'Transférés Wi‑Fi'),
                Tab(text: 'Défis amis'),
              ],
            ),
          ),
          body: _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : TabBarView(
                  children: [
                    RefreshIndicator(
                      onRefresh: _loadData,
                      color: primaryColor,
                      child: _buildQuizList(
                        context: context,
                        isDark: isDark,
                        primaryColor: primaryColor,
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor,
                        quizzes: _generatedQuizzes,
                        title: 'Quiz générés',
                        emptyMessage: 'Aucun quiz généré pour le moment.',
                        emptyIcon: Icons.quiz_outlined,
                        transferredTab: false,
                      ),
                    ),
                    RefreshIndicator(
                      onRefresh: _loadData,
                      color: primaryColor,
                      child: _buildQuizList(
                        context: context,
                        isDark: isDark,
                        primaryColor: primaryColor,
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor,
                        quizzes: _transferredQuizzes,
                        title: 'Quiz transférés',
                        emptyMessage: 'Aucun quiz transféré via Wi‑Fi.',
                        emptyIcon: Icons.wifi_tethering,
                        transferredTab: true,
                      ),
                    ),
                    RefreshIndicator(
                      onRefresh: _loadData,
                      color: primaryColor,
                      child: _buildFriendChallengesList(
                        context: context,
                        isDark: isDark,
                        primaryColor: primaryColor,
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openCreateQuiz,
            backgroundColor: primaryColor,
            foregroundColor: isDark ? Colors.black : Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Créer un quiz'),
          ),
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'facile':
        return Colors.green.shade300;
      case 'difficile':
        return Colors.red.shade300;
      default:
        return Colors.blue.shade300;
    }
  }
}
