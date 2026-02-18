# Transfert de quiz via Wi-Fi (AtaoQuiz)

Ce document couvre le transfert local de quiz et la base reseau utilisee aussi par les challenges live.

## 1. Objectif

Permettre des echanges locaux sans cloud:
- un telephone hote lance le serveur TCP
- un ou plusieurs telephones clients se connectent
- tous les appareils connectes peuvent envoyer/recevoir des quiz

Le meme canal sert aussi au mode challenge Wi-Fi.

## 2. Methode technique

### 2.1 Transport reseau
- `dart:io` (`ServerSocket`, `Socket`)
- port par defaut: `4040` (modifiable)
- appareils sur le meme LAN (meme Wi-Fi/hotspot)

### 2.2 Connexion
- QR code (recommande)
  - l'hote publie `host + port`
  - le client scanne
- saisie manuelle IP + port

### 2.3 Protocole
Messages JSON, une ligne par message (`\n`), enveloppe commune:
- `protocol`: `atao_quiz.live_transfer`
- `version`: `2`

Types principaux:
- transfert quiz: `hello`, `quiz`, `ack`
- challenge live: `challenge_start`, `challenge_round_start`, `challenge_result`, `challenge_leaderboard`

Exemple:
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

## 3. Flux d'utilisation

### 3.1 Hote
1. Ouvrir `Transfert de quiz` > `Connexion`.
2. Verifier/choisir le port.
3. Appuyer sur `Lancer serveur`.
4. Afficher le QR.
5. Les amis scannent pour rejoindre.

### 3.2 Client
1. Ouvrir `Transfert de quiz` > `Connexion`.
2. Scanner QR (ou IP/port manuel).
3. Se connecter a l'hote.

### 3.3 Echange de quiz
1. Ouvrir onglet `Echanges`.
2. Selectionner quiz.
3. Envoyer.
4. Import automatique cote recepteur.
5. Historique de statut affiche.

## 4. Regles de traitement des quiz

### 4.1 Avant envoi
Quiz nettoye:
- copie defensive des questions/options
- reset score/date de jeu

### 4.2 A la reception
- validation protocole/version
- import `StorageService`
- si ID deja present:
  - nouvel ID genere
  - suffixe ` (copie)` sur le titre
- metadonnees:
  - `origin = "transfer"`
  - `receivedAt = now`
  - score reset

### 4.3 Historique
- en memoire (non persiste)
- max `120` entrees
- suppression possible depuis l'UI

## 5. Lien avec le challenge Wi-Fi

Le meme service reseau pilote les challenges live:
- l'hote cree et lance le challenge (`challenge_start`)
- l'hote annonce une manche synchronisee (`challenge_round_start`)
- les joueurs envoient leurs scores (`challenge_result`)
- l'hote renvoie le classement consolide (`challenge_leaderboard`)

Regle metier UI:
- en mode `Defi entre amis`, seul le telephone hote (celui du QR) peut creer/continuer.

## 6. Configuration Android

### 6.1 Dependances Flutter
- `qr_flutter`
- `mobile_scanner`
- `shared_preferences`

### 6.2 Permissions
Dans `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
```

Notes:
- `INTERNET`: obligatoire pour sockets TCP.
- `CAMERA`: obligatoire pour scanner QR.
- permissions biometrie: utilisees par la securite app, pas par le transfert.

### 6.3 Activity
- `MainActivity` doit rester `FlutterFragmentActivity`
- fichier: `android/app/src/main/kotlin/com/example/atao_quiz/MainActivity.kt`

### 6.4 Permission runtime
- la camera est demandee au premier scan QR.
- fallback possible par saisie IP/port si refus camera.

## 7. Conditions de fonctionnement

- appareils sur le meme reseau local
- protocole compatible (`version = 2`) sur tous les appareils
- l'hote doit avoir une IP locale valide pour afficher le QR
- le serveur peut gerer plusieurs pairs connectes

## 8. Erreurs frequentes

- `QR indisponible: connectez-vous au reseau Wi-Fi puis relancez`
  - pas d'IP locale exploitable
- `Connexion impossible`
  - verifier reseau, IP, port, serveur actif
- `Protocole incompatible`
  - mismatch de version app/protocole
- `Port invalide (1..65535)`
  - saisir un port numerique valide

## 9. Securite actuelle

Etat:
- pas de TLS applicatif
- pas d'authentification forte pair-a-pair

Conseils:
- utiliser reseau de confiance
- eviter Wi-Fi public
- evolutions possibles: token session, chiffrement, verification explicite pair

## 10. Fichiers de reference

- `lib/services/quiz_transfer_service.dart`
- `lib/screens/transfer_quiz/transfer_quiz_screen.dart`
- `lib/screens/transfer_quiz/receive_quiz_screen.dart`
- `lib/screens/transfer_quiz/send_quiz_screen.dart`
- `lib/screens/transfer_quiz/qr_scanner_screen.dart`
- `lib/services/storage_service.dart`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/build.gradle.kts`
