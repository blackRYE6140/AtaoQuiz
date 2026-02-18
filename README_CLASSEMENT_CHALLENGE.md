# Classement et Challenge (local + reseau Wi-Fi)

Ce document decrit le fonctionnement reel de `Challenge & Classement` dans AtaoQuiz: modes de jeu, roles hote/joueur, regles de classement, points/niveaux et protocole reseau.

## 1. Objectif

Permettre de jouer un quiz:
- en mode `Defi entre amis` (reseau Wi-Fi, multi-telephones)
- en mode `Challenge avec le temps` (chrono personnel)

Puis calculer:
- un classement de session
- un classement global (points, niveau, victoires)

## 2. Perimetre actuel

- Session challenge mode amis: disponible.
- Session challenge mode chrono: disponible.
- Challenge live Wi-Fi multi-pairs: disponible.
- Demarrage synchronise avec compte a rebours: disponible.
- Profil synchronise (nom + image) dans challenge et leaderboard: disponible.
- Stockage: local (`SharedPreferences`), pas de cloud.

## 3. Architecture feature

### 3.1 Ecrans

- `lib/screens/challenge/challenge_center_screen.dart`
  - container principal avec 2 onglets: `Challenges` et `Classement`.
- `lib/screens/challenge/challenge_sessions_screen.dart`
  - creation session (choix mode amis ou chrono)
  - guard profil configure (prompt + redirection profil la premiere fois)
  - guard reseau: en `Defi entre amis`, seul l'hote peut continuer
  - liste des `Challenges termines`
- `lib/screens/challenge/challenge_detail_screen.dart`
  - details session et lancement de partie
  - bouton `Lancer challenge Wi-Fi` (hote)
  - demarrage synchronise des manches reseau
  - classement local ou live (avec avatar joueur)
- `lib/screens/challenge/leaderboard_screen.dart`
  - classement global (points, niveau, victoires, stats)
  - prompt setup profil la premiere fois si profil non configure

### 3.2 Services

- `lib/services/challenge_service.dart`
  - modeles: `ChallengeSession`, `ChallengeAttempt`, `LeaderboardEntry`
  - persistance locale des sessions
  - ranking par session
  - calcul points et niveaux globaux
- `lib/services/quiz_transfer_service.dart`
  - sockets TCP, connexion QR/IP
  - challenge live: `challenge_start`, `challenge_round_start`, `challenge_result`, `challenge_leaderboard`
  - synchronisation resultats et avatars entre appareils
- `lib/services/user_profile_service.dart`
  - profil joueur unique (nom/avatar/photo)
  - gestion "prompt setup une seule fois" pour challenge/classement
- `lib/screens/generatequiz/play_quiz_screen.dart`
  - renvoie score + `completionDurationMs`
  - applique une limite de temps quand un challenge chrono est actif

## 4. Flux utilisateur

### 4.1 Creation d'une session challenge

Depuis `Challenges` -> `Creer et ouvrir`:
1. Choisir le quiz source.
2. Choisir le mode:
   - `Defi entre amis`
   - `Challenge avec le temps`
3. Si mode chrono, choisir la duree (ex: 2 min, 5 min, etc.).

Regles:
- `Defi entre amis`: le bouton `Continuer` est actif uniquement si:
  - le telephone est en mode hote (`serveur Wi-Fi`)
  - au moins un autre telephone est connecte
- sinon, popup d'information + redirection possible vers `Partage via Wi-Fi`.

### 4.2 Challenge reseau Wi-Fi (defi entre amis)

1. Telephone hote:
   - ouvre `Transfert Wi-Fi`
   - lance le serveur
   - partage QR/IP aux amis
2. Hote cree/ouvre une session mode amis.
3. Hote appuie `Lancer challenge Wi-Fi`.
4. Les joueurs rejoins recoivent la session et voient l'etat d'attente.
5. Hote lance une manche synchronisee:
   - countdown diffuse a tous
   - option chrono activable pour cette manche (sinon sans chrono)
6. Tous les appareils demarrent ensemble au debut du countdown.
7. Chaque joueur envoie son resultat, l'hote consolide et rediffuse le classement live.

### 4.3 Challenge avec le temps (mode personnel)

1. L'utilisateur cree une session en mode `Challenge avec le temps`.
2. Il choisit une duree.
3. Le quiz s'arrete automatiquement a la fin du chrono.
4. Le resultat est classe avec les autres tentatives de la session.

## 5. Regles de classement de session

Pour chaque joueur, un seul meilleur resultat est conserve.

Comparaison des tentatives:
1. score le plus eleve
2. puis temps de completion le plus court
3. puis meilleure reussite
4. puis tentative la plus ancienne

Tri final:
1. score desc
2. temps asc
3. reussite desc
4. date asc

## 6. Classement global: points et niveaux

Sources:
- meilleurs resultats challenge (amis + chrono)
- resultats d'entrainement local

Points challenge:
- base: `30 + round(taux_reussite * 70)`
- bonus podium:
  - rang 1: `+30`
  - rang 2: `+20`
  - rang 3: `+10`
- bonus chrono session timed:
  - `+15` fixe
  - `+0..10` selon rapidite vs limite temps

Points entrainement:
- `10 + round(taux_reussite * 40)`

Tri leaderboard global:
1. points desc
2. victoires challenge desc
3. victoires chrono desc
4. reussite moyenne desc
5. temps moyen asc
6. nom joueur alpha

Niveaux:
- seuil initial niv 1 -> 2: `120`
- seuil suivant: `seuil_precedent * 1.18` (arrondi)

## 7. Reseau challenge (protocole)

Transport:
- TCP (`dart:io`)
- protocole: `atao_quiz.live_transfer`
- version: `2`

Messages principaux:
- `challenge_start`: creation session live + envoi quiz + identite hote
- `challenge_round_start`: annonce manche synchronisee (countdown + chrono optionnel)
- `challenge_result`: envoi resultat joueur
- `challenge_leaderboard`: classement live consolide diffuse par l'hote

Important:
- l'hote est l'autorite de classement live
- un pair qui rejoint plus tard peut recevoir l'etat actif (session + manche + leaderboard)

## 8. Persistance locale

`ChallengeService` stocke les sessions dans:
- `challenge_sessions_v1`

`UserProfileService` gere le nom/image global, avec migration legacy possible depuis:
- `challenge_local_player_name_v1` (lecture legacy uniquement)

Chaque `ChallengeSession` stocke:
- metadonnees session (`id`, `name`, `quizId`, `quizTitle`, `questionCount`)
- `mode` (`friends` ou `timed`)
- `timeLimitSeconds` si mode chrono
- `networkSessionId` si session reseau
- tentatives

## 9. Configuration Android

Dans `android/app/src/main/AndroidManifest.xml`:
- `android.permission.INTERNET` (sockets TCP)
- `android.permission.CAMERA` (scan QR)

Autres points:
- appareils sur le meme reseau local
- `MainActivity` compatible plugins (`FlutterFragmentActivity`)

## 10. Limites connues

- Pas de TLS applicatif sur sockets.
- Pas d'authentification forte pair-a-pair.
- Classement global local a l'appareil (pas de sync cloud).

## 11. Fichiers de reference

- `lib/screens/challenge/challenge_center_screen.dart`
- `lib/screens/challenge/challenge_sessions_screen.dart`
- `lib/screens/challenge/challenge_detail_screen.dart`
- `lib/screens/challenge/leaderboard_screen.dart`
- `lib/services/challenge_service.dart`
- `lib/services/quiz_transfer_service.dart`
- `lib/services/user_profile_service.dart`
- `lib/screens/generatequiz/play_quiz_screen.dart`
- `README_TRANSFERT_QUIZ.md`
