import 'package:flutter/material.dart';
import 'package:atao_quiz/services/storage_service.dart';
import 'package:atao_quiz/theme/colors.dart';

class PlayQuizScreen extends StatefulWidget {
  final Quiz quiz;
  
  const PlayQuizScreen({super.key, required this.quiz});

  @override
  State<PlayQuizScreen> createState() => _PlayQuizScreenState();
}

class _PlayQuizScreenState extends State<PlayQuizScreen> {
  int _currentQuestionIndex = 0;
  bool _quizCompleted = false;
  int _score = 0;
  final List<bool> _questionResults = [];

  @override
  void initState() {
    super.initState();
    // Initialiser les résultats
    _questionResults.addAll(List.filled(widget.quiz.questions.length, false));
  }

  void _selectAnswer(int optionIndex) {
    if (_quizCompleted) return;
    
    setState(() {
      // Enregistrer la réponse
      widget.quiz.questions[_currentQuestionIndex].selectedIndex = optionIndex;
      
      // Vérifier si la réponse est correcte
      final isCorrect = optionIndex == 
          widget.quiz.questions[_currentQuestionIndex].correctIndex;
      
      _questionResults[_currentQuestionIndex] = isCorrect;
      if (isCorrect) _score++;
      
      // Passer à la question suivante ou terminer le quiz
      if (_currentQuestionIndex < widget.quiz.questions.length - 1) {
        _currentQuestionIndex++;
      } else {
        _quizCompleted = true;
        _saveQuizResult();
      }
    });
  }

  Future<void> _saveQuizResult() async {
    final storageService = StorageService();
    await storageService.saveQuizResult(widget.quiz.id, _score);
  }

  void _goToQuestion(int index) {
    if (index >= 0 && index < widget.quiz.questions.length) {
      setState(() {
        _currentQuestionIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentQuestion = widget.quiz.questions[_currentQuestionIndex];
    final totalQuestions = widget.quiz.questions.length;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quiz.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Chip(
              backgroundColor: isDark ? AppColors.darkCard : Colors.blue.shade100,
              label: Text(
                'Score: $_score/$totalQuestions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.blue.shade800,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progression
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / totalQuestions,
            backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            color: AppColors.primaryBlue,
            minHeight: 4,
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${_currentQuestionIndex + 1}/$totalQuestions',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Chip(
                  label: Text(
                    widget.quiz.difficulty.toUpperCase(),
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: _getDifficultyColor(widget.quiz.difficulty),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        currentQuestion.text,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Options
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: currentQuestion.options.length,
                    itemBuilder: (context, index) {
                      final option = currentQuestion.options[index];
                      final isSelected = currentQuestion.selectedIndex == index;
                      final isCorrect = index == currentQuestion.correctIndex;
                      
                      Color? cardColor;
                      if (_quizCompleted && isSelected && !isCorrect) {
                        cardColor = Colors.red.shade100;
                      } else if (_quizCompleted && isCorrect) {
                        cardColor = Colors.green.shade100;
                      } else if (isSelected) {
                        cardColor = Colors.blue.shade100;
                      }
                      
                      return GestureDetector(
                        onTap: () => _selectAnswer(index),
                        child: Card(
                          color: cardColor,
                          elevation: isSelected ? 4 : 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getOptionColor(index, isSelected, isCorrect),
                              child: Text(
                                String.fromCharCode(65 + index), // A, B, C, D
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : 
                                        (isDark ? Colors.black : Colors.black),
                                ),
                              ),
                            ),
                            title: Text(
                              option,
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(
                                    isCorrect ? Icons.check : Icons.close,
                                    color: isCorrect ? Colors.green : Colors.red,
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  // Navigation entre questions
                  if (totalQuestions > 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(totalQuestions, (index) {
                            final isCurrent = index == _currentQuestionIndex;
                            final isAnswered = widget.quiz.questions[index].selectedIndex != null;
                            final isCorrect = _questionResults[index];
                            
                            return GestureDetector(
                              onTap: () => _goToQuestion(index),
                              child: Container(
                                width: 40,
                                height: 40,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? AppColors.primaryBlue
                                      : isAnswered
                                          ? isCorrect
                                              ? Colors.green
                                              : Colors.red
                                          : isDark
                                              ? Colors.grey.shade800
                                              : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isCurrent || isAnswered
                                          ? Colors.white
                                          : isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  
                  // Résultats finaux
                  if (_quizCompleted)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(
                                _score >= totalQuestions * 0.7
                                    ? Icons.emoji_events
                                    : _score >= totalQuestions * 0.5
                                        ? Icons.check_circle
                                        : Icons.refresh,
                                size: 60,
                                color: _score >= totalQuestions * 0.7
                                    ? Colors.amber
                                    : _score >= totalQuestions * 0.5
                                        ? Colors.green
                                        : Colors.blue,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Quiz Terminé!',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Score final: $_score/$totalQuestions',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.home),
                                    label: const Text('Accueil'),
                                    onPressed: () {
                                      Navigator.popUntil(
                                        context,
                                        ModalRoute.withName('/home'),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 16),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.restart_alt),
                                    label: const Text('Recommencer'),
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PlayQuizScreen(quiz: widget.quiz),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getOptionColor(int index, bool isSelected, bool isCorrect) {
    if (isSelected) {
      if (_quizCompleted) {
        return isCorrect ? Colors.green : Colors.red;
      }
      return AppColors.primaryBlue;
    }
    return isDark ? Colors.grey.shade700 : Colors.grey.shade300;
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'facile':
        return Colors.green.shade100;
      case 'difficile':
        return Colors.red.shade100;
      default:
        return Colors.blue.shade100;
    }
  }
  
  bool get isDark => Theme.of(context).brightness == Brightness.dark;
}