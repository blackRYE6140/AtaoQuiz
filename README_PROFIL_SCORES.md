# Profil et Scores (AtaoQuiz)

Ce document couvre les fonctionnalites `Profil` et `Mes Scores` ainsi que leur synchronisation dans challenge/classement.

## 1. Objectif

Fournir une identite joueur unique et des statistiques coherentes:
- profil unique (nom + avatar/photo)
- reutilisation du profil dans toute l'app
- historique des performances en entrainement et challenge

## 2. Architecture

### 2.1 Ecrans
- `lib/screens/profile_screen.dart`
- `lib/screens/scores/my_scores_screen.dart`
- `lib/screens/home_screen.dart` (avatar appbar)
- `lib/screens/challenge/challenge_sessions_screen.dart`
- `lib/screens/challenge/challenge_detail_screen.dart`
- `lib/screens/challenge/leaderboard_screen.dart`

### 2.2 Services/composants
- `lib/services/user_profile_service.dart`
- `lib/services/challenge_service.dart`
- `lib/services/storage_service.dart`
- `lib/components/profile_avatar.dart`

## 3. Modele profil

`UserProfile` contient:
- `displayName`
- `avatarIndex` (avatar icone)
- `profileImageBase64` (image importee, optionnelle)
- `isConfigured`

Nom par defaut: `Moi`.

## 4. Gestion du profil

Dans `ProfileScreen`, l'utilisateur peut:
1. modifier le nom
2. choisir un avatar icone
3. importer une image locale
4. enregistrer le profil

Comportements importants:
- renommage synchronise: si le nom change, les sessions challenge sont mises a jour (`renamePlayerInAllSessions`)
- image importee prioritaire sur l'avatar icone
- l'avatar de l'appbar home est remplace automatiquement apres sauvegarde

## 5. Import image profil

Pipeline d'import:
1. selection image via `file_picker`
2. validation taille source max `5 Mo`
3. recadrage centre en carre
4. redimensionnement/optimisation PNG (cibles progressives)
5. stockage final vise `<= 220 Ko`

Affichage:
- rendu circulaire avec `ProfileAvatar`
- meme visuel reutilise dans home/challenge/classement/scores

## 6. Setup profil guide (challenge/classement)

Si le profil n'est pas configure:
- premiere ouverture de `Challenges` ou `Classement` peut afficher un popup
- le popup redirige vers `ProfileScreen` (`setupFlow`)
- chaque zone n'affiche le popup qu'une seule fois

Clés de prompt:
- `user_profile_prompt_challenge_shown_v1`
- `user_profile_prompt_leaderboard_shown_v1`

## 7. Synchronisation challenge et leaderboard

Le profil est injecte dans:
- details challenge (profil actif)
- resultats challenge live Wi-Fi (nom + image de chaque joueur)
- affichage hote dans challenge reseau
- classement global (avatar a droite de l'entree)

## 8. Ecran Mes Scores

`MyScoresScreen` propose 3 onglets:
1. `Quiz`
2. `Defis amis`
3. `Defis chrono`

Sources de donnees:
- quiz: `StorageService.getQuizzes()`
- challenges: `ChallengeService.getSessions()` (filtrage sur joueur courant)

Informations affichees:
- score / total
- pourcentage
- temps de completion
- date
- contexte `Local` ou `Reseau`

## 9. Stats profil synchronisees

`ProfileScreen` affiche:
- quiz resolus
- score moyen
- trophees
- victoires challenge
- victoires chrono

Calcul:
- quiz resolus + moyenne entrainement depuis `StorageService`
- stats challenge/classement depuis `ChallengeService.getLeaderboard()`

## 10. Persistance locale

Clés `SharedPreferences`:
- `user_profile_display_name_v1`
- `user_profile_avatar_index_v1`
- `user_profile_image_base64_v1`
- `user_profile_is_configured_v1`
- `user_profile_prompt_challenge_shown_v1`
- `user_profile_prompt_leaderboard_shown_v1`

Compatibilite legacy:
- lecture possible de `challenge_local_player_name_v1` pour migration du nom ancien format.

## 11. Fichiers de reference

- `lib/screens/profile_screen.dart`
- `lib/screens/scores/my_scores_screen.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/challenge/challenge_sessions_screen.dart`
- `lib/screens/challenge/challenge_detail_screen.dart`
- `lib/screens/challenge/leaderboard_screen.dart`
- `lib/components/profile_avatar.dart`
- `lib/services/user_profile_service.dart`
- `lib/services/challenge_service.dart`
- `lib/services/storage_service.dart`
