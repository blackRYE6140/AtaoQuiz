import 'package:atao_quiz/screens/generatequiz/play_quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:atao_quiz/services/storage_service.dart';
import 'package:atao_quiz/services/gemini_service.dart';
import 'package:flutter/services.dart';
import 'package:atao_quiz/theme/colors.dart';

class GenerateQuizScreen extends StatefulWidget {
  const GenerateQuizScreen({super.key});

  @override
  State<GenerateQuizScreen> createState() => _GenerateQuizScreenState();
}

class _GenerateQuizScreenState extends State<GenerateQuizScreen> {
  bool _isLoading = false;
  String? _error;

  // Paramètres du quiz
  String _difficulty = 'normal';
  int _questionCount = 5;
  final List<String> _difficulties = ['facile', 'normal', 'difficile'];
  final List<int> _questionCounts = [3, 5, 10, 15];

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _geminiService = GeminiService();
  final _storageService = StorageService();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _generateQuiz() async {
    if (_titleController.text.trim().isEmpty) {
      setState(() {
        _error = 'Veuillez donner un titre au quiz';
      });
      return;
    }

    if (_contentController.text.trim().isEmpty) {
      setState(() {
        _error = 'Veuillez entrer ou coller du contenu';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Appeler Gemini API pour générer le quiz
      final response = await _geminiService.generateQuizFromContent(
        content: _contentController.text.trim(),
        difficulty: _difficulty,
        questionCount: _questionCount,
      );

      // Parser la réponse de Gemini
      final questions = _parseGeminiResponse(response);

      if (questions.isEmpty) {
        throw Exception('Aucune question valide générée');
      }

      // Créer l'objet Quiz
      final quiz = Quiz(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        pdfFileName: 'Contenu texte', // Plus de nom de fichier PDF
        difficulty: _difficulty,
        questionCount: _questionCount,
        createdAt: DateTime.now(),
        questions: questions,
      );

      // Sauvegarder le quiz
      await _storageService.saveQuiz(quiz);

      // Naviguer vers l'écran de jeu du quiz
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => PlayQuizScreen(quiz: quiz)),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur de génération: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Question> _parseGeminiResponse(String response) {
    final List<Question> questions = [];
    final lines = response.split('\n');

    String currentQuestion = '';
    List<String> currentOptions = [];
    int? correctIndex;

    for (var line in lines) {
      line = line.trim();

      // Détecter une nouvelle question
      if (line.startsWith('Q') && line.contains(':')) {
        // Sauvegarder la question précédente si elle existe
        if (currentQuestion.isNotEmpty &&
            currentOptions.length == 4 &&
            correctIndex != null) {
          questions.add(
            Question(
              text: currentQuestion,
              options: List.from(currentOptions),
              correctIndex: correctIndex,
            ),
          );
        }

        // Réinitialiser pour la nouvelle question
        final colonIndex = line.indexOf(':');
        currentQuestion = line.substring(colonIndex + 1).trim();
        currentOptions.clear();
        correctIndex = null;
      }
      // Détecter les options (A), B), C), D))
      else if (RegExp(r'^[A-D]\)').hasMatch(line)) {
        final optionText = line.substring(2).trim();
        if (optionText.isNotEmpty) {
          currentOptions.add(optionText);
        }
      }
      // Détecter la réponse correcte
      else if (line.toLowerCase().startsWith('réponse:')) {
        final answerPart = line.substring(8).trim();
        if (answerPart.isNotEmpty) {
          switch (answerPart.toUpperCase()) {
            case 'A':
              correctIndex = 0;
              break;
            case 'B':
              correctIndex = 1;
              break;
            case 'C':
              correctIndex = 2;
              break;
            case 'D':
              correctIndex = 3;
              break;
          }
        }
      }
      // Détecter "Réponse correcte:"
      else if (line.toLowerCase().contains('réponse correcte')) {
        final match = RegExp(r'[A-D]').firstMatch(line.toUpperCase());
        if (match != null) {
          switch (match.group(0)) {
            case 'A':
              correctIndex = 0;
              break;
            case 'B':
              correctIndex = 1;
              break;
            case 'C':
              correctIndex = 2;
              break;
            case 'D':
              correctIndex = 3;
              break;
          }
        }
      }
    }

    // Ajouter la dernière question
    if (currentQuestion.isNotEmpty &&
        currentOptions.length == 4 &&
        correctIndex != null) {
      questions.add(
        Question(
          text: currentQuestion,
          options: List.from(currentOptions),
          correctIndex: correctIndex,
        ),
      );
    }

    return questions;
  }

  BoxDecoration _surfaceDecoration({
    required bool isDark,
    required Color primaryColor,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      border: Border.all(color: primaryColor.withValues(alpha: 0.18)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required bool isDark,
    required Color primaryColor,
    required IconData icon,
    String? labelText,
    String? hintText,
  }) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.20)),
    );
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: Icon(icon, color: primaryColor),
      filled: true,
      fillColor: isDark
          ? AppColors.darkBackground.withValues(alpha: 0.60)
          : AppColors.lightBackground,
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.75)),
      ),
      labelStyle: TextStyle(
        fontFamily: 'Poppins',
        color: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
      ),
      hintStyle: TextStyle(
        fontFamily: 'Poppins',
        color: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
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
    final buttonForegroundColor = isDark ? Colors.black : Colors.white;
    final isContentEmpty = _contentController.text.trim().isEmpty;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: primaryColor),
        title: Text(
          'Générer un Quiz',
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: _surfaceDecoration(
                isDark: isDark,
                primaryColor: primaryColor,
              ),
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _titleController,
                style: TextStyle(fontFamily: 'Poppins', color: textColor),
                decoration: _fieldDecoration(
                  isDark: isDark,
                  primaryColor: primaryColor,
                  icon: Icons.title,
                  labelText: 'Titre du quiz',
                  hintText: 'Ex: Quiz - Bases du développement web',
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Zone de contenu texte
            Container(
              decoration: _surfaceDecoration(
                isDark: isDark,
                primaryColor: primaryColor,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contenu du quiz',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: _contentController,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(fontFamily: 'Poppins', color: textColor),
                      maxLines: 10,
                      minLines: 5,
                      decoration:
                          _fieldDecoration(
                            isDark: isDark,
                            primaryColor: primaryColor,
                            icon: Icons.article_outlined,
                            hintText:
                                'Collez ou écrivez ici le contenu du cours...\n\nExemple :\nEn programmation orientée objet, une classe définit les attributs et méthodes d\'un objet. En Java, l\'héritage permet de réutiliser du code avec extends. Le polymorphisme permet d\'appeler la même méthode sur des objets de types différents.',
                          ).copyWith(
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Le quiz sera généré à partir de ce texte',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),

                    // Bouton pour coller du texte
                    if (isContentEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: BorderSide(
                              color: primaryColor.withValues(alpha: 0.35),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Icon(Icons.paste, color: primaryColor),
                          label: const Text(
                            'Coller depuis le presse-papier',
                            style: TextStyle(fontFamily: 'Poppins'),
                          ),
                          onPressed: () async {
                            final clipboardData = await Clipboard.getData(
                              'text/plain',
                            );
                            if (clipboardData != null &&
                                clipboardData.text != null) {
                              setState(() {
                                _contentController.text = clipboardData.text!;
                              });
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Paramètres du quiz
            Container(
              decoration: _surfaceDecoration(
                isDark: isDark,
                primaryColor: primaryColor,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paramètres du quiz',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Difficulté
                    DropdownButtonFormField<String>(
                      initialValue: _difficulty,
                      dropdownColor: isDark
                          ? AppColors.darkCard
                          : AppColors.lightCard,
                      style: TextStyle(fontFamily: 'Poppins', color: textColor),
                      decoration: _fieldDecoration(
                        isDark: isDark,
                        primaryColor: primaryColor,
                        icon: Icons.bolt,
                        labelText: 'Difficulté',
                      ),
                      items: _difficulties.map((diff) {
                        return DropdownMenuItem(
                          value: diff,
                          child: Text(
                            diff[0].toUpperCase() + diff.substring(1),
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _difficulty = value!;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // Nombre de questions
                    DropdownButtonFormField<int>(
                      initialValue: _questionCount,
                      dropdownColor: isDark
                          ? AppColors.darkCard
                          : AppColors.lightCard,
                      style: TextStyle(fontFamily: 'Poppins', color: textColor),
                      decoration: _fieldDecoration(
                        isDark: isDark,
                        primaryColor: primaryColor,
                        icon: Icons.format_list_numbered,
                        labelText: 'Nombre de questions',
                      ),
                      items: _questionCounts.map((count) {
                        return DropdownMenuItem(
                          value: count,
                          child: Text(
                            '$count questions',
                            style: const TextStyle(fontFamily: 'Poppins'),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _questionCount = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Message d'erreur
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 30),

            // Bouton de génération
            ElevatedButton.icon(
              icon: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          buttonForegroundColor,
                        ),
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isLoading ? 'Génération en cours...' : 'Générer le Quiz',
                style: const TextStyle(fontFamily: 'Poppins'),
              ),
              onPressed: _isLoading ? null : _generateQuiz,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: primaryColor,
                foregroundColor: buttonForegroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
