import 'dart:async';
import 'dart:io';

import 'package:atao_quiz/services/quiz_transfer_service.dart';
import 'package:atao_quiz/services/storage_service.dart';
import 'package:atao_quiz/theme/colors.dart';
import 'package:flutter/material.dart';

class SendQuizScreen extends StatefulWidget {
  const SendQuizScreen({super.key});

  @override
  State<SendQuizScreen> createState() => _SendQuizScreenState();
}

class _SendQuizScreenState extends State<SendQuizScreen> {
  final StorageService _storageService = StorageService();
  final QuizTransferService _transferService = QuizTransferService();
  final TextEditingController _portController = TextEditingController(
    text: '${QuizTransferService.defaultPort}',
  );

  List<Quiz> _quizzes = [];
  List<String> _localIps = [];
  bool _isLoading = true;
  bool _isServing = false;
  bool _isSending = false;
  String _status = 'Sélectionnez un quiz puis appuyez sur "Envoyer".';
  String? _error;
  Quiz? _activeQuiz;
  ServerSocket? _server;
  StreamSubscription<Socket>? _serverSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _portController.dispose();
    _serverSubscription?.cancel();
    _server?.close();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final quizzes = await _storageService.getQuizzes();
      final localIps = await _transferService.getLocalIpv4Addresses();
      quizzes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) {
        return;
      }

      setState(() {
        _quizzes = quizzes;
        _localIps = localIps;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Impossible de charger les quiz: $e';
      });
    }
  }

  int? _validatedPort() {
    final parsed = int.tryParse(_portController.text.trim());
    if (parsed == null || parsed < 1 || parsed > 65535) {
      return null;
    }
    return parsed;
  }

  Future<void> _startServerForQuiz(Quiz quiz) async {
    final port = _validatedPort();
    if (port == null) {
      _showMessage(
        'Port invalide. Utilisez un nombre entre 1 et 65535.',
        isError: true,
      );
      return;
    }

    await _stopServer(showMessage: false);

    try {
      final server = await _transferService.startServer(port: port);
      if (!mounted) {
        await server.close();
        return;
      }

      setState(() {
        _server = server;
        _activeQuiz = quiz;
        _isServing = true;
        _isSending = false;
        _error = null;
        _status =
            'Serveur prêt sur le port $port. Le receveur peut se connecter.';
      });

      _serverSubscription = server.listen(
        _handleClientConnection,
        onError: (Object err) {
          if (!mounted) {
            return;
          }
          setState(() {
            _error = 'Erreur serveur: $err';
            _status = 'Le serveur a rencontré une erreur.';
          });
          _stopServer(showMessage: false);
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Impossible de démarrer le serveur: $e';
      });
    }
  }

  Future<void> _handleClientConnection(Socket client) async {
    final activeQuiz = _activeQuiz;
    if (activeQuiz == null) {
      client.destroy();
      return;
    }

    setState(() {
      _isSending = true;
      _status = 'Receveur connecté. Envoi du quiz...';
    });

    await _serverSubscription?.cancel();
    _serverSubscription = null;
    await _server?.close();
    _server = null;

    try {
      await _transferService.sendQuiz(client, activeQuiz);
      if (!mounted) {
        return;
      }

      setState(() {
        _isServing = false;
        _isSending = false;
        _status = 'Quiz envoyé avec succès.';
        _activeQuiz = null;
      });
      _showMessage('Quiz envoyé. Le receveur peut maintenant jouer.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isServing = false;
        _isSending = false;
        _activeQuiz = null;
        _error = 'Échec de l\'envoi: $e';
        _status = 'L\'envoi a échoué.';
      });
      _showMessage('Erreur pendant l\'envoi: $e', isError: true);
    } finally {
      client.destroy();
    }
  }

  Future<void> _stopServer({bool showMessage = true}) async {
    await _serverSubscription?.cancel();
    _serverSubscription = null;

    await _server?.close();
    _server = null;

    if (!mounted) {
      return;
    }

    setState(() {
      _isServing = false;
      _isSending = false;
      _activeQuiz = null;
      if (showMessage) {
        _status = 'Serveur arrêté.';
      }
    });

    if (showMessage) {
      _showMessage('Serveur arrêté.');
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
            decoration: _cardDecoration(isDark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuration réseau',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Port socket',
                    hintText: 'Ex: ${QuizTransferService.defaultPort}',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _localIps.isEmpty
                      ? 'IP locale introuvable. Vérifiez votre Wi-Fi.'
                      : 'IP de ce téléphone: ${_localIps.join(' , ')}',
                  style: TextStyle(color: secondaryTextColor, fontSize: 12),
                ),
                if (_isServing) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _stopServer,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Arrêter le serveur'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardDecoration(isDark),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _isServing
                      ? Icons.wifi_tethering
                      : _isSending
                      ? Icons.upload
                      : Icons.info_outline,
                  color: primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_status, style: TextStyle(color: textColor)),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 14),
          Text(
            'Quiz disponibles (${_quizzes.length})',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          if (_quizzes.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(isDark),
              child: Text(
                'Aucun quiz trouvé. Créez un quiz puis revenez ici.',
                style: TextStyle(color: secondaryTextColor),
              ),
            )
          else
            ..._quizzes.map((quiz) {
              final isActive = _isServing && _activeQuiz?.id == quiz.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: _cardDecoration(isDark),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primaryColor.withValues(alpha: 0.18),
                    child: Icon(Icons.quiz, color: primaryColor),
                  ),
                  title: Text(
                    quiz.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    '${quiz.questionCount} questions • ${quiz.difficulty}',
                    style: TextStyle(color: secondaryTextColor, fontSize: 12),
                  ),
                  trailing: ElevatedButton.icon(
                    onPressed: _isSending
                        ? null
                        : () => _startServerForQuiz(quiz),
                    icon: Icon(isActive ? Icons.hourglass_top : Icons.send),
                    label: Text(isActive ? 'En attente' : 'Envoyer'),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
