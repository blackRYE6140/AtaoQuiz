# Transfert de quiz entre 2 telephones (AtaoQuiz)

Ce document explique de facon complete le transfert local de quiz entre deux telephones Android dans AtaoQuiz: methode technique, configuration Android, permissions, utilisation, limites et depannage.

## 1. Objectif

Permettre a deux telephones d'echanger des quiz en local, sans cloud:
- telephone A heberge la connexion (serveur TCP)
- telephone B se connecte (client TCP)
- une fois connectes, les deux peuvent envoyer/recevoir des quiz

## 2. Methode utilisee

### 2.1 Transport reseau
- Socket TCP locale via `dart:io` (`ServerSocket` et `Socket`)
- Port par defaut: `4040` (modifiable dans l'ecran de connexion)
- Reseau requis: meme LAN (meme Wi-Fi ou hotspot partage)

### 2.2 Decouverte du pair
- Methode 1 (recommandee): QR code
  - l'hote genere un QR contenant `host` + `port`
  - le client scanne le QR avec la camera
- Methode 2: saisie manuelle IP + port

### 2.3 Format de protocole
Messages JSON, 1 message par ligne (`\n`), avec enveloppe:
- `protocol`: `atao_quiz.live_transfer`
- `version`: `2`
- `type`: `hello`, `quiz`, `ack`

Exemple logique:
```json
{
  "protocol": "atao_quiz.live_transfer",
  "version": 2,
  "type": "quiz",
  "transferId": "1739840000123456",
  "sentAt": "2026-02-17T10:15:32.000Z",
  "quiz": { "...": "..." }
}
```

## 3. Flux complet entre 2 telephones

### 3.1 Telephone A (hote)
1. Aller dans `Transfert de quiz` > onglet `Connexion`.
2. Verifier/choisir le port (par defaut `4040`).
3. Appuyer sur `Lancer serveur`.
4. Afficher le QR code.

### 3.2 Telephone B (client)
1. Aller dans `Transfert de quiz` > onglet `Connexion`.
2. Appuyer sur `Scanner QR` (ou saisir IP/port manuellement).
3. Se connecter a l'hote.

### 3.3 Envoi des quiz
1. Sur l'un des telephones, aller dans l'onglet `Echanges`.
2. Selectionner un ou plusieurs quiz.
3. Appuyer sur `Envoyer`.
4. Le pair recoit et importe les quiz automatiquement.
5. L'historique affiche succes/erreur pour chaque transfert.

## 4. Donnees transferees et traitement

### 4.1 Avant envoi
Le quiz est "nettoye":
- copie des questions/options
- remise a zero des champs de score/session (`score`, `playedAt`)

### 4.2 A la reception
- validation du protocole/version
- import via `StorageService` (SharedPreferences)
- si ID deja existant:
  - creation d'un nouvel ID
  - suffixe ` (copie)` sur le titre
- metadonnees appliquees:
  - `origin = "transfer"`
  - `receivedAt = now`
  - score remis a zero

### 4.3 Historique
- Historique en memoire (temporaire, non persiste)
- Maximum `120` entrees
- Suppression possible depuis l'UI

## 5. Configuration Android complete

### 5.1 Dependances Flutter (pubspec)
Les dependances cle pour le transfert sont:
- `qr_flutter` (generation du QR)
- `mobile_scanner` (scan camera du QR)
- `shared_preferences` (stockage local des quiz recus)

### 5.2 Permissions Android (Manifest)
Dans `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
```

Explication:
- `INTERNET`: indispensable pour sockets TCP locales
- `CAMERA`: indispensable pour scanner le QR
- `USE_BIOMETRIC` / `USE_FINGERPRINT`: utilisees par la securite locale de l'app (auth systeme), pas directement par le transfert

### 5.3 Activity Android
`MainActivity` doit rester compatible plugins (scanner/auth):
- classe: `FlutterFragmentActivity`
- fichier: `android/app/src/main/kotlin/com/example/atao_quiz/MainActivity.kt`

### 5.4 Build Android (Gradle)
Dans `android/app/build.gradle.kts`:
- Java/Kotlin cible 11
- `minSdk` et `targetSdk` herites de Flutter

### 5.5 Permissions runtime
- Camera: autorisation demandee au premier scan QR
- Si l'utilisateur refuse la camera, le scan QR ne fonctionne pas (utiliser IP/port manuel en secours)

## 6. Conditions de fonctionnement

- Les 2 telephones doivent etre sur le meme reseau local.
- Le telephone hote doit rester sur l'ecran de transfert pendant la session.
- Un seul pair actif a la fois sur le serveur actuel.
- Les 2 appareils doivent utiliser une version compatible du protocole (`version = 2`).

## 7. Erreurs frequentes et solutions

- `QR indisponible: connectez-vous au reseau Wi-Fi puis relancez`
  - le telephone n'a pas d'IP locale exploitable
  - activer Wi-Fi/hotspot puis relancer le serveur

- `Connexion impossible`
  - verifier meme reseau, IP correcte, port correct
  - verifier qu'un serveur est bien lance sur l'hote

- `Protocole incompatible`
  - versions d'app/protocole differentes
  - mettre a jour les deux telephones avec une version compatible

- `Nouveau pair refuse: connexion deja active`
  - le serveur accepte une connexion active a la fois
  - deconnecter le pair courant avant un nouveau pair

- `Port invalide (1..65535)`
  - saisir un port numerique valide

## 8. Securite (etat actuel)

Le transfert actuel est local mais non chiffre au niveau applicatif:
- pas de TLS
- pas d'authentification forte entre pairs

Recommandations:
- utiliser un reseau de confiance
- eviter les Wi-Fi publics
- evolutions conseillees: token de session, chiffrement (TLS), validation explicite du pair

## 9. Fichiers source de reference

- `lib/services/quiz_transfer_service.dart`
- `lib/screens/transfer_quiz/receive_quiz_screen.dart`
- `lib/screens/transfer_quiz/send_quiz_screen.dart`
- `lib/screens/transfer_quiz/qr_scanner_screen.dart`
- `lib/services/storage_service.dart`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/build.gradle.kts`
