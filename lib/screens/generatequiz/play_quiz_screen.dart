import 'package:atao_quiz/services/storage_service.dart';
import 'package:atao_quiz/theme/colors.dart';
import 'package:flutter/material.dart';

class PlayQuizScreen extends StatefulWidget {
  final Quiz quiz;

  const PlayQuizScreen({super.key, required this.quiz});

  @override
  State<PlayQuizScreen> createState() => _PlayQuizScreenState();
}

class _PlayQuizScreenState extends State<PlayQuizScreen> {
  late final List<Question> _questions;
  late final List<int?> _selectedAnswers;

  int _currentQuestionIndex = 0;
  bool _quizCompleted = false;
  bool _selectionLocked = false;
  bool _resultSaved = false;
  bool _isSavingResult = false;

  int get _totalQuestions => _questions.length;

  int get _answeredCount => _selectedAnswers.whereType<int>().length;

  int get _score {
    int value = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] == _questions[i].correctIndex) {
        value++;
      }
    }
    return value;
  }

  double get _scorePercent {
    if (_totalQuestions == 0) {
      return 0;
    }
    return _score / _totalQuestions;
  }

  @override
  void initState() {
    super.initState();

    // On travaille sur une copie des questions pour éviter les effets de bord
    // quand le quiz est rejoué avec le même objet.
    _questions = widget.quiz.questions
        .map(
          (question) => Question(
            text: question.text,
            options: List<String>.from(question.options),
            correctIndex: question.correctIndex,
          ),
        )
        .toList();

    _selectedAnswers = List<int?>.filled(_questions.length, null);
  }

  Future<void> _selectAnswer(int optionIndex) async {
    if (_quizCompleted || _selectionLocked) {
      return;
    }

    // Sécurité: une question déjà répondue ne peut plus être modifiée.
    if (_selectedAnswers[_currentQuestionIndex] != null) {
      return;
    }

    setState(() {
      _selectionLocked = true;
      _selectedAnswers[_currentQuestionIndex] = optionIndex;
    });

    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) {
      return;
    }

    final bool isLastQuestion = _currentQuestionIndex >= _totalQuestions - 1;

    if (isLastQuestion) {
      setState(() {
        _quizCompleted = true;
        _selectionLocked = false;
      });
      await _saveQuizResult();
      return;
    }

    setState(() {
      _currentQuestionIndex++;
      _selectionLocked = false;
    });
  }

  Future<void> _saveQuizResult() async {
    if (_resultSaved || _isSavingResult) {
      return;
    }

    setState(() {
      _isSavingResult = true;
    });

    try {
      await StorageService().saveQuizResult(widget.quiz.id, _score);
      _resultSaved = true;
    } finally {
      if (mounted) {
        setState(() {
          _isSavingResult = false;
        });
      }
    }
  }

  void _goToQuestion(int index) {
    if (_selectionLocked) {
      return;
    }

    if (index < 0 || index >= _totalQuestions) {
      return;
    }

    setState(() {
      _currentQuestionIndex = index;
    });
  }

  void _restartQuiz() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PlayQuizScreen(quiz: widget.quiz),
      ),
    );
  }

  void _goHome() {
    Navigator.popUntil(context, ModalRoute.withName('/home'));
  }

  void _onQuestionBadgeTap(int index) {
    if (_quizCompleted) {
      _showAnswerDetail(index);
      return;
    }

    _goToQuestion(index);
  }

  void _showAnswerDetail(int index) {
    final question = _questions[index];
    final selectedIndex = _selectedAnswers[index];
    final correctIndex = question.correctIndex;
    final isCorrect = selectedIndex == correctIndex;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final secondaryTextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 720),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : AppColors.primaryBlue.withValues(alpha: 0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Question ${index + 1}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question.text,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAnswerInfoTile(
                    label: 'Votre réponse',
                    value: _answerLabel(question, selectedIndex),
                    color: selectedIndex == null
                        ? AppColors.warning
                        : isCorrect
                        ? AppColors.success
                        : AppColors.error,
                    icon: selectedIndex == null
                        ? Icons.help_outline
                        : Icons.person_outline,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildAnswerInfoTile(
                    label: 'Bonne réponse',
                    value: _answerLabel(question, correctIndex),
                    color: AppColors.success,
                    icon: Icons.check_circle_outline,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isCorrect ? 'Bonne réponse.' : 'Réponse incorrecte.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: isCorrect ? AppColors.success : AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Touchez un autre numéro pour voir la correction d\'une autre question.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _answerLabel(Question question, int? optionIndex) {
    if (optionIndex == null ||
        optionIndex < 0 ||
        optionIndex >= question.options.length) {
      return 'Non répondu';
    }

    final letter = String.fromCharCode(65 + optionIndex);
    return '$letter. ${question.options[optionIndex]}';
  }

  BoxDecoration _panelDecoration({required bool isDark}) {
    return BoxDecoration(
      color: isDark
          ? AppColors.darkCard.withValues(alpha: 0.85)
          : Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.10)
            : AppColors.primaryBlue.withValues(alpha: 0.10),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 18,
          offset: const Offset(0, 7),
        ),
      ],
    );
  }

  Widget _buildPlayingBody({
    required bool isDark,
    required bool isWide,
    required Color primaryColor,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    final question = _questions[_currentQuestionIndex];

    return Column(
      key: const ValueKey('quiz-playing'),
      children: [
        _buildHeaderCard(
          isDark: isDark,
          primaryColor: primaryColor,
          textColor: textColor,
          secondaryTextColor: secondaryTextColor,
          showCompletedState: false,
        ),
        const SizedBox(height: 6),
        Expanded(
          child: SingleChildScrollView(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final panelWidth = isWide
                    ? (constraints.maxWidth - 6) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    SizedBox(
                      width: panelWidth,
                      child: _buildQuestionPanel(
                        question: question,
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor,
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                    ),
                    SizedBox(
                      width: panelWidth,
                      child: _buildOptionsPanel(
                        question: question,
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor,
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        _buildQuestionNavigator(
          isDark: isDark,
          primaryColor: primaryColor,
          textColor: textColor,
          secondaryTextColor: secondaryTextColor,
          reviewMode: false,
        ),
      ],
    );
  }

  Widget _buildCompletedBody({
    required bool isDark,
    required bool isWide,
    required Color primaryColor,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    final int wrongAnswers = _totalQuestions - _score;

    IconData trophyIcon;
    Color trophyColor;
    String statusLabel;

    if (_scorePercent >= 0.8) {
      trophyIcon = Icons.emoji_events;
      trophyColor = Colors.amber;
      statusLabel = 'Excellent résultat';
    } else if (_scorePercent >= 0.5) {
      trophyIcon = Icons.verified;
      trophyColor = AppColors.success;
      statusLabel = 'Bon travail';
    } else {
      trophyIcon = Icons.refresh;
      trophyColor = AppColors.warning;
      statusLabel = 'Continuez à vous entraîner';
    }

    return Column(
      key: const ValueKey('quiz-completed'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: _panelDecoration(isDark: isDark),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(trophyIcon, size: 56, color: trophyColor),
                      const SizedBox(height: 10),
                      Text(
                        'Quiz terminé',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Score final: $_score/$_totalQuestions',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: _scorePercent,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation(trophyColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildStatTile(
                      label: 'Réussite',
                      value: '${(_scorePercent * 100).toStringAsFixed(0)}%',
                      icon: Icons.percent,
                      color: primaryColor,
                      isDark: isDark,
                      isWide: isWide,
                    ),
                    _buildStatTile(
                      label: 'Bonnes réponses',
                      value: '$_score',
                      icon: Icons.check_circle,
                      color: AppColors.success,
                      isDark: isDark,
                      isWide: isWide,
                    ),
                    _buildStatTile(
                      label: 'Erreurs',
                      value: '$wrongAnswers',
                      icon: Icons.cancel,
                      color: AppColors.error,
                      isDark: isDark,
                      isWide: isWide,
                    ),
                    _buildStatTile(
                      label: 'Questions',
                      value: '$_totalQuestions',
                      icon: Icons.format_list_numbered,
                      color: AppColors.info,
                      isDark: isDark,
                      isWide: isWide,
                    ),
                  ],
                ),
                if (_isSavingResult)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sauvegarde du score...',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : Colors.black.withValues(alpha: 0.05),
                          color: primaryColor,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                _buildQuestionNavigator(
                  isDark: isDark,
                  primaryColor: primaryColor,
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                  reviewMode: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: _restartQuiz,
              icon: const Icon(Icons.restart_alt),
              label: const Text(
                'Recommencer',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                backgroundColor: primaryColor,
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _goHome,
              icon: const Icon(Icons.home),
              label: const Text(
                'Accueil',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                foregroundColor: textColor,
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.30)
                      : Colors.black.withValues(alpha: 0.22),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderCard({
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color secondaryTextColor,
    required bool showCompletedState,
  }) {
    final double progress = showCompletedState
        ? 1
        : (_currentQuestionIndex + 1) / _totalQuestions;

    return Container(
      decoration: _panelDecoration(isDark: isDark),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Question ${_currentQuestionIndex + 1} / $_totalQuestions',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
              ),
              _buildDifficultyPill(
                difficulty: widget.quiz.difficulty,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(primaryColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.check_circle_outline, size: 16, color: primaryColor),
              const SizedBox(width: 6),
              Text(
                'Répondu: $_answeredCount / $_totalQuestions',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: secondaryTextColor,
                ),
              ),
              const Spacer(),
              Text(
                'Score: $_score',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionPanel({
    required Question question,
    required Color textColor,
    required Color secondaryTextColor,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Container(
      decoration: _panelDecoration(isDark: isDark),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: isDark ? 0.25 : 0.13),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Question ${_currentQuestionIndex + 1}',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            question.text,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: textColor,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsPanel({
    required Question question,
    required Color textColor,
    required Color secondaryTextColor,
    required bool isDark,
    required Color primaryColor,
  }) {
    final selectedIndex = _selectedAnswers[_currentQuestionIndex];

    return Container(
      decoration: _panelDecoration(isDark: isDark),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Réponses',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(question.options.length, (index) {
            final bool isSelected = selectedIndex == index;
            final bool isQuestionLocked = selectedIndex != null;

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == question.options.length - 1 ? 0 : 8,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: (_selectionLocked || isQuestionLocked)
                    ? null
                    : () => _selectAnswer(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: isSelected
                        ? primaryColor.withValues(alpha: isDark ? 0.28 : 0.14)
                        : isDark
                        ? AppColors.darkBackground.withValues(alpha: 0.35)
                        : Colors.white,
                    border: Border.all(
                      color: isSelected
                          ? primaryColor
                          : isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.08),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: isSelected
                            ? primaryColor
                            : isDark
                            ? Colors.white.withValues(alpha: 0.18)
                            : Colors.black.withValues(alpha: 0.06),
                        child: Text(
                          String.fromCharCode(65 + index),
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: isSelected
                                ? (isDark ? Colors.black : Colors.white)
                                : textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          question.options[index],
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: textColor,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Icon(
                            Icons.check_circle,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuestionNavigator({
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color secondaryTextColor,
    required bool reviewMode,
  }) {
    return Container(
      decoration: _panelDecoration(isDark: isDark),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reviewMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Correction par numéro de question',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_totalQuestions, (index) {
                final selected = _selectedAnswers[index];
                final isAnswered = selected != null;
                final isCorrect =
                    isAnswered && selected == _questions[index].correctIndex;
                final isCurrent = index == _currentQuestionIndex;

                Color backgroundColor;
                Color foregroundColor;
                Border border = Border.all(color: Colors.transparent);

                if (!isAnswered) {
                  backgroundColor = isDark
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.black.withValues(alpha: 0.08);
                  foregroundColor = textColor;
                } else if (isCorrect) {
                  backgroundColor = AppColors.success;
                  foregroundColor = Colors.white;
                } else {
                  backgroundColor = AppColors.error;
                  foregroundColor = Colors.white;
                }

                if (!reviewMode && isCurrent) {
                  backgroundColor = primaryColor;
                  foregroundColor = isDark ? Colors.black : Colors.white;
                }

                if (reviewMode && isCurrent) {
                  border = Border.all(color: primaryColor, width: 1.6);
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _onQuestionBadgeTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: border,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            color: foregroundColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          if (reviewMode)
            Text(
              'Touchez un numéro pour voir votre réponse et la bonne réponse.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: secondaryTextColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDifficultyPill({
    required String difficulty,
    required bool isDark,
  }) {
    Color color;
    switch (difficulty.toLowerCase()) {
      case 'facile':
        color = Colors.green;
        break;
      case 'difficile':
        color = Colors.red;
        break;
      default:
        color = AppColors.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.35 : 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        difficulty.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildAnswerInfoTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.24 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required bool isWide,
  }) {
    final minWidth = isWide ? 240.0 : 156.0;

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _panelDecoration(isDark: isDark),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: isDark ? 0.30 : 0.16),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.quiz.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Poppins'),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth >= 920;
          final EdgeInsets screenPadding = EdgeInsets.symmetric(
            horizontal: isWide ? 10 : 6,
            vertical: 6,
          );

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF10182D), AppColors.darkBackground]
                    : [const Color(0xFFE9F4FF), AppColors.lightBackground],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: screenPadding,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: _quizCompleted
                          ? _buildCompletedBody(
                              isDark: isDark,
                              isWide: isWide,
                              primaryColor: primaryColor,
                              textColor: textColor,
                              secondaryTextColor: secondaryTextColor,
                            )
                          : _buildPlayingBody(
                              isDark: isDark,
                              isWide: isWide,
                              primaryColor: primaryColor,
                              textColor: textColor,
                              secondaryTextColor: secondaryTextColor,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
