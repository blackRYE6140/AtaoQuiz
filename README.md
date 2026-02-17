# AtaoQuiz
Ataovy lalao ny fianarana, amin'ny AtaoQuiz.

AtaoQuiz est une application mobile Flutter pour apprendre à partir de documents PDF, générer des quiz avec IA et réviser de façon interactive, y compris avec des scénarios hors ligne.

## Sommaire
1. Vision
2. État du projet
3. Fonctionnalités
4. Architecture du code
5. Stack technique
6. Installation et démarrage
7. Configuration IA (`.env`)
8. Authentification et sécurité
9. Scripts utiles
10. Documentation complémentaire

## 1. Vision
AtaoQuiz vise à centraliser l'expérience d'apprentissage dans une seule application:
- lecture de supports PDF
- génération de quiz assistée par IA
- entraînement et suivi local
- accès possible même avec une connectivité limitée

## 2. État du projet
- Statut: en développement actif
- Version application: `1.0.0+1`
- Cible principale actuellement configurée: Android
- Langue UI principale: français

## 3. Fonctionnalités

### 3.1 Fonctionnalités disponibles
1. Gestion locale des quiz et des résultats (SharedPreferences)
2. Import et lecture de documents PDF
3. Génération de quiz via l'API Gemini
4. Écran de jeu de quiz (QCM) avec score
5. Thème clair/sombre
6. Authentification système Android (biométrie + verrou appareil)
7. Reverrouillage automatique au retour depuis l'arrière-plan
8. Détection de changement de configuration de sécurité Android
9. Transfert local de quiz entre deux téléphones (QR code ou IP/port)

### 3.2 Fonctionnalités en préparation
1. Durcissement sécurité du transfert local (authentification/chiffrement)
2. Compétition locale entre utilisateurs
3. Synchronisation cloud (ex: Firebase)

## 4. Architecture du code

### 4.1 Vue d'ensemble
L'application est organisée autour de trois blocs:
1. UI (écrans Flutter)
2. Services métiers (auth, stockage, génération IA)
3. Configuration plateforme (Android)

### 4.2 Structure des dossiers (`lib/`)
```text
lib/
  main.dart
  components/
    home_components.dart
  screens/
    authentication/
      first_time_setup_screen.dart
      system_auth_screen.dart
      system_auth_manage_screen.dart
    generatequiz/
      generate_quiz_screen.dart
      quiz_list_screen.dart
      play_quiz_screen.dart
    pdf/
      pdf_list_screen.dart
      pdf_reader_screen.dart
    home_screen.dart
    profile_screen.dart
    settings_screen.dart
    splash_screen.dart
  services/
    gemini_service.dart
    storage_service.dart
    system_auth_service.dart
  theme/
    colors.dart
```

### 4.3 Responsabilités principales
- `lib/main.dart`: bootstrap app, routes, thème, guard de verrouillage au cycle de vie
- `lib/services/system_auth_service.dart`: logique d'authentification locale
- `lib/services/gemini_service.dart`: appel API Gemini pour générer le contenu quiz
- `lib/services/storage_service.dart`: persistance locale des quiz/résultats

## 5. Stack technique
- Flutter / Dart
- `local_auth` pour l'authentification locale
- `shared_preferences` pour le stockage local
- `pdfx` et `flutter_pdfview` pour PDF
- `http` pour l'appel API Gemini
- `flutter_dotenv` pour la clé API

## 6. Installation et démarrage

### 6.1 Prérequis
1. Flutter SDK installé
2. SDK Android configuré
3. Un appareil Android ou émulateur

### 6.2 Installation
```bash
flutter pub get
```

### 6.3 Lancer l'application
```bash
flutter run
```

## 7. Configuration IA (`.env`)
Créer ou compléter le fichier `.env` à la racine:

```env
GEMINI_API_KEY=VOTRE_CLE_API
```

Sans clé valide, la génération IA de quiz ne fonctionnera pas.

## 8. Authentification et sécurité
Le projet utilise l'authentification système Android.
Méthodes prises en charge:
- biométrie
- verrou appareil (PIN, schéma, mot de passe)

Points importants:
1. la désactivation de la sécurité dans l'app demande une ré-authentification
2. la sécurité peut être activée/réactivée depuis l'écran de gestion
3. la configuration Android doit inclure `FlutterFragmentActivity`, permissions biométriques et thèmes AppCompat

## 9. Scripts utiles
```bash
flutter analyze
flutter test
flutter build apk --debug
```

## 10. Documentation complémentaire
- `AUTH_SYSTEM_DOCUMENTATION.md`
- `AUTHENTICATION_SYSTEM.md`
- `README_TRANSFERT_QUIZ.md`

Ces documents détaillent l'architecture auth, les flux de sécurité, le transfert local de quiz et les configurations Android requises.
