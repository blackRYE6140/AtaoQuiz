import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DeviceLockType {
  pattern, // Schéma de déverrouillage
  pin, // Code PIN
  password, // Mot de passe
  biometric, // Biométrie (empreinte, reconnaissance faciale, iris)
  none, // Aucun
}

class SystemAuthService {
  static final SystemAuthService _instance = SystemAuthService._internal();

  factory SystemAuthService() {
    return _instance;
  }

  SystemAuthService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  static const String _lockTypesKey = 'device_lock_types';
  static const String _systemAuthEnabledKey = 'system_auth_enabled';
  static const String _lastSecurityHashKey = 'last_security_hash';

  /// Vérifier si le téléphone a un verrou de sécurité
  Future<bool> isDeviceSecured() async {
    try {
      final canCheckBio = await _localAuth.canCheckBiometrics;
      final isDevSupported = await _localAuth.isDeviceSupported();
      final result = canCheckBio || isDevSupported;

      print(
        '[SystemAuthService] isDeviceSecured: $result (canCheckBio=$canCheckBio, isDevSupported=$isDevSupported)',
      );
      return result;
    } catch (e) {
      print('[SystemAuthService] ERROR checking device security: $e');
      return false;
    }
  }

  /// Obtenir les types de verrous disponibles sur le téléphone
  Future<List<DeviceLockType>> getAvailableLockTypes() async {
    try {
      print('[SystemAuthService] Checking available lock types...');

      final canCheckBio = await _localAuth.canCheckBiometrics;
      final isDevSupported = await _localAuth.isDeviceSupported();

      print(
        '[SystemAuthService] canCheckBiometrics: $canCheckBio, isDeviceSupported: $isDevSupported',
      );

      final biometrics = await _localAuth.getAvailableBiometrics();
      print('[SystemAuthService] Available biometrics: $biometrics');

      final List<DeviceLockType> types = [];

      // Vérifier la biométrie disponible
      if (biometrics.isNotEmpty) {
        types.add(DeviceLockType.biometric);
        print('[SystemAuthService] Added biometric lock type');
      }

      // Vérifier si l'appareil supporte l'authentification (PIN, Pattern, Password, etc)
      if (isDevSupported) {
        // Ajouter PIN comme fallback ou complément
        if (types.isEmpty) {
          types.add(DeviceLockType.pin);
          print('[SystemAuthService] Added PIN lock type (no biometric)');
        } else {
          types.add(DeviceLockType.pin);
          print('[SystemAuthService] Added PIN lock type (with biometric)');
        }
      }

      print('[SystemAuthService] Final lock types: $types');
      return types;
    } catch (e) {
      print('[SystemAuthService] ERROR getting available lock types: $e');
      return [];
    }
  }

  /// Activer l'authentification système pour l'app
  Future<bool> enableSystemAuth() async {
    try {
      print('[SystemAuthService] enableSystemAuth called');
      final prefs = await SharedPreferences.getInstance();
      final lockTypes = await getAvailableLockTypes();

      print('[SystemAuthService] Available lock types: $lockTypes');

      if (lockTypes.isEmpty) {
        print('[SystemAuthService] ERROR: No lock types available');
        return false;
      }

      // Stocker les types de verrous disponibles
      final lockTypeStrings = lockTypes.map((type) => type.toString()).toList();
      print('[SystemAuthService] Storing lock type strings: $lockTypeStrings');

      await prefs.setStringList(_lockTypesKey, lockTypeStrings);

      // Activer l'authentification système
      await prefs.setBool(_systemAuthEnabledKey, true);

      // Créer un hash de la sécurité actuelle
      await _createSecurityHash();

      print('[SystemAuthService] System auth enabled successfully');
      return true;
    } catch (e) {
      print('[SystemAuthService] ERROR in enableSystemAuth: $e');
      return false;
    }
  }

  /// Désactiver l'authentification système pour l'app
  Future<bool> disableSystemAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_systemAuthEnabledKey, false);
      await prefs.remove(_lockTypesKey);
      await prefs.remove(_lastSecurityHashKey);
      return true;
    } catch (e) {
      print('Erreur désactivation auth système: $e');
      return false;
    }
  }

  /// Vérifier si l'authentification système est activée pour l'app
  Future<bool> isSystemAuthEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_systemAuthEnabledKey) ?? false;
    } catch (e) {
      print('Erreur vérification activation auth système: $e');
      return false;
    }
  }

  /// Obtenir les types de verrous stockés lors de l'activation
  Future<List<DeviceLockType>> getEnabledLockTypes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockTypesString = prefs.getStringList(_lockTypesKey) ?? [];

      print(
        '[SystemAuthService] Retrieved stored lock types: $lockTypesString',
      );

      final result = lockTypesString
          .map(
            (type) => DeviceLockType.values.firstWhere(
              (e) => e.toString() == type,
              orElse: () => DeviceLockType.none,
            ),
          )
          .toList();

      print('[SystemAuthService] Converted to DeviceLockType: $result');
      return result;
    } catch (e) {
      print('[SystemAuthService] ERROR in getEnabledLockTypes: $e');
      return [];
    }
  }

  /// Authentifier avec le système
  Future<bool> authenticateWithSystem({String? reason}) async {
    try {
      final result = await _localAuth.authenticate(
        localizedReason: reason ?? 'Authentifiez-vous pour accéder à AtaoQuiz',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Permet PIN, pattern, password, biométrie
        ),
      );
      return result;
    } catch (e) {
      print('Erreur authentification système: $e');
      return false;
    }
  }

  /// Créer un hash de l'état actuel de sécurité
  Future<void> _createSecurityHash() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockTypes = await getAvailableLockTypes();
      final hash = _generateHash(lockTypes.map((t) => t.toString()).join(','));
      await prefs.setString(_lastSecurityHashKey, hash);
    } catch (e) {
      print('Erreur création hash sécurité: $e');
    }
  }

  /// Vérifier si la configuration de sécurité du système a changé
  Future<bool> hasSecurityConfigChanged() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastHash = prefs.getString(_lastSecurityHashKey);

      if (lastHash == null) {
        return false;
      }

      final currentLockTypes = await getAvailableLockTypes();
      final currentHash = _generateHash(
        currentLockTypes.map((t) => t.toString()).join(','),
      );

      return lastHash != currentHash;
    } catch (e) {
      print('Erreur vérification changement sécurité: $e');
      return false;
    }
  }

  /// Obtenir un label lisible pour un type de verrou
  String getLockTypeLabel(DeviceLockType type) {
    switch (type) {
      case DeviceLockType.pattern:
        return 'Schéma de déverrouillage';
      case DeviceLockType.pin:
        return 'Code PIN';
      case DeviceLockType.password:
        return 'Mot de passe';
      case DeviceLockType.biometric:
        return 'Biométrie (Empreinte/Visage/Iris)';
      case DeviceLockType.none:
        return 'Aucun verrou';
    }
  }

  /// Obtenir une description de tous les types de verrous disponibles
  Future<String> getSecurityMethodsDescription() async {
    final types = await getAvailableLockTypes();
    if (types.isEmpty) {
      return 'Aucune méthode de sécurité disponible';
    }

    final labels = types.map((type) => getLockTypeLabel(type)).toList();
    return labels.join(', ');
  }

  /// Générer un simple hash pour comparer les configurations
  String _generateHash(String input) {
    return input.hashCode.toString();
  }
}
