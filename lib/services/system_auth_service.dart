import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DeviceLockType {
  pattern, // Schéma de déverrouillage
  pin, // Verrou système (PIN, schéma ou mot de passe)
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
  static const MethodChannel _deviceCredentialChannel = MethodChannel(
    'atao_quiz/device_credential',
  );
  static const String _lockTypesKey = 'device_lock_types';
  static const String _systemAuthEnabledKey = 'system_auth_enabled';
  static const String _lastSecurityHashKey = 'last_security_hash';
  String? _lastAuthErrorCode;
  String? _lastAuthErrorMessage;

  String? get lastAuthErrorCode => _lastAuthErrorCode;
  String? get lastAuthErrorMessage => _lastAuthErrorMessage;

  /// Vérifier si le téléphone a un verrou de sécurité
  Future<bool> isDeviceSecured() async {
    try {
      final lockTypes = await getAvailableLockTypes();
      final result = lockTypes.isNotEmpty;

      debugPrint('[SystemAuthService] isDeviceSecured: $result');
      return result;
    } catch (e) {
      debugPrint('[SystemAuthService] ERROR checking device security: $e');
      return false;
    }
  }

  /// Obtenir les types de verrous disponibles sur le téléphone
  Future<List<DeviceLockType>> getAvailableLockTypes() async {
    try {
      debugPrint('[SystemAuthService] Checking available lock types...');

      final canCheckBio = await _localAuth.canCheckBiometrics;
      final isDevSupported = await _localAuth.isDeviceSupported();

      debugPrint(
        '[SystemAuthService] canCheckBiometrics: $canCheckBio, isDeviceSupported: $isDevSupported',
      );

      final Set<DeviceLockType> types = <DeviceLockType>{};

      if (canCheckBio) {
        try {
          final biometrics = await _localAuth.getAvailableBiometrics();
          debugPrint('[SystemAuthService] Available biometrics: $biometrics');
          if (biometrics.isNotEmpty) {
            types.add(DeviceLockType.biometric);
          }
        } catch (e) {
          // Some devices throw while listing biometrics. Keep fallback auth.
          debugPrint(
            '[SystemAuthService] getAvailableBiometrics failed, fallback to device credential: $e',
          );
        }
      }

      // Vérifier si l'appareil supporte l'authentification (PIN, Pattern, Password, etc)
      if (isDevSupported) {
        types.add(DeviceLockType.pin);
      }

      final result = types.toList()..sort((a, b) => a.index.compareTo(b.index));
      debugPrint('[SystemAuthService] Final lock types: $result');
      return result;
    } catch (e) {
      debugPrint('[SystemAuthService] ERROR getting available lock types: $e');
      return [];
    }
  }

  /// Activer l'authentification système pour l'app
  Future<bool> enableSystemAuth({
    bool requireCurrentUserVerification = false,
  }) async {
    try {
      debugPrint('[SystemAuthService] enableSystemAuth called');
      final prefs = await SharedPreferences.getInstance();
      final lockTypes = await getAvailableLockTypes();

      debugPrint('[SystemAuthService] Available lock types: $lockTypes');

      if (lockTypes.isEmpty) {
        debugPrint('[SystemAuthService] ERROR: No lock types available');
        return false;
      }

      if (requireCurrentUserVerification) {
        final isVerified = await authenticateWithSystem(
          reason: 'Confirmez votre identité pour activer la sécurité',
        );
        if (!isVerified) {
          debugPrint(
            '[SystemAuthService] User verification failed while enabling auth',
          );
          return false;
        }
      }

      if (!await isDeviceSecured()) {
        debugPrint('[SystemAuthService] Device is not secured anymore');
        return false;
      }

      // Stocker les types de verrous disponibles
      final lockTypeStrings = lockTypes.map((type) => type.name).toList();
      debugPrint(
        '[SystemAuthService] Storing lock type strings: $lockTypeStrings',
      );

      await prefs.setStringList(_lockTypesKey, lockTypeStrings);

      // Activer l'authentification système
      await prefs.setBool(_systemAuthEnabledKey, true);

      // Stocker une signature stable de la sécurité actuelle
      await _storeSecuritySignature(lockTypes);

      debugPrint('[SystemAuthService] System auth enabled successfully');
      return true;
    } catch (e) {
      debugPrint('[SystemAuthService] ERROR in enableSystemAuth: $e');
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
      debugPrint('Erreur désactivation auth système: $e');
      return false;
    }
  }

  /// Vérifier si l'authentification système est activée pour l'app
  Future<bool> isSystemAuthEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_systemAuthEnabledKey) ?? false;
    } catch (e) {
      debugPrint('Erreur vérification activation auth système: $e');
      return false;
    }
  }

  /// Obtenir les types de verrous stockés lors de l'activation
  Future<List<DeviceLockType>> getEnabledLockTypes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockTypesString = prefs.getStringList(_lockTypesKey) ?? [];

      debugPrint(
        '[SystemAuthService] Retrieved stored lock types: $lockTypesString',
      );

      final result = lockTypesString
          .map(_parseStoredLockType)
          .where((type) => type != DeviceLockType.none)
          .toList();

      debugPrint('[SystemAuthService] Converted to DeviceLockType: $result');
      return result;
    } catch (e) {
      debugPrint('[SystemAuthService] ERROR in getEnabledLockTypes: $e');
      return [];
    }
  }

  /// Authentifier avec le système
  Future<bool> authenticateWithSystem({String? reason}) async {
    _lastAuthErrorCode = null;
    _lastAuthErrorMessage = null;

    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) {
        _setLastAuthError(
          code: 'device_not_supported',
          message: 'Device does not support local auth.',
        );
        return false;
      }

      final result = await _localAuth.authenticate(
        localizedReason: reason ?? 'Authentifiez-vous pour accéder à AtaoQuiz',
        options: const AuthenticationOptions(
          // Keep this false to avoid OEM-specific loops when switching from
          // biometric prompt to credential screens.
          stickyAuth: false,
          sensitiveTransaction: true,
          biometricOnly: false, // Permet PIN, pattern, password, biométrie
        ),
      );

      if (!result) {
        _setLastAuthError(
          code: 'auth_failed_or_canceled',
          message:
              'Authentication returned false (canceled by user or credential rejected).',
        );

        // Ensure no residual prompt is still active before manual fallback.
        await stopAuthentication();

        final fallbackSuccess =
            await _authenticateWithDeviceCredentialFallback();
        if (fallbackSuccess) {
          _lastAuthErrorCode = null;
          _lastAuthErrorMessage = null;
          return true;
        }
      }
      return result;
    } on PlatformException catch (e) {
      _setLastAuthError(
        code: e.code,
        message: e.message ?? 'PlatformException without message',
      );

      await stopAuthentication();
      final fallbackSuccess = await _authenticateWithDeviceCredentialFallback();
      if (fallbackSuccess) {
        _lastAuthErrorCode = null;
        _lastAuthErrorMessage = null;
        return true;
      }

      if (e.code == auth_error.notAvailable ||
          e.code == auth_error.notEnrolled ||
          e.code == auth_error.passcodeNotSet ||
          e.code == auth_error.lockedOut ||
          e.code == auth_error.permanentlyLockedOut) {
        return false;
      }
      return false;
    } catch (e) {
      _setLastAuthError(code: 'unknown_exception', message: e.toString());
      return false;
    }
  }

  /// Arrêter une authentification en cours (utile à la fermeture d'écran)
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      debugPrint('Erreur arrêt authentification système: $e');
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
      final currentSignature = _buildSecuritySignature(currentLockTypes);

      if (lastHash == currentSignature) {
        return false;
      }

      // Migration de l'ancien format (hashCode) vers signature stable.
      final legacyHash = _buildLegacySecurityHash(currentLockTypes);
      if (lastHash == legacyHash) {
        await prefs.setString(_lastSecurityHashKey, currentSignature);
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Erreur vérification changement sécurité: $e');
      return false;
    }
  }

  /// Obtenir un label lisible pour un type de verrou
  String getLockTypeLabel(DeviceLockType type) {
    switch (type) {
      case DeviceLockType.pattern:
        return 'Schéma de déverrouillage';
      case DeviceLockType.pin:
        return 'Verrouillage appareil (PIN/Schéma/Mot de passe)';
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

  Future<void> _storeSecuritySignature(List<DeviceLockType> lockTypes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final signature = _buildSecuritySignature(lockTypes);
      await prefs.setString(_lastSecurityHashKey, signature);
    } catch (e) {
      debugPrint('Erreur stockage signature sécurité: $e');
    }
  }

  DeviceLockType _parseStoredLockType(String value) {
    final normalized = value.contains('.') ? value.split('.').last : value;
    return DeviceLockType.values.firstWhere(
      (type) => type.name == normalized,
      orElse: () => DeviceLockType.none,
    );
  }

  String _buildSecuritySignature(List<DeviceLockType> lockTypes) {
    final normalized =
        lockTypes
            .where((type) => type != DeviceLockType.none)
            .map((type) => type.name)
            .toSet()
            .toList()
          ..sort();
    return normalized.join('|');
  }

  String _buildLegacySecurityHash(List<DeviceLockType> lockTypes) {
    final input = lockTypes.map((type) => type.toString()).join(',');
    return input.hashCode.toString();
  }

  Future<bool> _authenticateWithDeviceCredentialFallback() async {
    try {
      final isAvailable =
          await _deviceCredentialChannel.invokeMethod<bool>(
            'isDeviceCredentialAvailable',
          ) ??
          false;
      if (!isAvailable) {
        return false;
      }

      final isAuthenticated =
          await _deviceCredentialChannel.invokeMethod<bool>(
            'authenticateWithDeviceCredential',
            const <String, String>{
              'title': 'Authentification requise',
              'description': 'Entrez votre schéma, PIN ou mot de passe',
            },
          ) ??
          false;

      if (!isAuthenticated) {
        _setLastAuthError(
          code: 'device_credential_failed_or_canceled',
          message: 'Device credential authentication returned false.',
        );
      }

      return isAuthenticated;
    } on PlatformException catch (e) {
      _setLastAuthError(
        code: 'device_credential_${e.code}',
        message: e.message ?? 'Device credential platform exception.',
      );
      return false;
    } catch (e) {
      _setLastAuthError(
        code: 'device_credential_unknown_exception',
        message: e.toString(),
      );
      return false;
    }
  }

  void _setLastAuthError({required String code, required String message}) {
    _lastAuthErrorCode = code;
    _lastAuthErrorMessage = message;
    debugPrint('[SystemAuthService] Auth error code=$code message=$message');
  }
}
