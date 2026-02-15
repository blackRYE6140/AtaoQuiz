import 'package:shared_preferences/shared_preferences.dart';

class PinService {
  static const String _pinKey = 'app_pin_code';
  static const String _pinEnabledKey = 'pin_enabled';
  static const int _pinLength = 4;

  /// Vérifier si le PIN est activé
  Future<bool> isPinEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinEnabledKey) ?? false;
  }

  /// Vérifier si un PIN est stocké
  Future<bool> hasPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString(_pinKey);
    return pin != null && pin.isNotEmpty;
  }

  /// Vérifier un PIN
  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString(_pinKey);
    return storedPin == pin && pin.length == _pinLength;
  }

  /// Créer/définir un nouveau PIN
  Future<bool> setPin(String pin) async {
    if (pin.length != _pinLength || !_isNumeric(pin)) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
    await prefs.setBool(_pinEnabledKey, true);
    return true;
  }

  /// Modifier un PIN existant (après vérification de l'ancien)
  Future<bool> updatePin(String oldPin, String newPin) async {
    if (!await verifyPin(oldPin)) {
      return false;
    }
    return await setPin(newPin);
  }

  /// Supprimer le PIN
  Future<bool> removePin(String pin) async {
    if (!await verifyPin(pin)) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.setBool(_pinEnabledKey, false);
    return true;
  }

  /// Désactiver/Réactiver le PIN
  Future<void> togglePinEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pinEnabledKey, enabled);
  }

  /// Vérifier si le PIN est numérique uniquement
  bool _isNumeric(String value) {
    return int.tryParse(value) != null;
  }

  /// Obtenir la longueur du PIN
  static int getPinLength() => _pinLength;
}
