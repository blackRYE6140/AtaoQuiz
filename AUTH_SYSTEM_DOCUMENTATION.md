# Documentation du système d'authentification AtaoQuiz

## 1. Objectif
AtaoQuiz délègue entièrement l'authentification locale à Android.
L'application ne stocke pas de code secret interne et réutilise les protections natives (biométrie, PIN, schéma, mot de passe).

## 2. Architecture

### Service central
- `lib/services/system_auth_service.dart`

Fonctions principales:
- inventaire des méthodes de sécurité disponibles
- activation/désactivation du verrou applicatif
- authentification à l'exécution
- fallback natif Android pour device credential
- prise en charge des comportements OEM (Transsion)
- journalisation d'erreurs détaillées

### Écrans concernés
- `lib/screens/authentication/first_time_setup_screen.dart`
- `lib/screens/authentication/system_auth_screen.dart`
- `lib/screens/authentication/system_auth_manage_screen.dart`
- `lib/screens/splash_screen.dart`

### Cycle de vie / navigation
- `lib/main.dart`

### Bridge natif Android
- `android/app/src/main/kotlin/com/example/atao_quiz/MainActivity.kt`

## 3. Méthodes de sécurité exposées
`DeviceLockType` utilisé dans l'app:
- `biometric`
- `pin` (libellé générique appareil)

Libellé utilisé côté UI:
- `Verrouillage appareil (PIN/Schéma/Mot de passe)`

Note:
- Android ne fournit pas un mapping stable PIN/schéma/mot de passe
- biométrie souvent remontée comme `weak` / `strong`

## 4. Flux utilisateur

### 4.1 Premier démarrage
1. lecture de `is_first_time_setup`
2. redirection vers `/first-time-setup` si nécessaire
3. activation sécurité possible ou passage sans sécurité

### 4.2 Démarrages suivants
1. lecture de `system_auth_enabled`
2. redirection vers `/system-auth` si activé
3. succès -> `/home`

### 4.3 Retour au foreground
Comportement actuel:
- plus de lock systématique au simple retour depuis notifications/Home
- lock uniquement si l'écran s'est éteint

Mécanisme:
1. `MainActivity` intercepte `ACTION_SCREEN_OFF`
2. un flag natif est positionné
3. Flutter lit ce flag au `resumed` via `consumeScreenOffFlag()`
4. si `true`, redirection vers `/system-auth`

Routes exclues:
- `/`
- `/first-time-setup`
- `/system-auth`

### 4.4 Changement de verrou Android
Au chargement de `/system-auth`:
- comparaison de la signature sécurité courante vs stockée
- si mismatch: désactivation auth app + redirection setup

## 5. Détails techniques d'auth

### 5.1 Flux standard
`local_auth.authenticate` avec:
```dart
AuthenticationOptions(
  stickyAuth: false,
  sensitiveTransaction: true,
  biometricOnly: false,
)
```

En cas d'échec:
- arrêt auth active
- fallback credential natif

### 5.2 Flux spécifique Transsion (Tecno/Infinix/Itel)
Détection OEM via `manufacturer`/`brand`.

Si biométrie enrôlée:
- tentative biométrie seule (`biometricOnly: true`)
- bouton Android personnalisé: `Utiliser le mot de passe`
- si échec/annulation: fallback credential une seule fois (retry auto OEM désactivé pour éviter double demande)

Si biométrie non enrôlée:
- fallback credential standard

### 5.3 Fallback credential natif
Channel: `atao_quiz/device_credential`

Méthodes natives:
- `isDeviceCredentialAvailable`
- `authenticateWithDeviceCredential`
- `getDeviceAuthDebugInfo`
- `consumeScreenOffFlag`

Implémentation:
- `KeyguardManager.isDeviceSecure`
- `createConfirmDeviceCredentialIntent`
- Activity Result API moderne (`ActivityResultContracts.StartActivityForResult`)
- lancement différé si activité non `resumed`

Tolérance OEM:
- délai initial avant prompt credential
- retry optionnel OEM après échec `device_credential_failed_or_canceled`
- retry désactivé dans le chemin Transsion biométrie->mot de passe pour éviter double auth

## 6. Erreurs et observabilité
Le service expose:
- `lastAuthErrorCode`
- `lastAuthErrorMessage`

Utilisé par `SystemAuthScreen` pour logs runtime et diagnostic terrain.

## 7. Stockage local
Clés `SharedPreferences`:
- `is_first_time_setup`
- `system_auth_enabled`
- `device_lock_types`
- `last_security_hash`

## 8. Configuration requise

### AndroidManifest
- `USE_BIOMETRIC`
- `USE_FINGERPRINT`
- `android:allowBackup="false"`

### Activity
- `MainActivity : FlutterFragmentActivity`

### Thèmes Android
- base AppCompat DayNight (`Theme.AppCompat.DayNight.NoActionBar`)

### Dépendances Flutter
- `local_auth`
- `local_auth_android` (nécessaire pour `AndroidAuthMessages`)

## 9. Limites connues
- impossible de garantir le type exact PIN/schéma/mot de passe
- certaines ROM OEM peuvent retourner `false` sans distinguer annulation/rejet
- classification biométrique Android peut rester générique (`weak/strong`)

## 10. Scénarios de test recommandés
1. Setup initial avec activation sécurité
2. Activation/désactivation depuis écran gestion
3. Biométrie OK
4. PIN/schéma/mot de passe OK
5. Flux Transsion: bascule biométrie -> mot de passe
6. Vérification absence de double prompt mot de passe sur Transsion
7. Retour depuis notifications/Home (sans écran OFF) -> pas de lock
8. Écran OFF puis reprise -> lock
9. Relance complète app -> lock si activé
10. Changement verrou Android -> reset/reconfiguration

## 11. Dernière mise à jour
- 17 février 2026
