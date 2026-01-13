import 'package:atao_quiz/screens/generatequiz/play_quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:atao_quiz/services/storage_service.dart';
import 'package:atao_quiz/services/gemini_service.dart';
import 'package:flutter/services.dart';

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
          MaterialPageRoute(
            builder: (context) => PlayQuizScreen(quiz: quiz),
          ),
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
          questions.add(Question(
            text: currentQuestion,
            options: List.from(currentOptions),
            correctIndex: correctIndex,
          ));
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
            case 'A': correctIndex = 0; break;
            case 'B': correctIndex = 1; break;
            case 'C': correctIndex = 2; break;
            case 'D': correctIndex = 3; break;
          }
        }
      }
      // Détecter "Réponse correcte:"
      else if (line.toLowerCase().contains('réponse correcte')) {
        final match = RegExp(r'[A-D]').firstMatch(line.toUpperCase());
        if (match != null) {
          switch (match.group(0)) {
            case 'A': correctIndex = 0; break;
            case 'B': correctIndex = 1; break;
            case 'C': correctIndex = 2; break;
            case 'D': correctIndex = 3; break;
          }
        }
      }
    }
    
    // Ajouter la dernière question
    if (currentQuestion.isNotEmpty && 
        currentOptions.length == 4 && 
        correctIndex != null) {
      questions.add(Question(
        text: currentQuestion,
        options: List.from(currentOptions),
        correctIndex: correctIndex,
      ));
    }
    
    return questions;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Générer un Quiz'),
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
            // Titre du quiz
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Titre du quiz',
                hintText: 'Ex: Quiz sur l\'histoire de France',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.title),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Zone de contenu texte
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contenu du quiz',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    TextField(
                      controller: _contentController,
                      maxLines: 10,
                      minLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Collez ou écrivez ici le contenu sur lequel baser le quiz...\n\nExemple :\nLa Révolution française a commencé en 1789. La Déclaration des droits de l\'homme et du citoyen a été adoptée en 1789. Napoléon Bonaparte est devenu empereur en 1804.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDark 
                            ? Colors.grey.shade900 
                            : Colors.grey.shade50,
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Le quiz sera généré à partir de ce texte',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    
                    // Bouton pour coller du texte
                    if (_contentController.text.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.paste),
                          label: const Text('Coller depuis le presse-papier'),
                          onPressed: () async {
                            final clipboardData = await Clipboard.getData('text/plain');
                            if (clipboardData != null && clipboardData.text != null) {
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
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paramètres du quiz',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Difficulté
                    DropdownButtonFormField<String>(
                      value: _difficulty,
                      decoration: InputDecoration(
                        labelText: 'Difficulté',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.bolt),
                      ),
                      items: _difficulties.map((diff) {
                        return DropdownMenuItem(
                          value: diff,
                          child: Text(
                            diff[0].toUpperCase() + diff.substring(1),
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black,
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
                      value: _questionCount,
                      decoration: InputDecoration(
                        labelText: 'Nombre de questions',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.format_list_numbered),
                      ),
                      items: _questionCounts.map((count) {
                        return DropdownMenuItem(
                          value: count,
                          child: Text('$count questions'),
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
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                ),
              ),
            
            const SizedBox(height: 30),
            
            // Bouton de génération
            ElevatedButton.icon(
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_isLoading ? 'Génération en cours...' : 'Générer le Quiz'),
              onPressed: _isLoading ? null : _generateQuiz,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
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