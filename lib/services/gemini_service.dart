import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  String? _apiKey;
  bool _isInitialized = false;
  
  // Choix du modèle
  final String _modelName = 'gemini-2.5-flash';

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _apiKey = dotenv.env['GEMINI_API_KEY'];
      
      if (_apiKey == null || _apiKey!.isEmpty) {
        print('⚠️ GEMINI_API_KEY est vide dans .env');
      } else {
        print('✅ GeminiService initialisé avec clé API');
        print('🤖 Modèle sélectionné: $_modelName');
        await _testConnection();
      }
      _isInitialized = true;
    } catch (e) {
      print('⚠️ Erreur initialisation GeminiService: $e');
      _apiKey = null;
      _isInitialized = true;
    }
  }

  Future<void> _testConnection() async {
    try {
      final url = '$_baseUrl/models?key=$_apiKey';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = data['models'] as List;
        print('✅ Connexion API réussie');
        
        // Vérifier si notre modèle est disponible
        final modelAvailable = models.any((m) => 
            m['name'].toString() == 'models/$_modelName' &&
            m['supportedGenerationMethods'] != null &&
            (m['supportedGenerationMethods'] as List).contains('generateContent'));
        
        if (!modelAvailable) {
          print('⚠️ Modèle "$_modelName" non disponible');
          // Lister les modèles disponibles
          print('📋 Modèles disponibles pour generateContent:');
          for (var model in models) {
            final name = model['name'].toString().replaceFirst('models/', '');
            final supportsGenerate = model['supportedGenerationMethods'] != null &&
                (model['supportedGenerationMethods'] as List).contains('generateContent');
            if (supportsGenerate) {
              print('   - $name');
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ Erreur test connexion: $e');
    }
  }

  Future<String> generateQuizFromContent({
    required String content,
    required String difficulty,
    required int questionCount,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('API Gemini non configurée. Vérifiez votre fichier .env');
    }
    
    try {
      final url = '$_baseUrl/models/$_modelName:generateContent?key=$_apiKey';
      final prompt = _buildQuizPrompt(content, difficulty, questionCount);
      
      print('🔄 Envoi de la requête à Gemini (modèle: $_modelName)...');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {
            'temperature': _getTemperatureForDifficulty(difficulty),
            'maxOutputTokens': 4000,
            'topP': 0.95,
            'topK': 40,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final generatedText = data['candidates'][0]['content']['parts'][0]['text'];
        print('✅ Quiz généré (${generatedText.length} caractères)');
        return generatedText;
      } else {
        final error = jsonDecode(response.body)['error'];
        throw Exception('Erreur Gemini: ${error['message']}');
      }
    } catch (e) {
      print('❌ Erreur génération quiz: $e');
      rethrow;
    }
  }

  String _buildQuizPrompt(String content, String difficulty, int questionCount) {
    // Description de la difficulté intégrée directement
    final difficultyDescription = switch (difficulty.toLowerCase()) {
      'facile' => 'questions directes, réponses évidentes dans le texte',
      'difficile' => 'questions complexes nécessitant analyse ou inférence',
      _ => 'mélange équilibré de questions simples et modérées',
    };
    
    return """Tu es un expert en création de quiz pédagogiques. Crée un quiz à choix multiples.

FORMAT EXACT REQUIS :
Q1: [Question complète]
A) [Option A]
B) [Option B]
C) [Option C]
D) [Option D]
Réponse: [Lettre A/B/C/D]

Q2: [Question complète]
A) [Option A]
B) [Option B]
C) [Option C]
D) [Option D]
Réponse: [Lettre A/B/C/D]

Continue pour $questionCount questions.

CONTENU DE RÉFÉRENCE :
$content

INSTRUCTIONS :
1. Génère EXACTEMENT $questionCount questions
2. Difficulté: $difficulty ($difficultyDescription)
3. 4 options par question, une seule correcte
4. Options incorrectes plausibles mais fausses
5. Pas de texte supplémentaire avant/après
6. Format strict comme dans l'exemple

Génère le quiz maintenant.""";
  }

  double _getTemperatureForDifficulty(String difficulty) {
    return switch (difficulty.toLowerCase()) {
      'facile' => 0.1,
      'difficile' => 0.6,
      _ => 0.4,
    };
  }
}