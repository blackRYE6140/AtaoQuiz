# AtaoQuiz
Ataovy lalao ny fianarana, amin'ny AtaoQuiz.

AtaoQuiz est une application mobile Flutter pour apprendre depuis des PDF, generer des quiz avec IA et suivre la progression locale, y compris en mode reseau local Wi-Fi.

## Sommaire
1. Vision
2. Etat du projet
3. Fonctionnalites
4. Architecture du code
5. Stack technique
6. Installation et demarrage
7. Configuration IA (`.env`)
8. Authentification et securite
9. Scripts utiles
10. Documentation complementaire

## 1. Vision
AtaoQuiz centralise l'experience d'apprentissage:
- lecture de supports PDF
- generation de quiz assistee par IA
- entrainement et suivi local
- scenarios challenge avec ou sans reseau

## 2. Etat du projet
- Statut: developpement actif
- Version app: `1.0.0+1`
- Cible principale configuree: Android
- Langue UI principale: francais

## 3. Fonctionnalites

### 3.1 Fonctionnalites disponibles
1. Gestion locale des quiz/resultats via `SharedPreferences`.
2. Import et lecture de documents PDF.
3. Generation de quiz via l'API Gemini.
4. Ecran de jeu QCM avec score et temps de completion.
5. Theme clair/sombre avec palette adaptee.
6. Authentification systeme Android (biometrie + verrou appareil).
7. Reverrouillage controle au retour en foreground (selon etat ecran OFF).
8. Detection de changement de configuration de securite Android.
9. Transfert local de quiz via Wi-Fi (QR code ou IP/port).
10. Challenge entre amis (mode Wi-Fi): creation/lancement reserves a l'hote.
11. Challenge avec chrono (mode personnel): fin automatique quand le temps expire.
12. Demarrage synchronise en reseau avec compte a rebours.
13. Classement live et global (points, niveaux, victoires, stats).
14. Profil joueur unique (nom + avatar/photo) synchronise dans home/challenge/classement.
15. Ecran `Mes Scores` avec historiques separes: quiz, defis amis, defis chrono.

### 3.2 Fonctionnalites en preparation
1. Durcissement securite transfert local (authentification/chiffrement applicatif).
2. Synchronisation cloud (ex: Firebase).

## 4. Architecture du code

### 4.1 Vue d'ensemble
L'application est organisee autour de:
1. UI Flutter
2. Services metiers (auth, stockage, profil, challenge, transfert, IA)
3. Configuration plateforme Android

### 4.2 Structure des dossiers (`lib/`)
```text
lib/
  main.dart
  components/
    home_components.dart
    profile_avatar.dart
  screens/
    authentication/
      first_time_setup_screen.dart
      system_auth_screen.dart
      system_auth_manage_screen.dart
    challenge/
      challenge_center_screen.dart
      challenge_sessions_screen.dart
      challenge_detail_screen.dart
      leaderboard_screen.dart
    generatequiz/
      generate_quiz_screen.dart
      quiz_list_screen.dart
      play_quiz_screen.dart
    pdf/
      pdf_list_screen.dart
      pdf_reader_screen.dart
    scores/
      my_scores_screen.dart
    transfer_quiz/
      transfer_quiz_screen.dart
      receive_quiz_screen.dart
      send_quiz_screen.dart
      qr_scanner_screen.dart
    home_screen.dart
    profile_screen.dart
    settings_screen.dart
    splash_screen.dart
  services/
    challenge_service.dart
    gemini_service.dart
    quiz_transfer_service.dart
    storage_service.dart
    system_auth_service.dart
    user_profile_service.dart
  theme/
    colors.dart
```

### 4.3 Responsabilites principales
- `lib/main.dart`: bootstrap app, routes, themes, comportement global scroll/lock.
- `lib/services/system_auth_service.dart`: logique auth locale Android.
- `lib/services/gemini_service.dart`: generation quiz via API Gemini.
- `lib/services/storage_service.dart`: persistance quiz/resultats locaux.
- `lib/services/user_profile_service.dart`: profil unique (nom, avatar, photo, etat setup).
- `lib/services/challenge_service.dart`: sessions challenge, ranking, points/niveaux.
- `lib/services/quiz_transfer_service.dart`: connexion Wi-Fi, transfert quiz, challenge live.

## 5. Stack technique
- Flutter / Dart
- `local_auth` pour l'authentification locale
- `shared_preferences` pour le stockage local
- `pdfx` et `flutter_pdfview` pour PDF
- `http` pour l'appel API Gemini
- `flutter_dotenv` pour la cle API
- `qr_flutter` + `mobile_scanner` pour QR et connexion inter-appareils
- `file_picker` pour import d'image profil

## 6. Installation et demarrage

### 6.1 Prerequis
1. Flutter SDK installe
2. SDK Android configure
3. Appareil Android ou emulateur

### 6.2 Installation
```bash
flutter pub get
```

### 6.3 Lancer l'application
```bash
flutter run
```

## 7. Configuration IA (`.env`)
Creer/mettre a jour `.env` a la racine:

```env
GEMINI_API_KEY=VOTRE_CLE_API
```

Sans cle valide, la generation IA ne fonctionne pas.

## 8. Authentification et securite
Le projet utilise l'authentification systeme Android.

Methodes prises en charge:
- biometrie
- verrou appareil (PIN/schema/mot de passe)

Points importants:
1. desactivation de la securite app soumise a re-authentification
2. gestion activation/desactivation depuis l'ecran de gestion
3. configuration Android requise: `FlutterFragmentActivity`, permissions biometrie, themes AppCompat

## 9. Scripts utiles
```bash
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release --split-per-abi
```

## 10. Documentation complementaire
- `AUTH_SYSTEM_DOCUMENTATION.md`
- `README_TRANSFERT_QUIZ.md`
- `README_CLASSEMENT_CHALLENGE.md`
- `README_PROFIL_SCORES.md`

Ces documents detaillent les flux techniques de securite, transfert Wi-Fi, challenge/classement, profil et historiques de scores.
