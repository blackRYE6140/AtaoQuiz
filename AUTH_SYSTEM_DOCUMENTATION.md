# Système d'Authentification AtaoQuiz - Nouveau système basé sur l'authentification système

## Vue d'ensemble

Le système d'authentification d'AtaoQuiz a été complètement restructuré pour utiliser **l'authentification système Android** au lieu d'un PIN personnalisé. Cela signifie que l'application utilisera les méthodes de sécurité configurées au niveau du téléphone (empreinte digitale, reconnaissance faciale, PIN système, motif, mot de passe).

## Architecture du système

### 1. **Services Principaux**

#### `SystemAuthService` (`lib/services/system_auth_service.dart`)
Le service principal qui gère toute l'authentification système.

**Fonctionnalités principales:**
- ✅ **Détection de sécurité**: Vérifier si le téléphone a un verrou de sécurité
- ✅ **Détection des types de verrous**: Identifier les méthodes disponibles (PIN, empreinte, visage, motif, mot de passe)
- ✅ **Authentification**: Authentifier via le système Android
- ✅ **Détection de changements**: Détecter si la configuration de sécurité du téléphone change
- ✅ **Gestion persistante**: Sauvegarder l'état d'activation et les types de verrous

### 2. **Écrans d'Interface**

#### `FirstTimeSetupScreen` (`lib/screens/first_time_setup_screen.dart`)
**Première visite de l'application** - Configuration initiale de la sécurité.

- Si le téléphone n'a **PAS** de sécurité:
  - ❌ Affiche un dialogue d'avertissement
  - ✅ Permet de continuer sans sécurité
  
- Si le téléphone **A** une sécurité:
  - ✅ Affiche les méthodes disponibles
  - ✅ Bouton pour activer la liaison avec l'auth système
  - ✅ Option pour ignorer la configuration

#### `SystemAuthScreen` (`lib/screens/system_auth_screen.dart`)
**Écran d'authentification** - S'affiche à chaque entrée dans l'app si l'auth système est activée.

- Affiche un dialogue d'authentification native Android
- Permet d'utiliser:
  - 📱 Empreinte digitale
  - 😊 Reconnaissance faciale
  - 🔢 PIN système
  - 🔷 Motif de déverrouillage
  - 🔑 Mot de passe
  
- **Détection des changements de sécurité**:
  - Si la configuration change, l'app se verrouille automatiquement
  - Message: "La configuration de sécurité de votre appareil a changé"
  - Redirection vers l'écran de configuration

#### `SystemAuthManageScreen` (`lib/screens/system_auth_manage_screen.dart`)
**Gestion de la sécurité** - Accessible depuis Paramètres → Sécurité.

- Affiche l'état actuel:
  - ✅ Si activée: liste les méthodes utilisées
  - ❌ Si désactivée: explique qu'elle n'est pas activée
  
- **Fonctionnalités:**
  - ✅ Désactiver la sécurité (avec confirmation + affichage des risques)
  - ✅ Voir les détails des méthodes actuelles
  - ✅ Avertissements sur les risques de désactivation

### 3. **Flux d'utilisation**

#### Premier lancement de l'app:
```
SplashScreen
    ↓
FirstTimeSetupScreen (détection répertoire)
    ↓
    ├─ Si pas de sécurité → Dialogue d'avertissement
    │                   ↓
    │          Ignorer / Continuer sans sécurité
    │
    └─ Si sécurité OK → Affichage des méthodes
                   ↓
                Bouton "Activer" / "Ignorer"
                   ↓
         Si "Activer" → HomeScreen
         Si "Ignorer" → HomeScreen
```

#### Lancements suivants:
```
SplashScreen
    ↓
SystemAuthScreen (si auth système activée)
    ↓
Authentification native Android
    ↓
    ├─ Succès → HomeScreen
    │
    └─ Échec → Message d'erreur + Réessayer
              (Max 5 tentatives)
```

#### Détection de changement de sécurité:
```
SystemAuthScreen
    ↓
hasSecurityConfigChanged() = true
    ↓
Message: "Configuration modifiée"
    ↓
Redirection vers SplashScreen
    ↓
Nouvelle configuration requise
```

## Fichiers modifiés et créés

### Fichiers créés:
- ✅ `lib/services/system_auth_service.dart` - Service principal
- ✅ `lib/screens/first_time_setup_screen.dart` - Configuration initiale
- ✅ `lib/screens/system_auth_screen.dart` - Authentification
- ✅ `lib/screens/system_auth_manage_screen.dart` - Gestion des paramètres

### Fichiers modifiés:
- ✅ `lib/main.dart` - Ajout des nouvelles routes
- ✅ `lib/screens/splash_screen.dart` - Nouveau flux d'authentification
- ✅ `lib/screens/settings_screen.dart` - Lien vers gestion de sécurité

### Fichiers existants (inchangés mais toujours disponibles):
- `lib/screens/biometric_auth_screen.dart` - Peuvent être supprimés ou gardés
- `lib/screens/pin_entry_screen.dart` - Peuvent être supprimés ou gardés
- `lib/services/security_config_service.dart` - Peuvent être supprimés
- `lib/services/pin_service.dart` - Peuvent être supprimés

## Configuration de SharedPreferences

Clés utilisées:
```dart
'is_first_time_setup'           // bool: true si première visite
'system_auth_enabled'           // bool: true si auth système activée
'device_lock_types'             // List<String>: types de verrous disponibles
'last_security_hash'            // String: hash pour détecter les changements
```

## Types de verrous supportés

```dart
enum DeviceLockType {
  pattern,    // 🔷 Motif de déverrouillage
  pin,        // 🔢 Code PIN
  password,   // 🔑 Mot de passe
  biometric,  // 👁️ Reconnaissance faciale / Empreinte / Iris
  none,       // ❌ Aucun verrou
}
```

## Flux de sécurité détaillé

### Activation initiale:
1. App détecte première visite
2. Affiche `FirstTimeSetupScreen`
3. Vérifie si appareil a sécurité
4. Si oui:
   - Récupère types disponibles
   - Affiche options
   - Crée hash de sécurité
   - Stocke en SharedPreferences
5. Navigue vers `HomeScreen`

### Accès à l'app (après configuration):
1. Affiche `SystemAuthScreen`
2. Lance authentification native
3. Vérifie si configuration a changé:
   - Calcule nouveau hash
   - Compare avec hash stocké
   - Si différent → Redirection vers reconfiguration
4. Si succès → Accès à `HomeScreen`
5. Si échec → Compteur de tentatives

### Gestion de la sécurité (Paramètres):
1. Utilisateur ouvre Paramètres
2. Clique sur "Gestion de la sécurité"
3. Affiche `SystemAuthManageScreen`
4. Peut quitter ou désactiver
5. Si désactivation:
   - Dialogue de confirmation
   - Affiche risques
   - Affiche méthodes actuelles
   - Supprime données d'authentification

## Gestion des erreurs

### Scénarios gérés:

#### Pas de verrou de sécurité:
- ❌ Affiche dialogue d'avertissement
- ✅ Permet quand même d'utiliser l'app
- 💡 Recommande d'activer la sécurité

#### Authentification échouée:
- ❌ Affiche message d'erreur
- 🔄 Permet de réessayer
- ⚠️ Limite à 5 tentatives
- 🔒 Après 5 tentatives: message "Redémarrez l'app"

#### Changement de configuration:
- 🔍 Détecte automatique
- ⚠️ Affiche message d'avertissement
- 📌 Force redirection vers reconfiguration

#### Erreurs réseau/système:
- Try/catch global pour toutes les opérations
- Messages d'erreur lisibles
- Fallback à HomeScreen si nécessaire

## API LocalAuthentication utilisée

```dart
await _localAuth.authenticate(
  localizedReason: 'Authentifiez-vous pour accéder à AtaoQuiz',
  options: const AuthenticationOptions(
    stickyAuth: true,              // Garder dialogue jusqu'à succès/annulation
    biometricOnly: false,          // Autoriser PIN/Pattern système aussi
  ),
);
```

## Maintenance et évolution future

### À considérer:
1. **Notifications**: Alerter utilisateur si sécurité change
2. **Logs**: Tracer les tentatives d'authentification (RGPD)
3. **Expiration**: Session timeout configurable
4. **Biométrie multi-facteur**: Combiner biométrie + PIN
5. **Endpoint sécurisé**: Valider auth avec backend

## Suppression des anciens systèmes

Pour nettoyer le projet et supprimer l'ancien système PIN:

```bash
# Fichiers à supprimer (optionnel):
rm lib/screens/biometric_auth_screen.dart
rm lib/screens/pin_entry_screen.dart
rm lib/screens/pin_setup_dialog.dart
rm lib/screens/security_choice_dialog.dart
rm lib/screens/security_setup_dialog.dart
rm lib/services/security_config_service.dart
rm lib/services/pin_service.dart
```

Puis mettre à jour les imports dans `lib/main.dart`.

## Tests recommandés

```
✅ Première visite (pas de sécurité)
✅ Première visite (avec sécurité)
✅ Authentification réussie
✅ Authentification échouée
✅ 5 tentatives échouées
✅ Changement de PIN système
✅ Activation de nouvelle biométrie
✅ Désactivation de sécurité
✅ Réactivation de sécurité
✅ Changement de thème clair/sombre
```

## Support et dépannage

### L'app ne demande pas l'authentification:
→ Vérifier `SharedPreferences` pour `system_auth_enabled`

### Dialog d'authentification ne s'affiche pas:
→ Vérifier que le téléphone a au moins un verrou activé

### App se verrouille sans raison:
→ Vous avez probablement changé la config de sécurité du système

---

**Version**: 1.0  
**Date**: 2026-02-16  
**Auteur**: AtaoQuiz Auth Team
