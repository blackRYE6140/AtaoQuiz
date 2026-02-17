# Système d'authentification AtaoQuiz (implémentation actuelle)

## 1. Objectif
AtaoQuiz utilise la sécurité native Android pour contrôler l'accès à l'application.
L'application ne gère pas de PIN interne. Elle s'appuie sur le verrouillage déjà configuré sur l'appareil (biométrie, PIN, schéma, mot de passe).

## 2. Composants principaux

### Service d'authentification
- `lib/services/system_auth_service.dart`

Responsabilités:
- détecter les méthodes de sécurité disponibles
- activer/désactiver la sécurité de l'application
- exécuter l'authentification runtime
- gérer les adaptations OEM (Tecno/Infinix/Itel/Transsion)
- lancer le fallback natif Android (PIN/schéma/mot de passe)
- exposer les erreurs détaillées d'auth

### Écrans du flux
- `lib/screens/authentication/first_time_setup_screen.dart`
- `lib/screens/authentication/system_auth_screen.dart`
- `lib/screens/authentication/system_auth_manage_screen.dart`
- `lib/screens/splash_screen.dart`

### Verrouillage cycle de vie
- `lib/main.dart`

### Intégration Android native
- `android/app/src/main/kotlin/com/example/atao_quiz/MainActivity.kt`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/values/styles.xml`
- `android/app/src/main/res/values-night/styles.xml`
- `android/app/build.gradle.kts`

## 3. Méthodes supportées et libellés
Types détectés:
- biométrie
- verrou appareil générique

Libellé verrou appareil:
- `Verrouillage appareil (PIN/Schéma/Mot de passe)`

Pourquoi ce libellé reste générique:
- `local_auth` ne fournit pas une distinction fiable PIN vs schéma vs mot de passe
- Android remonte souvent la biométrie sous forme `weak/strong` sans type explicite visage/empreinte

## 4. Flux applicatif

### Premier lancement
1. `SplashScreen` vérifie `is_first_time_setup`.
2. Si `true`, redirection vers `/first-time-setup`.
3. L'utilisateur peut activer la sécurité ou ignorer.
4. Le setup initial est marqué terminé.

### Lancements suivants
1. `SplashScreen` vérifie `system_auth_enabled`.
2. Si activé, redirection vers `/system-auth`.
3. Succès -> `/home`.

### Retour en foreground (comportement actuel)
Le reverrouillage sur `resumed` ne se fait **plus** à chaque `paused/inactive`.
Il se fait uniquement si l'écran s'est éteint entre-temps.

Concrètement:
1. `MainActivity` écoute `ACTION_SCREEN_OFF` et pose un flag interne.
2. `main.dart` appelle `consumeScreenOffFlag()` au `resumed`.
3. Si flag = `true` et auth activée -> navigation vers `/system-auth`.
4. Si flag = `false` (retour notifications/Home sans écran éteint) -> pas de demande d'auth.

Routes exclues du lock:
- `/`
- `/first-time-setup`
- `/system-auth`

### Changement de configuration sécurité Android
`SystemAuthScreen` vérifie `hasSecurityConfigChanged()`.
Si changement détecté:
1. désactivation de la sécurité app
2. affichage d'un avertissement
3. redirection vers `/first-time-setup`

## 5. Moteur d'authentification

### 5.1 Flux standard (hors OEM ciblé)
`authenticateWithSystem()` utilise:
```dart
AuthenticationOptions(
  stickyAuth: false,
  sensitiveTransaction: true,
  biometricOnly: false,
)
```

Si `authenticate` retourne `false` ou exception:
1. `stopAuthentication()`
2. délai court
3. fallback natif via channel credential
4. retry OEM possible selon conditions (voir section fallback)

### 5.2 Flux optimisé Transsion (Tecno/Infinix/Itel)
Détection OEM via `manufacturer/brand` renvoyés par natif.

Si biométrie enrôlée:
1. tentative biométrique `biometricOnly: true`
2. message Android personnalisé avec bouton `Utiliser le mot de passe`
3. si échec/annulation -> fallback credential natif **sans retry OEM auto** (évite double saisie mot de passe)

Si biométrie non enrôlée:
- fallback credential natif direct

### 5.3 Fallback credential Android
Channel: `atao_quiz/device_credential`

Méthodes utilisées:
- `isDeviceCredentialAvailable`
- `authenticateWithDeviceCredential`
- `getDeviceAuthDebugInfo`
- `consumeScreenOffFlag`

Implémentation native:
- vérifie `KeyguardManager.isDeviceSecure`
- lance `createConfirmDeviceCredentialIntent(...)`
- utilise `ActivityResultContracts.StartActivityForResult()`
- diffère le lancement si l'activité n'est pas encore `resumed`

Comportement de fiabilisation:
- tentative 1 après délai (`250ms` par défaut)
- si échec `device_credential_failed_or_canceled` et OEM éligible: retry après `450ms`
- dans le flux Transsion biométrique->mot de passe: retry auto désactivé pour éviter la double demande

## 6. Diagnostic
Le service expose:
- `lastAuthErrorCode`
- `lastAuthErrorMessage`

`SystemAuthScreen` journalise ces valeurs pour diagnostiquer:
- annulation utilisateur
- rejet credential
- erreur plateforme
- échec fallback credential

## 7. Données persistées (SharedPreferences)
- `is_first_time_setup` (bool)
- `system_auth_enabled` (bool)
- `device_lock_types` (List<String>)
- `last_security_hash` (String)

## 8. Configuration Android requise

### Permissions
Dans `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
```

### Durcissement backup
Dans `android/app/src/main/AndroidManifest.xml`:
```xml
android:allowBackup="false"
```

### Activity
`MainActivity` doit hériter de `FlutterFragmentActivity`.

### Thème Android
`LaunchTheme` et `NormalTheme` doivent rester basés sur AppCompat (`Theme.AppCompat.DayNight.NoActionBar`).

### Dépendance Flutter
`pubspec.yaml` inclut:
- `local_auth`
- `local_auth_android` (nécessaire pour `AndroidAuthMessages`)

## 9. Limites connues
- `local_auth` ne distingue pas de manière certaine PIN/schéma/mot de passe.
- Android peut remonter la biométrie en classes génériques (`weak/strong`).
- selon certains firmwares OEM, `false` peut représenter soit annulation soit credential refusé.

## 10. Checklist de validation recommandée
1. Activation de la sécurité au premier setup
2. Activation/désactivation depuis Gestion sécurité
3. Auth biométrie réussie
4. Auth mot de passe/PIN/schéma réussie
5. Test Transsion: bouton `Utiliser le mot de passe` depuis prompt biométrique
6. Vérifier absence de double demande mot de passe sur Transsion
7. Retour notifications/Home sans écran éteint -> pas de lock
8. Écran éteint puis reprise -> lock
9. Relancement complet application -> lock si sécurité activée
10. Changement verrou Android -> redirection reconfiguration

## 11. Dernière mise à jour
- 17 février 2026
