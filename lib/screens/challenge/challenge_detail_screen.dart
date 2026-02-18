import 'dart:async';

import 'package:atao_quiz/screens/generatequiz/play_quiz_screen.dart';
import 'package:atao_quiz/services/challenge_service.dart';
import 'package:atao_quiz/services/quiz_transfer_service.dart';
import 'package:atao_quiz/services/storage_service.dart';
import 'package:atao_quiz/theme/colors.dart';
import 'package:flutter/material.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final String sessionId;

  const ChallengeDetailScreen({super.key, required this.sessionId});

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  final ChallengeService _challengeService = ChallengeService();
  final StorageService _storageService = StorageService();
  final QuizTransferService _transferService = QuizTransferService();
  final TextEditingController _participantController = TextEditingController();
  static const List<int> _networkRoundDurationsSeconds = [120, 300, 600, 900];
  static const int _roundStartGraceSeconds = 12;

  ChallengeSession? _session;
  Quiz? _quiz;
  bool _isLoading = true;
  bool _isLaunchingQuiz = false;
  bool _isDeleting = false;
  bool _isStartingNetwork = false;
  Timer? _reloadTimer;
  Timer? _roundCountdownTimer;
  LiveChallengeRoundPlan? _pendingRoundPlan;
  int _roundCountdownSeconds = 0;
  final Set<String> _launchedRoundIds = <String>{};

  @override
  void initState() {
    super.initState();
    _transferService.addListener(_onTransferChanged);
    _transferService.initialize();
    _loadSession();
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    _roundCountdownTimer?.cancel();
    _transferService.removeListener(_onTransferChanged);
    _participantController.dispose();
    super.dispose();
  }

  void _onTransferChanged() {
    if (!mounted) {
      return;
    }
    _reloadTimer?.cancel();
    _reloadTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        unawaited(_loadSession());
      }
    });
  }

  Future<void> _loadSession() async {
    setState(() => _isLoading = true);
    try {
      final session = await _challengeService.getSessionById(widget.sessionId);
      final quizzes = await _storageService.getQuizzes();
      final localName = await _challengeService.getLocalPlayerName();

      Quiz? quiz;
      if (session != null) {
        for (final item in quizzes) {
          if (item.id == session.quizId) {
            quiz = item;
            break;
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _session = session;
        _quiz = quiz;
        if (_participantController.text.trim().isEmpty) {
          _participantController.text = localName;
        }
        _isLoading = false;
      });
      _syncPendingRoundFromService();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _syncPendingRoundFromService();
    }
  }

  Future<void> _deleteSession() async {
    final session = _session;
    if (session == null) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce challenge ?'),
        content: Text('Le challenge "${session.name}" sera supprimé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() => _isDeleting = true);
    try {
      await _challengeService.deleteSession(session.id);
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _startNetworkChallenge() async {
    final session = _session;
    final quiz = _quiz;
    if (session == null || quiz == null) {
      _showMessage('Quiz ou challenge indisponible.', isError: true);
      return;
    }

    if (!_transferService.isHosting) {
      _showMessage(
        'Passez en mode hôte (serveur) dans Transfert Wi-Fi.',
        isError: true,
      );
      return;
    }

    if (_transferService.connectedPeersCount == 0) {
      _showMessage('Aucun téléphone connecté.', isError: true);
      return;
    }

    setState(() => _isStartingNetwork = true);
    try {
      final localName = await _challengeService.getLocalPlayerName();
      await _transferService.startLiveChallenge(
        session: session,
        quiz: quiz,
        hostPlayerName: localName,
      );
      await _loadSession();
      if (!mounted) {
        return;
      }
      _showMessage(
        'Challenge Wi-Fi lancé pour ${_transferService.connectedPeersCount} pair(s).',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(
        'Impossible de lancer le challenge réseau: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isStartingNetwork = false);
      }
    }
  }

  Future<void> _onPlayPressed() async {
    final session = _session;
    if (session == null) {
      _showMessage('Challenge introuvable.', isError: true);
      return;
    }

    final networkSessionId = session.networkSessionId;
    final isNetworkRun =
        networkSessionId != null && _transferService.isConnected;
    if (!isNetworkRun) {
      await _openChallengeQuiz();
      return;
    }

    if (!_transferService.isHosting) {
      final roundPlan = _transferService.getRoundPlanForNetworkSession(
        networkSessionId,
      );
      if (roundPlan != null && _secondsUntilRoundStart(roundPlan) > 0) {
        _showMessage(
          'Départ prévu dans ${_secondsUntilRoundStart(roundPlan)}s. Attendez l\'hôte.',
        );
      } else {
        _showMessage(
          'Seul le créateur peut démarrer. Attendez le compte à rebours.',
        );
      }
      return;
    }

    await _startSyncedNetworkRound(networkSessionId);
  }

  Future<void> _startSyncedNetworkRound(String networkSessionId) async {
    if (_transferService.connectedPeersCount == 0) {
      _showMessage(
        'Aucun ami connecté. Ouvrez Partage via Wi-Fi avant de lancer.',
        isError: true,
      );
      return;
    }

    final choice = await _showRoundStartDialog();
    if (choice == null) {
      return;
    }

    try {
      final participant = _participantController.text.trim();
      final fallbackName = await _challengeService.getLocalPlayerName();
      final starterName = participant.isEmpty ? fallbackName : participant;
      final roundPlan = await _transferService.startLiveChallengeRound(
        networkSessionId: networkSessionId,
        startedBy: starterName,
        roundTimeLimitSeconds: choice.timeLimitSeconds,
      );
      if (!mounted) {
        return;
      }

      final countdown = _secondsUntilRoundStart(roundPlan);
      setState(() {
        _pendingRoundPlan = roundPlan;
        _roundCountdownSeconds = countdown;
      });
      if (countdown > 0) {
        _startRoundCountdownTicker();
      } else {
        unawaited(_launchRoundWhenReady(roundPlan));
      }

      final timerLabel = roundPlan.timeLimitSeconds == null
          ? 'sans chrono'
          : 'chrono ${_formatDurationFromSeconds(roundPlan.timeLimitSeconds!)}';
      _showMessage('Départ synchronisé dans ${countdown}s ($timerLabel).');
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(
        'Impossible de démarrer la partie synchronisée: $e',
        isError: true,
      );
    }
  }

  Future<_RoundStartChoice?> _showRoundStartDialog() {
    var timerEnabled = false;
    var selectedDuration = _networkRoundDurationsSeconds.first;

    return showDialog<_RoundStartChoice>(
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

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark
                  ? AppColors.darkCard
                  : AppColors.lightCard,
              title: Text(
                'Lancer la partie réseau',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Par défaut, le défi démarre sans chrono.',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontFamily: 'Poppins',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: timerEnabled,
                      onChanged: (value) {
                        setDialogState(() => timerEnabled = value);
                      },
                      activeThumbColor: primaryColor,
                      title: Text(
                        'Activer défi avec temps',
                        style: TextStyle(
                          color: textColor,
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        timerEnabled
                            ? 'Le quiz se termine à la fin du chrono.'
                            : 'Aucun chrono appliqué.',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontFamily: 'Poppins',
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (timerEnabled) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _networkRoundDurationsSeconds.map((seconds) {
                          return ChoiceChip(
                            label: Text(_formatDurationFromSeconds(seconds)),
                            selected: selectedDuration == seconds,
                            onSelected: (_) {
                              setDialogState(() => selectedDuration = seconds);
                            },
                            selectedColor: primaryColor.withValues(alpha: 0.22),
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Annuler', style: TextStyle(color: primaryColor)),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      _RoundStartChoice(
                        timeLimitSeconds: timerEnabled
                            ? selectedDuration
                            : null,
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Lancer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openChallengeQuiz({int? forcedTimeLimitSeconds}) async {
    final session = _session;
    final quiz = _quiz;
    if (session == null) {
      _showMessage('Challenge introuvable.', isError: true);
      return;
    }
    if (quiz == null) {
      _showMessage(
        'Le quiz source de ce challenge a été supprimé.',
        isError: true,
      );
      return;
    }

    final participant = _participantController.text.trim();
    if (participant.isEmpty) {
      _showMessage('Entrez un nom de participant.', isError: true);
      return;
    }

    final networkSessionId = session.networkSessionId;
    final shouldPublishNetwork =
        networkSessionId != null && _transferService.isConnected;
    final fallbackTimedLimitSeconds = !shouldPublishNetwork && session.isTimed
        ? session.timeLimitSeconds
        : null;
    final effectiveTimeLimitSeconds =
        forcedTimeLimitSeconds ?? fallbackTimedLimitSeconds;

    final saveOperations = <Future<void>>[];
    setState(() => _isLaunchingQuiz = true);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayQuizScreen(
            quiz: quiz,
            persistResult: false,
            challengeTimeLimit: effectiveTimeLimitSeconds == null
                ? null
                : Duration(seconds: effectiveTimeLimitSeconds),
            onCompleted: (result) {
              saveOperations.add(_saveAttempt(participant, session.id, result));

              if (shouldPublishNetwork) {
                saveOperations.add(
                  _transferService.submitLiveChallengeResult(
                    networkSessionId: networkSessionId,
                    participantName: participant,
                    score: result.score,
                    totalQuestions: result.totalQuestions,
                    completionDurationMs: result.completionDurationMs,
                  ),
                );
              }
            },
          ),
        ),
      );

      if (saveOperations.isNotEmpty) {
        await Future.wait(saveOperations);
      }
    } finally {
      if (mounted) {
        setState(() => _isLaunchingQuiz = false);
      }
    }

    if (mounted) {
      await _loadSession();
    }
  }

  void _syncPendingRoundFromService() {
    final networkSessionId = _session?.networkSessionId;
    if (networkSessionId == null) {
      if (_pendingRoundPlan != null || _roundCountdownSeconds != 0) {
        setState(() {
          _pendingRoundPlan = null;
          _roundCountdownSeconds = 0;
        });
      }
      _stopRoundCountdownTicker();
      return;
    }

    final fetched = _transferService.getRoundPlanForNetworkSession(
      networkSessionId,
    );
    final activePlan = (fetched != null && _isRoundPlanFresh(fetched))
        ? fetched
        : null;

    if (activePlan == null) {
      if (_pendingRoundPlan != null || _roundCountdownSeconds != 0) {
        setState(() {
          _pendingRoundPlan = null;
          _roundCountdownSeconds = 0;
        });
      }
      _stopRoundCountdownTicker();
      return;
    }

    final countdown = _secondsUntilRoundStart(activePlan);
    final changed =
        _pendingRoundPlan?.roundId != activePlan.roundId ||
        _pendingRoundPlan?.startsAt != activePlan.startsAt ||
        _pendingRoundPlan?.timeLimitSeconds != activePlan.timeLimitSeconds ||
        _roundCountdownSeconds != countdown;
    if (changed) {
      setState(() {
        _pendingRoundPlan = activePlan;
        _roundCountdownSeconds = countdown;
      });
    }

    if (countdown > 0) {
      _startRoundCountdownTicker();
    } else {
      _stopRoundCountdownTicker();
      unawaited(_launchRoundWhenReady(activePlan));
    }
  }

  void _startRoundCountdownTicker() {
    _roundCountdownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _stopRoundCountdownTicker();
        return;
      }
      final plan = _pendingRoundPlan;
      if (plan == null) {
        _stopRoundCountdownTicker();
        return;
      }

      final countdown = _secondsUntilRoundStart(plan);
      if (countdown > 0) {
        if (_roundCountdownSeconds != countdown) {
          setState(() => _roundCountdownSeconds = countdown);
        }
        return;
      }

      if (_roundCountdownSeconds != 0) {
        setState(() => _roundCountdownSeconds = 0);
      }
      _stopRoundCountdownTicker();
      unawaited(_launchRoundWhenReady(plan));
    });
  }

  void _stopRoundCountdownTicker() {
    _roundCountdownTimer?.cancel();
    _roundCountdownTimer = null;
  }

  int _secondsUntilRoundStart(LiveChallengeRoundPlan plan) {
    final remaining = plan.startsAt.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  bool _isRoundPlanFresh(LiveChallengeRoundPlan plan) {
    final delay = DateTime.now().difference(plan.startsAt).inSeconds;
    return delay <= _roundStartGraceSeconds;
  }

  Future<void> _launchRoundWhenReady(LiveChallengeRoundPlan plan) async {
    if (_launchedRoundIds.contains(plan.roundId) || _isLaunchingQuiz) {
      return;
    }
    if (!_isRoundPlanFresh(plan)) {
      return;
    }
    if (_participantController.text.trim().isEmpty) {
      _participantController.text = await _challengeService.getLocalPlayerName();
    }
    _launchedRoundIds.add(plan.roundId);
    await _openChallengeQuiz(forcedTimeLimitSeconds: plan.timeLimitSeconds);
    if (!mounted) {
      return;
    }
    if (_pendingRoundPlan?.roundId == plan.roundId) {
      setState(() {
        _pendingRoundPlan = null;
        _roundCountdownSeconds = 0;
      });
    }
  }

  Future<void> _saveAttempt(
    String participant,
    String sessionId,
    QuizPlayResult result,
  ) async {
    try {
      await _challengeService.addAttempt(
        sessionId: sessionId,
        participantName: participant,
        score: result.score,
        totalQuestions: result.totalQuestions,
        completionDurationMs: result.completionDurationMs,
      );
      if (!mounted) {
        return;
      }
      _showMessage(
        'Score enregistré: $participant (${result.score}/${result.totalQuestions})',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage('Impossible de sauvegarder le score: $e', isError: true);
    }
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
    final d = dateTime.day.toString().padLeft(2, '0');
    final m = dateTime.month.toString().padLeft(2, '0');
    final y = dateTime.year.toString();
    final h = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
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

  Color _rankColor(int rank) {
    if (rank == 1) {
      return const Color(0xFFFFC107);
    }
    if (rank == 2) {
      return const Color(0xFFB0BEC5);
    }
    if (rank == 3) {
      return const Color(0xFFCD7F32);
    }
    return AppColors.info;
  }

  InputDecoration _inputDecoration({
    required String labelText,
    required Color primaryColor,
  }) {
    return InputDecoration(
      labelText: labelText,
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
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: primaryColor),
        ),
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    final session = _session;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: primaryColor),
        ),
        body: Center(
          child: Text(
            'Challenge introuvable.',
            style: TextStyle(color: textColor, fontFamily: 'Poppins'),
          ),
        ),
      );
    }

    final networkSessionId = session.networkSessionId;
    final isNetworkRun =
        networkSessionId != null && _transferService.isConnected;
    final isNetworkHost = isNetworkRun && _transferService.isHosting;
    final pendingRound = _pendingRoundPlan;
    final isPendingRoundFresh =
        pendingRound != null && _isRoundPlanFresh(pendingRound);
    final isRoundCountingDown =
        isPendingRoundFresh && (_roundCountdownSeconds > 0);
    final isRoundStartingNow =
        isPendingRoundFresh && (_roundCountdownSeconds == 0);
    final liveResults = networkSessionId == null
        ? const <LiveChallengePlayerResult>[]
        : _transferService.getRankedResultsForNetworkSession(networkSessionId);
    final rankedLocal = _challengeService.rankAttempts(session);
    final useLiveResults = liveResults.isNotEmpty;
    final modeLabel = session.isTimed
        ? 'Challenge avec le temps (${_formatDurationFromSeconds(session.timeLimitSeconds ?? 0)})'
        : 'Défi entre amis';

    final canStartNetwork =
        !_isStartingNetwork &&
        _transferService.isHosting &&
        _transferService.connectedPeersCount > 0 &&
        networkSessionId == null;

    final playLabelBase = isNetworkRun
        ? isNetworkHost
              ? 'Jouer et publier score réseau'
              : 'En attente du créateur'
        : 'Jouer ce challenge';
    final playLabel = !isNetworkRun && session.isTimed
        ? '$playLabelBase (${_formatDurationFromSeconds(session.timeLimitSeconds ?? 0)})'
        : playLabelBase;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: primaryColor),
        title: Text(
          session.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isDeleting ? null : _deleteSession,
            icon: _isDeleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSession,
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
                    session.quizTitle,
                    style: TextStyle(
                      color: textColor,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${session.questionCount} questions • Créé le ${_formatDate(session.createdAt)}',
                    style: TextStyle(color: secondaryTextColor, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    modeLabel,
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (networkSessionId != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Session réseau: $networkSessionId',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _quiz == null
                        ? 'Quiz source introuvable.'
                        : 'Quiz source disponible.',
                    style: TextStyle(
                      color: _quiz == null
                          ? AppColors.error
                          : AppColors.success,
                      fontSize: 12,
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
                    'Challenge réseau (Wi-Fi)',
                    style: TextStyle(
                      color: textColor,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'État connexion: ${_transferService.statusMessage}',
                    style: TextStyle(color: secondaryTextColor, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pairs connectés: ${_transferService.connectedPeersCount}',
                    style: TextStyle(color: secondaryTextColor, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  if (networkSessionId == null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: canStartNetwork
                            ? _startNetworkChallenge
                            : null,
                        icon: _isStartingNetwork
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.wifi_tethering),
                        label: const Text('Lancer challenge Wi-Fi'),
                      ),
                    )
                  else
                    Text(
                      'Challenge Wi-Fi déjà lancé. Les joueurs connectés peuvent envoyer leurs résultats.',
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
                    'Lancer une partie',
                    style: TextStyle(
                      color: textColor,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _participantController,
                    textInputAction: TextInputAction.done,
                    decoration: _inputDecoration(
                      labelText: 'Nom participant',
                      primaryColor: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          !_isLaunchingQuiz && (!isNetworkRun || isNetworkHost)
                          ? _onPlayPressed
                          : null,
                      icon: _isLaunchingQuiz
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(playLabel),
                    ),
                  ),
                  if (isNetworkRun) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isNetworkHost
                                ? 'Démarrage synchronisé: vous lancez, les autres attendent.'
                                : 'Attendez le créateur: le quiz démarre automatiquement.',
                            style: TextStyle(
                              color: textColor,
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (isRoundCountingDown)
                            Text(
                              'Départ dans ${_roundCountdownSeconds}s • '
                              '${pendingRound.timeLimitSeconds == null ? 'Sans chrono' : 'Chrono ${_formatDurationFromSeconds(pendingRound.timeLimitSeconds!)}'}',
                              style: TextStyle(
                                color: primaryColor,
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else if (isRoundStartingNow)
                            Text(
                              'Démarrage en cours... '
                              '${pendingRound.timeLimitSeconds == null ? 'Sans chrono' : 'Chrono ${_formatDurationFromSeconds(pendingRound.timeLimitSeconds!)}'}',
                              style: TextStyle(
                                color: primaryColor,
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            Text(
                              'En attente du prochain départ synchronisé.',
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontFamily: 'Poppins',
                                fontSize: 12,
                              ),
                            ),
                          if (pendingRound != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Lancé par: ${pendingRound.startedBy}',
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontFamily: 'Poppins',
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              useLiveResults
                  ? 'Classement live (départage au temps)'
                  : session.isTimed
                  ? 'Classement du challenge (mode chrono)'
                  : 'Classement du challenge',
              style: TextStyle(
                color: textColor,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            if (useLiveResults)
              ...List.generate(liveResults.length, (index) {
                final result = liveResults[index];
                final rank = index + 1;
                final color = _rankColor(rank);
                final percent = (result.successRate * 100).toStringAsFixed(0);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: _cardDecoration(isDark, primaryColor),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.18),
                      child: Text(
                        '$rank',
                        style: TextStyle(color: color, fontFamily: 'Poppins'),
                      ),
                    ),
                    title: Text(
                      result.playerName,
                      style: TextStyle(
                        color: textColor,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${result.score}/${result.totalQuestions} • $percent% • Temps: ${_formatDuration(result.completionDurationMs)}\n'
                      '${_formatDate(result.completedAt)}',
                      style: TextStyle(color: secondaryTextColor, fontSize: 12),
                    ),
                    isThreeLine: true,
                  ),
                );
              })
            else if (rankedLocal.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(isDark, primaryColor),
                child: Text(
                  'Aucun score enregistré pour ce challenge.',
                  style: TextStyle(color: secondaryTextColor),
                ),
              )
            else
              ...List.generate(rankedLocal.length, (index) {
                final attempt = rankedLocal[index];
                final rank = index + 1;
                final color = _rankColor(rank);
                final percent = (attempt.successRate * 100).toStringAsFixed(0);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: _cardDecoration(isDark, primaryColor),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.18),
                      child: Text(
                        '$rank',
                        style: TextStyle(color: color, fontFamily: 'Poppins'),
                      ),
                    ),
                    title: Text(
                      attempt.participantName,
                      style: TextStyle(
                        color: textColor,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${attempt.score}/${attempt.totalQuestions} • $percent% • Temps: ${_formatDuration(attempt.completionDurationMs)}\n'
                      '${_formatDate(attempt.completedAt)}',
                      style: TextStyle(color: secondaryTextColor, fontSize: 12),
                    ),
                    isThreeLine: true,
                  ),
                );
              }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _RoundStartChoice {
  final int? timeLimitSeconds;

  const _RoundStartChoice({required this.timeLimitSeconds});
}
