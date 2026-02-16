# Documentation du système d'authentification AtaoQuiz

## 1. Objectif
Le système d'authentification d'AtaoQuiz repose sur la sécurité native Android.
L'application n'implémente pas de code secret interne: elle réutilise le verrouillage déjà configuré sur l'appareil (biométrie ou identifiants système).

## 2. Composants principaux

### Service d'authentification
- `lib/services/system_auth_service.dart`

Responsabilités:
- détecter les méthodes de verrouillage disponibles
- activer/désactiver la sécurité de l'application
- lancer l'authentification système
- gérer un fallback natif Android pour schéma/PIN/mot de passe
- détecter les changements de configuration de sécurité Android

### Écrans
- `lib/screens/authentication/first_time_setup_screen.dart`
- `lib/screens/authentication/system_auth_screen.dart`
- `lib/screens/authentication/system_auth_manage_screen.dart`
- `lib/screens/splash_screen.dart`

### Verrouillage au retour arrière-plan
- `lib/main.dart`

### Intégration Android native
- `android/app/src/main/kotlin/com/example/atao_quiz/MainActivity.kt`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/values/styles.xml`
- `android/app/src/main/res/values-night/styles.xml`
- `android/app/build.gradle.kts`

## 3. Méthodes supportées et affichage
Le service expose les types suivants:
- biométrie (`DeviceLockType.biometric`)
- verrou appareil générique (`DeviceLockType.pin`)

Important:
- Android/`local_auth` ne donne pas de distinction fiable entre PIN, schéma et mot de passe.
- Le libellé affiché est volontairement:
  - `Verrouillage appareil (PIN/Schéma/Mot de passe)`

Pour la biométrie, Android remonte souvent `BiometricType.weak` / `BiometricType.strong`.
Le système ne peut pas garantir une différenciation explicite "empreinte" vs "visage" dans tous les cas.

## 4. Flux fonctionnels

### Premier lancement
1. `SplashScreen` lit `is_first_time_setup`.
2. Si `true`, redirection vers `/first-time-setup`.
3. L'utilisateur peut activer la sécurité ou ignorer.
4. Dans les deux cas, `is_first_time_setup` devient `false`.

### Lancements suivants
1. `SplashScreen` lit `system_auth_enabled`.
2. Si activé, redirection vers `/system-auth`.
3. En cas de succès, navigation vers `/home`.

### Retour depuis l'arrière-plan
`main.dart` arme un verrou au prochain `resumed` quand l'app passe en `inactive/paused/hidden`.
Au `resumed`, l'app redirige vers `/system-auth` si la sécurité est activée et si la route courante n'est pas exclue.

Routes exclues:
- `/`
- `/first-time-setup`
- `/system-auth`

### Changement de sécurité Android
Au chargement de `/system-auth`, l'app compare la signature sécurité stockée avec la configuration actuelle.
Si changement détecté:
1. désactivation de la sécurité de l'app
2. affichage d'un message explicite
3. redirection vers `/first-time-setup`

Cela évite les boucles d'authentification et impose une reconfiguration propre.

## 5. Détails techniques du service

### 5.1 Détection des méthodes
`getAvailableLockTypes()`:
- utilise `canCheckBiometrics` + `isDeviceSupported()`
- tente `getAvailableBiometrics()` dans un `try/catch` dédié
- si la liste biométrique échoue sur certains appareils OEM, l'app conserve quand même le fallback identifiant appareil

### 5.2 Activation
`enableSystemAuth({ bool requireCurrentUserVerification = false })`:
- vérifie qu'un verrou est bien disponible
- stocke les types détectés
- active `system_auth_enabled`
- stocke une signature stable de sécurité

Par défaut, `requireCurrentUserVerification` est `false` pour éviter des échecs d'activation sur certains appareils.

### 5.3 Authentification runtime
`authenticateWithSystem()` utilise:
```dart
AuthenticationOptions(
  stickyAuth: false,
  sensitiveTransaction: true,
  biometricOnly: false,
)
```

Raison:
- `stickyAuth: false` réduit les boucles OEM lors du passage biométrie -> identifiant appareil
- `biometricOnly: false` autorise le fallback PIN/schéma/mot de passe

### 5.4 Fallback natif Kotlin (mot de passe/schéma/PIN)
Si `local_auth.authenticate(...)` renvoie `false` ou lève `PlatformException`:
1. appel `stopAuthentication()`
2. tentative de fallback via `MethodChannel('atao_quiz/device_credential')`

Méthodes natives exposées par `MainActivity.kt`:
- `isDeviceCredentialAvailable`
- `authenticateWithDeviceCredential`

Implémentation:
- vérification `KeyguardManager.isDeviceSecure`
- ouverture de `createConfirmDeviceCredentialIntent(...)`
- résultat renvoyé à Flutter via `onActivityResult` (code requête `4242`)

Résultat:
- schéma/PIN/mot de passe fonctionnent même quand biométrie est aussi configurée

### 5.5 Diagnostic d'erreurs
Le service stocke:
- `lastAuthErrorCode`
- `lastAuthErrorMessage`

`SystemAuthScreen` les journalise pour identifier précisément les causes d'échec (annulation, exception plateforme, fallback credential refusé, etc.).

## 6. Données persistées (SharedPreferences)
- `is_first_time_setup` (bool)
- `system_auth_enabled` (bool)
- `device_lock_types` (List<String>)
- `last_security_hash` (String)

## 7. Configuration Android obligatoire

### 7.1 Permissions
Dans `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
```

### 7.2 Durcissement Manifest
Toujours dans `AndroidManifest.xml`:
```xml
android:allowBackup="false"
```

### 7.3 Activity
`MainActivity` doit hériter de `FlutterFragmentActivity`:
```kotlin
class MainActivity : FlutterFragmentActivity()
```

### 7.4 Thèmes Android
Dans `styles.xml` et `values-night/styles.xml`, `LaunchTheme` et `NormalTheme` héritent de:
```xml
@style/Theme.AppCompat.DayNight.NoActionBar
```

### 7.5 Gradle / JVM
Dans `android/app/build.gradle.kts`:
- Java 11 (`sourceCompatibility`, `targetCompatibility`)
- Kotlin JVM target 11
- `minSdk = flutter.minSdkVersion`
- `targetSdk = flutter.targetSdkVersion`

## 8. Limites connues
- `local_auth` ne permet pas d'indiquer de façon certaine si l'utilisateur a saisi un PIN, un schéma ou un mot de passe.
- La présence d'une biométrie ne signifie pas qu'un type "visage" sera affiché explicitement; Android peut remonter des classes génériques `weak/strong`.

## 9. Checklist de validation recommandée
1. Activation depuis setup initial
2. Activation depuis gestion sécurité après "Ignorer"
3. Désactivation avec ré-authentification
4. Réactivation après désactivation
5. Auth biométrique réussie
6. Auth schéma/PIN/mot de passe réussie avec biométrie aussi configurée
7. Retour arrière-plan -> reverrouillage
8. Changement de verrou Android -> redirection reconfiguration
9. Test sur appareil sans biométrie
10. Test sur appareil avec biométrie + identifiant appareil

## 10. Dernière mise à jour
- 16 février 2026
