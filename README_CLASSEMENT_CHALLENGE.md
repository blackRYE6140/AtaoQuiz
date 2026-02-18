# Classement et Challenge (local + reseau Wi-Fi)

Ce document explique en detail la fonctionnalite `Classement & Challenge` d'AtaoQuiz: architecture, flux utilisateur, regles de classement, points/niveaux, protocole reseau et configuration Android.

## 1. Objectif

Permettre de jouer un meme quiz:
- en local (un telephone, plusieurs joueurs)
- en reseau local Wi-Fi (2 telephones ou plus)

Puis calculer:
- un classement de session challenge (vainqueur d'une partie)
- un classement global (points, niveau, victoires)

## 2. Perimetre actuel

- Challenge local: disponible.
- Challenge reseau multi-telephones: disponible.
- Departage des ex aequo: score d'abord, puis vitesse de fin.
- Classement global: disponible avec systeme de points et niveau.
- Stockage: local (`SharedPreferences`), pas de cloud pour le moment.

## 3. Hierarchie du code (feature)

### 3.1 Ecrans

- `lib/screens/challenge/challenge_center_screen.dart`
  - conteneur principal avec 2 onglets: `Challenges` et `Classement`.
- `lib/screens/challenge/challenge_sessions_screen.dart`
  - creation des sessions challenge
  - configuration du nom joueur local
  - affichage et ouverture de sessions existantes
  - status Wi-Fi (pairs connectes)
- `lib/screens/challenge/challenge_detail_screen.dart`
  - lancement de partie
  - lancement d'un challenge reseau
  - affichage classement local ou live
- `lib/screens/challenge/leaderboard_screen.dart`
  - classement global (points, niveau, victoires, stats)

### 3.2 Services

- `lib/services/challenge_service.dart`
  - modeles challenge (session, tentative, leaderboard)
  - persistance locale
  - ranking local
  - calcul points et niveaux
- `lib/services/quiz_transfer_service.dart`
  - socket TCP
  - connexion QR/IP
  - orchestration challenge live (`challenge_start`, `challenge_result`, `challenge_leaderboard`)
  - synchronisation resultats entre appareils
- `lib/screens/generatequiz/play_quiz_screen.dart`
  - retourne `completionDurationMs` a la fin d'un quiz
  - cette duree est utilisee pour departager les ex aequo

## 4. Flux utilisateur

### 4.1 Challenge local (sans reseau)

1. Ouvrir `Classement & Challenge`.
2. Dans `Challenges`, creer une session en choisissant un quiz.
3. Ouvrir la session.
4. Saisir le nom du participant.
5. Lancer `Jouer ce challenge`.
6. Le score et le temps sont sauvegardes.
7. Le classement de la session est mis a jour.

### 4.2 Challenge reseau (2+ telephones)

1. Sur le telephone hote:
   - aller dans `Transfert Wi-Fi`
   - lancer le serveur
   - connecter les autres appareils via QR ou IP/port
2. Sur l'hote, creer ou ouvrir une session challenge.
3. Dans le detail de la session, appuyer sur `Lancer challenge Wi-Fi`.
4. Le quiz et la session reseau sont diffuses aux telephones connectes.
5. Chaque joueur lance le quiz et envoie son resultat.
6. L'hote calcule le classement live et le rediffuse a tous les appareils.
7. Les resultats persistent localement pour alimenter le classement global.

## 5. Regles de classement d'une session challenge

Pour un joueur, seul le meilleur resultat est garde.

Regle de comparaison des tentatives:
1. score le plus eleve
2. si meme score: temps de completion le plus court
3. si toujours egalite: tentative la plus ancienne

Tri final d'un classement de session:
1. score descendant
2. temps de completion ascendant
3. date de fin (plus ancien d'abord)
4. nom joueur (fallback alphabetique pour le live)

## 6. Classement global: points et niveaux

Le leaderboard global est calcule a partir:
- des meilleurs resultats de chaque joueur dans chaque challenge
- des resultats d'entrainement local du joueur local

Points challenge (par session):
- base: `30 + round(taux_reussite * 70)`
- bonus podium:
  - rang 1: `+30`
  - rang 2: `+20`
  - rang 3: `+10`

Points entrainement local:
- `10 + round(taux_reussite * 40)`

Tri du leaderboard global:
1. points totaux (desc)
2. nombre de victoires challenge (desc)
3. reussite moyenne (desc)
4. temps moyen (asc, si disponible)
5. nom joueur (alphabetique)

Niveaux:
- seuil initial niveau 1 -> 2: `120` points
- puis seuil suivant = seuil precedent `* 1.18` (arrondi)

## 7. Protocole reseau challenge

Transport:
- TCP socket (`dart:io`)
- protocole applicatif: `atao_quiz.live_transfer`
- version: `2`

Messages principaux:
- `challenge_start`: demarre une session live et envoie le quiz
- `challenge_result`: envoi du score individuel d'un joueur
- `challenge_leaderboard`: classement live consolide diffuse par l'hote

Important:
- l'hote est l'autorite du classement live
- quand un nouveau pair se connecte en cours de partie, l'hote peut lui renvoyer session + leaderboard courant

## 8. Persistance locale

`ChallengeService` utilise `SharedPreferences`:
- `challenge_sessions_v1`
- `challenge_local_player_name_v1`

Chaque `ChallengeSession` stocke:
- metadonnees session (`id`, `name`, `quizId`, `quizTitle`, `questionCount`)
- `networkSessionId` si challenge reseau
- liste des tentatives

## 9. Configuration Android et permissions

Le challenge reseau depend de la stack transfert Wi-Fi.

Manifest (`android/app/src/main/AndroidManifest.xml`):
- `android.permission.INTERNET` (obligatoire sockets TCP)
- `android.permission.CAMERA` (necessaire uniquement pour scan QR)

Autres points:
- les appareils doivent etre sur le meme reseau local
- `MainActivity` doit rester compatible plugins (scanner/auth), donc `FlutterFragmentActivity`

## 10. Limites actuelles

- Pas de chiffrement TLS applicatif sur les sockets.
- Pas d'authentification forte entre appareils.
- Pas encore de lobby "pret/pas pret" avant lancement.
- Classement global local a l'appareil (pas synchronise cloud).

## 11. Fichiers de reference

- `lib/screens/challenge/challenge_center_screen.dart`
- `lib/screens/challenge/challenge_sessions_screen.dart`
- `lib/screens/challenge/challenge_detail_screen.dart`
- `lib/screens/challenge/leaderboard_screen.dart`
- `lib/services/challenge_service.dart`
- `lib/services/quiz_transfer_service.dart`
- `lib/screens/generatequiz/play_quiz_screen.dart`
- `README_TRANSFERT_QUIZ.md`
