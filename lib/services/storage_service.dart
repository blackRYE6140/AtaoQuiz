import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Quiz {
  final String id;
  final String title;
  final String pdfFileName;
  final String difficulty;
  final int questionCount;
  final DateTime createdAt;
  final List<Question> questions;
  final String origin; // local | transfer
  final DateTime? receivedAt;
  int? score; // Score obtenu (null si pas encore joué)
  DateTime? playedAt;

  Quiz({
    required this.id,
    required this.title,
    required this.pdfFileName,
    required this.difficulty,
    required this.questionCount,
    required this.createdAt,
    required this.questions,
    this.origin = 'local',
    this.receivedAt,
    this.score,
    this.playedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'pdfFileName': pdfFileName,
      'difficulty': difficulty,
      'questionCount': questionCount,
      'createdAt': createdAt.toIso8601String(),
      'questions': questions.map((q) => q.toJson()).toList(),
      'origin': origin,
      'receivedAt': receivedAt?.toIso8601String(),
      'score': score,
      'playedAt': playedAt?.toIso8601String(),
    };
  }

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'],
      title: json['title'],
      pdfFileName: json['pdfFileName'],
      difficulty: json['difficulty'],
      questionCount: json['questionCount'],
      createdAt: DateTime.parse(json['createdAt']),
      questions: (json['questions'] as List)
          .map((q) => Question.fromJson(q))
          .toList(),
      origin: json['origin'] ?? 'local',
      receivedAt: json['receivedAt'] != null
          ? DateTime.parse(json['receivedAt'])
          : null,
      score: json['score'],
      playedAt: json['playedAt'] != null
          ? DateTime.parse(json['playedAt'])
          : null,
    );
  }

  bool get isTransferred => origin == 'transfer';

  Quiz copyWith({
    String? id,
    String? title,
    String? pdfFileName,
    String? difficulty,
    int? questionCount,
    DateTime? createdAt,
    List<Question>? questions,
    String? origin,
    DateTime? receivedAt,
    int? score,
    bool clearScore = false,
    DateTime? playedAt,
    bool clearPlayedAt = false,
  }) {
    return Quiz(
      id: id ?? this.id,
      title: title ?? this.title,
      pdfFileName: pdfFileName ?? this.pdfFileName,
      difficulty: difficulty ?? this.difficulty,
      questionCount: questionCount ?? this.questionCount,
      createdAt: createdAt ?? this.createdAt,
      questions: questions ?? this.questions,
      origin: origin ?? this.origin,
      receivedAt: receivedAt ?? this.receivedAt,
      score: clearScore ? null : (score ?? this.score),
      playedAt: clearPlayedAt ? null : (playedAt ?? this.playedAt),
    );
  }
}

class Question {
  final String text;
  final List<String> options;
  final int correctIndex;
  int? selectedIndex; // Réponse choisie par l'utilisateur

  Question({
    required this.text,
    required this.options,
    required this.correctIndex,
    this.selectedIndex,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'options': options,
      'correctIndex': correctIndex,
      'selectedIndex': selectedIndex,
    };
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      text: json['text'],
      options: List<String>.from(json['options']),
      correctIndex: json['correctIndex'],
      selectedIndex: json['selectedIndex'],
    );
  }

  bool get isCorrect => selectedIndex == correctIndex;
}

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _quizzesKey = 'saved_quizzes';

  Future<void> initialize() async {
    // Initialisation si nécessaire
  }

  Future<void> saveQuiz(Quiz quiz) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> existingQuizzes = prefs.getStringList(_quizzesKey) ?? [];

    // Supprimer l'ancienne version si elle existe
    existingQuizzes.removeWhere((q) {
      final quizJson = jsonDecode(q);
      return quizJson['id'] == quiz.id;
    });

    // Ajouter le nouveau quiz
    existingQuizzes.add(jsonEncode(quiz.toJson()));

    await prefs.setStringList(_quizzesKey, existingQuizzes);
  }

  Future<List<Quiz>> getQuizzes() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> quizzesJson = prefs.getStringList(_quizzesKey) ?? [];

    return quizzesJson
        .map((json) {
          try {
            return Quiz.fromJson(jsonDecode(json));
          } catch (e) {
            return null;
          }
        })
        .whereType<Quiz>()
        .toList();
  }

  Future<void> deleteQuiz(String quizId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> existingQuizzes = prefs.getStringList(_quizzesKey) ?? [];

    existingQuizzes.removeWhere((q) {
      try {
        final quizJson = jsonDecode(q);
        return quizJson['id'] == quizId;
      } catch (e) {
        return false;
      }
    });

    await prefs.setStringList(_quizzesKey, existingQuizzes);
  }

  Future<void> saveQuizResult(String quizId, int score) async {
    final quizzes = await getQuizzes();

    for (var quiz in quizzes) {
      if (quiz.id == quizId) {
        quiz.score = score;
        quiz.playedAt = DateTime.now();
        await saveQuiz(quiz);
        break;
      }
    }
  }
}
