# Documentation du système d'authentification AtaoQuiz

## 1) Objectif
Le système d'authentification d'AtaoQuiz s'appuie sur la sécurité native Android via `local_auth`.
L'application ne gère pas de PIN propriétaire. Elle utilise le verrouillage déjà configuré sur l'appareil:
- biométrie (empreinte, visage)
- verrou appareil (PIN, schéma, mot de passe)

## 2) Périmètre fonctionnel
Le système couvre:
- activation de la sécurité dans l'app
- déverrouillage à l'ouverture de l'app
- revérrouillage automatique au retour depuis l'arrière-plan
- détection de changement de configuration de sécurité Android
- désactivation sécurisée (avec ré-authentification)
- réactivation depuis la page de gestion

## 3) Fichiers principaux

### Services
- `lib/services/system_auth_service.dart`

### Écrans
- `lib/screens/authentication/first_time_setup_screen.dart`
- `lib/screens/authentication/system_auth_screen.dart`
- `lib/screens/authentication/system_auth_manage_screen.dart`
- `lib/screens/splash_screen.dart`

### Entrée app et verrouillage lifecycle
- `lib/main.dart`

### Android
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/example/atao_quiz/MainActivity.kt`
- `android/app/src/main/res/values/styles.xml`
- `android/app/src/main/res/values-night/styles.xml`
- `android/app/build.gradle.kts`

## 4) Méthodes détectées et limites techniques
`local_auth` ne donne pas le type exact du fallback appareil (PIN vs schéma vs mot de passe).
Donc l'app affiche volontairement un libellé générique:
- `Verrouillage appareil (PIN/Schéma/Mot de passe)`

Ce comportement est normal côté Android/`local_auth`.

## 5) Clés SharedPreferences
- `is_first_time_setup` (bool)
  - `true` par défaut: première configuration à faire
  - passe à `false` après activation de sécurité ou après "Ignorer"
- `system_auth_enabled` (bool)
  - active/désactive le verrouillage de l'app
- `device_lock_types` (List<String>)
  - types disponibles au moment de l'activation
- `last_security_hash` (String)
  - signature stable de config sécurité pour détecter les changements

## 6) Flux applicatif

### Premier lancement
1. `SplashScreen` lit `is_first_time_setup`.
2. Si `true`, route vers `/first-time-setup`.
3. Utilisateur peut:
   - activer la sécurité
   - ignorer pour le moment
4. Dans les deux cas, `is_first_time_setup` devient `false`.

### Lancements suivants
1. `SplashScreen` lit `system_auth_enabled`.
2. Si `true`, route vers `/system-auth`.
3. Si auth réussie, route vers `/home`.

### Retour depuis arrière-plan
`main.dart` observe le cycle de vie.
- sur `inactive/paused/hidden`: arme un verrou au prochain `resumed`
- sur `resumed`: si sécurité activée et route éligible, redirige vers `/system-auth`

Routes exclues du reverrouillage automatique:
- `/`
- `/first-time-setup`
- `/system-auth`

## 7) Changement de configuration Android
Au chargement de `/system-auth`, l'app compare la signature sécurité courante avec la signature stockée.

Si changement détecté:
1. l'auth app est désactivée
2. message explicite affiché
3. redirection forcée vers `/first-time-setup`

Ce mécanisme évite les boucles de verrouillage et force une reconfiguration propre.

## 8) Page "Gestion de la sécurité"
`SystemAuthManageScreen` permet:
- voir l'état actuel
- activer la sécurité
- désactiver la sécurité

Règles importantes:
- l'activation vérifie qu'un verrou Android existe réellement
- la désactivation exige une ré-authentification utilisateur
- la liste des méthodes affichées est rafraîchie à partir de l'état réel de l'appareil
- UI alignée avec les couleurs du thème de l'app (sans emoji)

## 9) Configuration Android obligatoire

### 9.1 Permissions
Dans `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
```

### 9.2 Activity
`local_auth` exige une `FragmentActivity`.
Dans `android/app/src/main/kotlin/com/example/atao_quiz/MainActivity.kt`:
```kotlin
class MainActivity : FlutterFragmentActivity()
```

### 9.3 Thème Android (compatibilité prompt biométrique)
Dans:
- `android/app/src/main/res/values/styles.xml`
- `android/app/src/main/res/values-night/styles.xml`

`LaunchTheme` et `NormalTheme` doivent hériter de:
```xml
@style/Theme.AppCompat.DayNight.NoActionBar
```

### 9.4 Durcissement manifest
Dans `AndroidManifest.xml`:
```xml
android:allowBackup="false"
```

### 9.5 Gradle
`android/app/build.gradle.kts`:
- Kotlin + Android plugin Flutter standard
- `minSdk = flutter.minSdkVersion`
- `targetSdk = flutter.targetSdkVersion`

## 10) Paramètres local_auth utilisés
Dans `SystemAuthService.authenticateWithSystem()`:
```dart
AuthenticationOptions(
  stickyAuth: true,
  sensitiveTransaction: true,
  biometricOnly: false,
)
```

Signification:
- `stickyAuth: true`: meilleure continuité pendant les transitions d'app
- `sensitiveTransaction: true`: contexte sensible explicite
- `biometricOnly: false`: autorise fallback appareil (PIN/schéma/mot de passe)

## 11) Robustesse et migration
Le système migre automatiquement l'ancien format de hash instable (`hashCode`) vers une signature stable.
Cela évite les faux positifs de "configuration modifiée" après redémarrage.

## 12) Checklist de validation recommandée
1. Première ouverture avec verrou Android actif
2. Première ouverture sans verrou Android actif
3. Activation depuis setup initial
4. Activation depuis gestion sécurité après "Ignorer"
5. Désactivation depuis gestion sécurité (avec ré-auth)
6. Réactivation après désactivation
7. Auth au lancement app
8. Reverrouillage après retour background
9. Changement de verrou Android puis relance app
10. Comportement sur petit écran et grand écran

## 13) Limites connues
- Android ne fournit pas le détail exact PIN vs schéma vs mot de passe via `local_auth`.
- L'app affiche donc un libellé générique pour le verrou appareil.

## 14) Date de mise à jour
- 16 février 2026
