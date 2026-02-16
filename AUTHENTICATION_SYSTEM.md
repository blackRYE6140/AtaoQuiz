# Système d'authentification AtaoQuiz (implémentation actuelle)

## 1. Objectif
AtaoQuiz utilise la sécurité native Android pour contrôler l'accès à l'application.
L'application ne gère pas de PIN interne. Elle s'appuie sur la méthode de verrouillage déjà configurée sur l'appareil.

## 2. Composants principaux

### Service d'authentification
- `lib/services/system_auth_service.dart`

Responsabilités:
- détecter les méthodes de verrouillage disponibles
- activer/désactiver l'authentification de l'application
- exécuter l'authentification au runtime
- lancer le fallback natif Android via identifiants appareil
- détecter les changements de configuration de sécurité Android

### Écrans du flux
- `lib/screens/authentication/first_time_setup_screen.dart`
- `lib/screens/authentication/system_auth_screen.dart`
- `lib/screens/authentication/system_auth_manage_screen.dart`
- `lib/screens/splash_screen.dart`

### Verrouillage au cycle de vie
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
- fallback identifiants appareil

Libellé affiché pour le fallback:
- `Verrouillage appareil (PIN/Schéma/Mot de passe)`

Pourquoi ce libellé est générique:
- `local_auth` ne fournit pas une distinction fiable entre PIN, schéma et mot de passe.
- la biométrie est souvent remontée comme `BiometricType.weak` / `BiometricType.strong`, sans type explicite visage/empreinte.

## 4. Flux d'exécution

### Premier lancement
1. `SplashScreen` vérifie `is_first_time_setup`.
2. Si `true`, redirection vers `/first-time-setup`.
3. L'utilisateur peut activer la sécurité ou ignorer.
4. La configuration initiale est marquée comme terminée dans les deux cas.

### Lancements suivants
1. `SplashScreen` vérifie `system_auth_enabled`.
2. Si activé, redirection vers `/system-auth`.
3. En cas de succès, redirection vers `/home`.

### Reverrouillage au retour de l'arrière-plan
`main.dart` prépare le verrouillage sur `inactive/paused/hidden` et impose `/system-auth` au `resumed` si nécessaire.

Routes exclues:
- `/`
- `/first-time-setup`
- `/system-auth`

### Changement de configuration de sécurité
`SystemAuthScreen` vérifie `hasSecurityConfigChanged()`.
Si changement détecté:
1. désactivation de l'authentification de l'app
2. affichage d'un avertissement
3. redirection forcée vers `/first-time-setup`

## 5. Détails du moteur d'authentification

### Options `local_auth` (actuelles)
`authenticateWithSystem()` utilise:
```dart
AuthenticationOptions(
  stickyAuth: false,
  sensitiveTransaction: true,
  biometricOnly: false,
)
```

Notes:
- `stickyAuth: false` évite des boucles OEM lors des transitions biométrie -> identifiants appareil.
- `biometricOnly: false` autorise le fallback PIN/schéma/mot de passe.

### Stratégie de fallback
Si `local_auth.authenticate(...)` renvoie `false` ou lève `PlatformException`:
1. appel de `stopAuthentication()`
2. appel du fallback natif via `MethodChannel('atao_quiz/device_credential')`

Méthodes natives implémentées dans `MainActivity.kt`:
- `isDeviceCredentialAvailable`
- `authenticateWithDeviceCredential`

Comportement natif:
- vérifie `KeyguardManager.isDeviceSecure`
- lance `createConfirmDeviceCredentialIntent(...)`
- renvoie le résultat à Flutter dans `onActivityResult` (code requête `4242`)

Cela corrige le cas où la biométrie est enregistrée mais l'utilisateur choisit mot de passe/schéma/PIN.

### Comportement d'activation
`enableSystemAuth({ requireCurrentUserVerification = false })` utilise par défaut une activation sans vérification immédiate pour éviter des échecs sur certains appareils OEM.

### Robustesse de la détection biométrique
`getAvailableLockTypes()` intercepte les exceptions de `getAvailableBiometrics()` pour conserver la disponibilité du fallback identifiants appareil.

### Diagnostic des erreurs
Le service expose:
- `lastAuthErrorCode`
- `lastAuthErrorMessage`

`SystemAuthScreen` journalise ces valeurs pour faciliter le diagnostic.

## 6. Clés SharedPreferences
- `is_first_time_setup` (bool)
- `system_auth_enabled` (bool)
- `device_lock_types` (List<String>)
- `last_security_hash` (String)

## 7. Configuration Android (obligatoire)

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

### Type d'activité
Dans `android/app/src/main/kotlin/com/example/atao_quiz/MainActivity.kt`:
```kotlin
class MainActivity : FlutterFragmentActivity()
```

### Compatibilité thème
Dans les deux fichiers `styles.xml`, `LaunchTheme` et `NormalTheme` héritent de:
```xml
@style/Theme.AppCompat.DayNight.NoActionBar
```

### Gradle/JVM
Dans `android/app/build.gradle.kts`:
- compatibilité Java 11
- Kotlin `jvmTarget = 11`
- `minSdk = flutter.minSdkVersion`
- `targetSdk = flutter.targetSdkVersion`

## 8. Limites connues
- Le type exact d'identifiant (PIN vs schéma vs mot de passe) n'est pas exposé par `local_auth`.
- La reconnaissance faciale peut ne pas apparaître comme type explicite même si elle est disponible.

## 9. Checklist de validation recommandée
1. Activation de la sécurité au premier setup
2. Activation depuis la gestion sécurité après "Ignorer"
3. Désactivation avec ré-authentification
4. Réactivation après désactivation
5. Succès avec biométrie
6. Succès avec mot de passe/schéma/PIN quand la biométrie est aussi configurée
7. Reverrouillage après retour de l'arrière-plan
8. Détection d'un changement de verrou Android
9. Test sur appareil sans biométrie
10. Test sur appareil avec biométrie + identifiants appareil

## 10. Dernière mise à jour
- 16 février 2026
