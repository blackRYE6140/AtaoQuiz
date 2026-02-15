import 'package:shared_preferences/shared_preferences.dart';

enum SecurityType {
  pin, // Code PIN personnalisé
  biometric, // Biométrie du téléphone
  none, // Pas de sécurité
}

class SecurityConfigService {
  static const String _securityTypeKey = 'security_type';
  static const String _securityEnabledKey = 'security_enabled';

  /// Obtenir le type de sécurité configuré
  Future<SecurityType> getSecurityType() async {
    final prefs = await SharedPreferences.getInstance();
    final typeString = prefs.getString(_securityTypeKey);

    if (typeString == null) {
      return SecurityType.none;
    }

    return SecurityType.values.firstWhere(
      (e) => e.toString() == typeString,
      orElse: () => SecurityType.none,
    );
  }

  /// Vérifier si la sécurité est activée
  Future<bool> isSecurityEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_securityEnabledKey) ?? false;
  }

  /// Définir le type de sécurité
  Future<bool> setSecurityType(SecurityType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_securityTypeKey, type.toString());
    await prefs.setBool(_securityEnabledKey, type != SecurityType.none);
    return true;
  }

  /// Désactiver la sécurité
  Future<bool> disableSecurity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_securityTypeKey);
    await prefs.setBool(_securityEnabledKey, false);
    return true;
  }

  /// Obtenir un rapport lisible du type de sécurité
  String getSecurityTypeLabel(SecurityType type) {
    switch (type) {
      case SecurityType.pin:
        return 'Code PIN';
      case SecurityType.biometric:
        return 'Biométrie du téléphone';
      case SecurityType.none:
        return 'Aucune sécurité';
    }
  }
}
