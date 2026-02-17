import 'package:atao_quiz/screens/generatequiz/quiz_list_screen.dart';
import 'package:atao_quiz/services/quiz_transfer_service.dart';
import 'package:atao_quiz/services/storage_service.dart';
import 'package:atao_quiz/theme/colors.dart';
import 'package:flutter/material.dart';

class ReceiveQuizScreen extends StatefulWidget {
  const ReceiveQuizScreen({super.key});

  @override
  State<ReceiveQuizScreen> createState() => _ReceiveQuizScreenState();
}

class _ReceiveQuizScreenState extends State<ReceiveQuizScreen> {
  final StorageService _storageService = StorageService();
  final QuizTransferService _transferService = QuizTransferService();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController(
    text: '${QuizTransferService.defaultPort}',
  );

  bool _isReceiving = false;
  String _status =
      'Entrez l\'IP du téléphone émetteur puis appuyez sur Recevoir.';
  String? _error;
  List<Quiz> _transferredQuizzes = [];

  @override
  void initState() {
    super.initState();
    _loadTransferredQuizzes();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadTransferredQuizzes() async {
    final quizzes = await _storageService.getQuizzes();
    final transferred = quizzes.where((quiz) => quiz.isTransferred).toList()
      ..sort((a, b) {
        final aDate = a.receivedAt ?? a.createdAt;
        final bDate = b.receivedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });

    if (!mounted) {
      return;
    }

    setState(() {
      _transferredQuizzes = transferred;
    });
  }

  int? _validatedPort() {
    final parsed = int.tryParse(_portController.text.trim());
    if (parsed == null || parsed < 1 || parsed > 65535) {
      return null;
    }
    return parsed;
  }

  Future<void> _receiveQuiz() async {
    final host = _hostController.text.trim();
    final port = _validatedPort();

    if (host.isEmpty) {
      _showMessage('Veuillez saisir une adresse IP.', isError: true);
      return;
    }
    if (port == null) {
      _showMessage('Port invalide.', isError: true);
      return;
    }

    setState(() {
      _isReceiving = true;
      _error = null;
      _status = 'Connexion à $host:$port...';
    });

    try {
      final receivedQuiz = await _transferService.receiveQuiz(
        host: host,
        port: port,
      );
      final preparedQuiz = await _prepareReceivedQuiz(receivedQuiz);
      await _storageService.saveQuiz(preparedQuiz);
      await _loadTransferredQuizzes();

      if (!mounted) {
        return;
      }

      setState(() {
        _isReceiving = false;
        _status = 'Quiz reçu: ${preparedQuiz.title}';
      });
      _showMessage('Quiz importé avec succès.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isReceiving = false;
        _error = 'Erreur de réception: $e';
        _status = 'La réception a échoué.';
      });
      _showMessage('Échec de la réception: $e', isError: true);
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

  void _openQuizList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QuizListScreen()),
    ).then((_) => _loadTransferredQuizzes());
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

  String _formatDate(DateTime dateTime) {
    final d = dateTime.day.toString().padLeft(2, '0');
    final m = dateTime.month.toString().padLeft(2, '0');
    final y = dateTime.year.toString();
    final h = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recevoir un quiz',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'IP du téléphone émetteur',
                  hintText: 'Ex: 192.168.1.12',
                  border: OutlineInputBorder(),
                  isDense: true,
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isReceiving ? null : _receiveQuiz,
                  icon: _isReceiving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isReceiving ? 'Réception...' : 'Recevoir'),
                ),
              ),
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
                _isReceiving ? Icons.sync : Icons.info_outline,
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
        Row(
          children: [
            Expanded(
              child: Text(
                'Quiz transférés (${_transferredQuizzes.length})',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _openQuizList,
              icon: const Icon(Icons.quiz),
              label: const Text('Mes Quiz'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_transferredQuizzes.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(isDark),
            child: Text(
              'Aucun quiz reçu pour le moment.',
              style: TextStyle(color: secondaryTextColor),
            ),
          )
        else
          ..._transferredQuizzes.map((quiz) {
            final date = quiz.receivedAt ?? quiz.createdAt;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: _cardDecoration(isDark),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: primaryColor.withValues(alpha: 0.18),
                  child: Icon(Icons.download_done, color: primaryColor),
                ),
                title: Text(
                  quiz.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  'Reçu le ${_formatDate(date)}',
                  style: TextStyle(color: secondaryTextColor, fontSize: 12),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: secondaryTextColor,
                ),
                onTap: _openQuizList,
              ),
            );
          }),
      ],
    );
  }
}
