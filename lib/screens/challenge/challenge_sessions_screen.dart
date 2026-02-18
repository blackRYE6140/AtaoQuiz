import 'dart:async';

import 'package:atao_quiz/screens/challenge/challenge_detail_screen.dart';
import 'package:atao_quiz/services/challenge_service.dart';
import 'package:atao_quiz/services/quiz_transfer_service.dart';
import 'package:atao_quiz/services/storage_service.dart';
import 'package:atao_quiz/theme/colors.dart';
import 'package:flutter/material.dart';

class ChallengeSessionsScreen extends StatefulWidget {
  const ChallengeSessionsScreen({super.key});

  @override
  State<ChallengeSessionsScreen> createState() =>
      _ChallengeSessionsScreenState();
}

class _ChallengeSessionsScreenState extends State<ChallengeSessionsScreen> {
  final ChallengeService _challengeService = ChallengeService();
  final StorageService _storageService = StorageService();
  final QuizTransferService _transferService = QuizTransferService();
  static const List<int> _timedDurationsSeconds = [3, 5, 10, 15, 30, 60, 120, 180, 300, 400, 500, 600];
  final TextEditingController _challengeNameController =
      TextEditingController();
  final TextEditingController _localPlayerController = TextEditingController();
  Timer? _reloadTimer;

  List<ChallengeSession> _sessions = [];
  List<Quiz> _quizzes = [];
  Quiz? _selectedQuiz;
  bool _isLoading = true;
  bool _isCreating = false;
  bool _isSavingName = false;

  @override
  void initState() {
    super.initState();
    _transferService.addListener(_onTransferChanged);
    _transferService.initialize();
    _loadData();
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    _transferService.removeListener(_onTransferChanged);
    _challengeNameController.dispose();
    _localPlayerController.dispose();
    super.dispose();
  }

  void _onTransferChanged() {
    if (!mounted) {
      return;
    }
    _reloadTimer?.cancel();
    _reloadTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        unawaited(_loadData());
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final sessions = await _challengeService.getSessions();
      final quizzes = await _storageService.getQuizzes();
      final localName = await _challengeService.getLocalPlayerName();
      quizzes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) {
        return;
      }

      setState(() {
        _sessions = sessions;
        _quizzes = quizzes;
        _selectedQuiz = _resolveSelectedQuiz(
          selectedQuiz: _selectedQuiz,
          quizzes: quizzes,
        );
        _localPlayerController.text = localName;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
    }
  }

  Quiz? _resolveSelectedQuiz({
    required Quiz? selectedQuiz,
    required List<Quiz> quizzes,
  }) {
    if (quizzes.isEmpty) {
      return null;
    }
    if (selectedQuiz == null) {
      return quizzes.first;
    }
    final index = quizzes.indexWhere((item) => item.id == selectedQuiz.id);
    if (index < 0) {
      return quizzes.first;
    }
    return quizzes[index];
  }

  Future<void> _createChallenge() async {
    final quiz = _selectedQuiz;
    if (quiz == null) {
      _showMessage(
        'Aucun quiz disponible. Créez un quiz avant un challenge.',
        isError: true,
      );
      return;
    }

    final choice = await _showChallengeModeDialog();
    if (choice == null) {
      return;
    }

    setState(() => _isCreating = true);
    try {
      final session = await _challengeService.createSession(
        quiz: quiz,
        sessionName: _challengeNameController.text.trim(),
        mode: choice.mode,
        timeLimitSeconds: choice.timeLimitSeconds,
      );
      _challengeNameController.clear();

      if (!mounted) {
        return;
      }

      _showMessage(
        choice.mode == ChallengeMode.timed
            ? 'Challenge chronométré créé.'
            : 'Défi entre amis créé.',
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChallengeDetailScreen(sessionId: session.id),
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage('Erreur création challenge: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _saveLocalPlayerName() async {
    final name = _localPlayerController.text.trim();
    if (name.isEmpty) {
      _showMessage('Nom joueur invalide.', isError: true);
      return;
    }

    setState(() => _isSavingName = true);
    try {
      await _challengeService.setLocalPlayerName(name);
      if (!mounted) {
        return;
      }
      _showMessage('Nom joueur mis à jour.');
      await _loadData();
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage('Impossible de sauvegarder le nom: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSavingName = false);
      }
    }
  }

  Future<_ChallengeCreationChoice?> _showChallengeModeDialog() {
    final parentContext = context;
    int selectedDuration = 300;
    String selectedMode = ChallengeMode.friends;

    return showDialog<_ChallengeCreationChoice>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final primaryColor = isDark
            ? AppColors.accentYellow
            : AppColors.primaryBlue;
        final textColor = isDark ? AppColors.darkText : AppColors.lightText;
        final secondaryTextColor = isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary;
        final hasConnectedPeer = _transferService.connectedPeersCount > 0;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark
                  ? AppColors.darkCard
                  : AppColors.lightCard,
              title: Text(
                'Choisir le type de challenge',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModeCard(
                        label: 'Défi entre amis',
                        icon: Icons.groups,
                        description:
                            'Mode classique pour jouer et comparer les scores.',
                        selected: selectedMode == ChallengeMode.friends,
                        isDark: isDark,
                        primaryColor: primaryColor,
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor,
                        onTap: () {
                          setDialogState(
                            () => selectedMode = ChallengeMode.friends,
                          );
                        },
                      ),
                      if (selectedMode == ChallengeMode.friends &&
                          !hasConnectedPeer) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Aucun autre téléphone connecté pour le moment.',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 12,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  Navigator.pushNamed(
                                    parentContext,
                                    '/transfer-quiz',
                                  );
                                },
                                icon: const Icon(Icons.wifi_tethering),
                                label: const Text('Configurer via Wi-Fi'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primaryColor,
                                  side: BorderSide(
                                    color: primaryColor.withValues(alpha: 0.35),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _buildModeCard(
                        label: 'Challenge avec le temps',
                        icon: Icons.timer_outlined,
                        description:
                            'Le quiz se termine automatiquement à la fin du chrono.',
                        selected: selectedMode == ChallengeMode.timed,
                        isDark: isDark,
                        primaryColor: primaryColor,
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor,
                        onTap: () {
                          setDialogState(
                            () => selectedMode = ChallengeMode.timed,
                          );
                        },
                      ),
                      if (selectedMode == ChallengeMode.timed) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Durée du défi',
                          style: TextStyle(
                            color: textColor,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _timedDurationsSeconds.map((seconds) {
                            return ChoiceChip(
                              label: Text(_formatDurationFromSeconds(seconds)),
                              selected: selectedDuration == seconds,
                              onSelected: (_) {
                                setDialogState(
                                  () => selectedDuration = seconds,
                                );
                              },
                              selectedColor: primaryColor.withValues(
                                alpha: 0.22,
                              ),
                              side: BorderSide(
                                color: primaryColor.withValues(alpha: 0.35),
                              ),
                              labelStyle: TextStyle(
                                color: textColor,
                                fontFamily: 'Poppins',
                                fontWeight: selectedDuration == seconds
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Annuler', style: TextStyle(color: primaryColor)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      _ChallengeCreationChoice(
                        mode: selectedMode,
                        timeLimitSeconds: selectedMode == ChallengeMode.timed
                            ? selectedDuration
                            : null,
                      ),
                    );
                  },
                  child: const Text('Continuer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildModeCard({
    required String label,
    required IconData icon,
    required String description,
    required bool selected,
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color secondaryTextColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? primaryColor.withValues(alpha: isDark ? 0.2 : 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? primaryColor
                  : primaryColor.withValues(alpha: 0.28),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: textColor,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontFamily: 'Poppins',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? primaryColor : secondaryTextColor,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSession(ChallengeSession session) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChallengeDetailScreen(sessionId: session.id),
      ),
    );
    await _loadData();
  }

  void _showMessage(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String _formatDurationFromSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) {
      return '$minutes min';
    }
    return '${minutes}m ${remainingSeconds}s';
  }

  InputDecoration _inputDecoration({
    required String labelText,
    String? hintText,
    required Color primaryColor,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.32)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.32)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 1.5),
      ),
    );
  }

  BoxDecoration _cardDecoration(bool isDark, Color primaryColor) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      border: Border.all(color: primaryColor.withValues(alpha: 0.32)),
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

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: primaryColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardDecoration(isDark, primaryColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profil challenge',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _localPlayerController,
                  textInputAction: TextInputAction.done,
                  decoration: _inputDecoration(
                    labelText: 'Nom joueur local',
                    primaryColor: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _isSavingName ? null : _saveLocalPlayerName,
                    icon: _isSavingName
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_alt),
                    label: const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardDecoration(isDark, primaryColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connexion Wi-Fi (challenge live)',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _transferService.statusMessage,
                  style: TextStyle(color: secondaryTextColor, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pairs connectés: ${_transferService.connectedPeersCount}',
                  style: TextStyle(color: secondaryTextColor, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Astuce: lancez le serveur dans Transfert Wi-Fi puis démarrez un challenge réseau depuis le détail.',
                  style: TextStyle(color: secondaryTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardDecoration(isDark, primaryColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Créer un challenge',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                if (_quizzes.isEmpty)
                  Text(
                    'Aucun quiz disponible pour créer un challenge.',
                    style: TextStyle(color: secondaryTextColor),
                  )
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedQuiz?.id),
                    initialValue: _selectedQuiz?.id,
                    decoration: _inputDecoration(
                      labelText: 'Quiz à utiliser',
                      primaryColor: primaryColor,
                    ),
                    items: _quizzes
                        .map(
                          (quiz) => DropdownMenuItem<String>(
                            value: quiz.id,
                            child: Text(
                              quiz.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      final selected = _quizzes.where(
                        (quiz) => quiz.id == value,
                      );
                      if (selected.isEmpty) {
                        return;
                      }
                      setState(() {
                        _selectedQuiz = selected.first;
                      });
                    },
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: _challengeNameController,
                  decoration: _inputDecoration(
                    labelText: 'Nom challenge (optionnel)',
                    hintText: 'Ex: Défi maths de la semaine',
                    primaryColor: primaryColor,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isCreating || _quizzes.isEmpty
                        ? null
                        : _createChallenge,
                    icon: _isCreating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_task),
                    label: const Text('Créer et ouvrir'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Challenges actifs (${_sessions.length})',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          if (_sessions.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(isDark, primaryColor),
              child: Text(
                'Aucun challenge pour le moment.',
                style: TextStyle(color: secondaryTextColor),
              ),
            )
          else
            ..._sessions.map((session) {
              final ranked = _challengeService.rankAttempts(session);
              final leader = ranked.isNotEmpty ? ranked.first : null;
              final participants = ranked.length;
              final isNetwork = session.networkSessionId != null;
              final modeLabel = session.isTimed
                  ? 'Chrono ${_formatDurationFromSeconds(session.timeLimitSeconds!)}'
                  : 'Défi entre amis';
              final isLiveNetwork =
                  isNetwork &&
                  _transferService.getLiveChallengeByNetworkId(
                        session.networkSessionId!,
                      ) !=
                      null;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: _cardDecoration(isDark, primaryColor),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primaryColor.withValues(alpha: 0.18),
                    child: Icon(
                      session.isTimed ? Icons.timer_outlined : Icons.flag,
                      color: primaryColor,
                    ),
                  ),
                  title: Text(
                    session.name,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${isNetwork ? 'Réseau Wi-Fi${isLiveNetwork ? ' (actif)' : ''}' : 'Local'} • '
                    '$modeLabel\n'
                    '${session.quizTitle} (${session.questionCount} questions)\n'
                    '${leader == null ? 'Aucun score' : 'Leader: ${leader.participantName} (${leader.score}/${leader.totalQuestions})'} • '
                    '$participants participant(s)\n'
                    'Créé le ${_formatDate(session.createdAt)}',
                    style: TextStyle(color: secondaryTextColor, fontSize: 12),
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: () => _openSession(session),
                  ),
                  onTap: () => _openSession(session),
                ),
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ChallengeCreationChoice {
  final String mode;
  final int? timeLimitSeconds;

  const _ChallengeCreationChoice({
    required this.mode,
    required this.timeLimitSeconds,
  });
}
