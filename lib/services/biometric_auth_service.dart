import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  static final BiometricAuthService _instance =
      BiometricAuthService._internal();

  factory BiometricAuthService() {
    return _instance;
  }

  BiometricAuthService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Vérifier si la biométrie est disponible
  Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      print('Erreur vérification biométrie: $e');
      return false;
    }
  }

  /// Obtenir les types de biométrie disponibles
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final List<BiometricType> availableBiometrics = await _localAuth
          .getAvailableBiometrics();
      return availableBiometrics;
    } catch (e) {
      print('Erreur récupération biométries: $e');
      return [];
    }
  }

  /// Authentifier avec biométrie
  Future<bool> authenticate() async {
    try {
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Veuillez vous authentifier pour accéder à AtaoQuiz',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Permet aussi le PIN/mot de passe système
        ),
      );
      return isAuthenticated;
    } catch (e) {
      print('Erreur authentification biométrique: $e');
      return false;
    }
  }

  /// Obtenir un label lisible pour le type de biométrie
  String getBiometricLabel(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Reconnaissance faciale';
      case BiometricType.fingerprint:
        return 'Empreinte digitale';
      case BiometricType.iris:
        return 'Reconnaissance iris';
      case BiometricType.strong:
        return 'Authentification forte';
      case BiometricType.weak:
        return 'Authentification faible';
    }
  }

  /// Obtenir un descrytif des méthodes disponibles
  Future<String> getSecurityMethodsDescription() async {
    final methods = await getAvailableBiometrics();
    if (methods.isEmpty) {
      return 'Aucune méthode biométrique disponible';
    }

    final labels = methods.map((type) => getBiometricLabel(type)).toList();
    return labels.join(', ');
  }
}
