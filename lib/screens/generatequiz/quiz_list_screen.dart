import 'package:atao_quiz/screens/generatequiz/generate_quiz_screen.dart';
import 'package:atao_quiz/screens/generatequiz/play_quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:atao_quiz/services/storage_service.dart';
import 'package:atao_quiz/theme/colors.dart';

class QuizListScreen extends StatefulWidget {
  const QuizListScreen({super.key});

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  List<Quiz> _quizzes = [];
  bool _isLoading = true;
  final _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }

  Future<void> _loadQuizzes() async {
    setState(() => _isLoading = true);
    try {
      final quizzes = await _storageService.getQuizzes();
      setState(() {
        _quizzes = quizzes;
        _isLoading = false;
      });
    } catch (e) {
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
      await _loadQuizzes();
    }
  }

  void _playQuiz(Quiz quiz) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayQuizScreen(quiz: quiz),
      ),
    ).then((_) => _loadQuizzes());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Quizzs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQuizzes,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GenerateQuizScreen(),
                ),
              ).then((_) => _loadQuizzes());
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _quizzes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.quiz,
                        size: 80,
                        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun quiz généré',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDark ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Générez votre premier quiz !',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Créer un quiz'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GenerateQuizScreen(),
                            ),
                          ).then((_) => _loadQuizzes());
                        },
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _quizzes.length,
                  itemBuilder: (context, index) {
                    final quiz = _quizzes[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getDifficultyColor(quiz.difficulty),
                          child: Text(
                            'Q',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.black : Colors.black,
                            ),
                          ),
                        ),
                        title: Text(
                          quiz.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '${quiz.questionCount} questions • ${quiz.difficulty} • ${quiz.pdfFileName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                              ),
                            ),
                            if (quiz.score != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.score,
                                      size: 14,
                                      color: quiz.score! >= quiz.questionCount * 0.7
                                          ? Colors.green
                                          : quiz.score! >= quiz.questionCount * 0.5
                                              ? Colors.orange
                                              : Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Score: ${quiz.score}/${quiz.questionCount}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: quiz.score! >= quiz.questionCount * 0.7
                                            ? Colors.green
                                            : quiz.score! >= quiz.questionCount * 0.5
                                                ? Colors.orange
                                                : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (quiz.score == null)
                              IconButton(
                                icon: Icon(
                                  Icons.play_arrow,
                                  color: AppColors.primaryBlue,
                                ),
                                onPressed: () => _playQuiz(quiz),
                              ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                              ),
                              onPressed: () => _deleteQuiz(quiz.id),
                            ),
                          ],
                        ),
                        onTap: () => _playQuiz(quiz),
                      ),
                    );
                  },
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