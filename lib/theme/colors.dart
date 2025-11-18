import 'package:flutter/material.dart';

/// Couleurs principales du thème AtaoQuiz
class AppColors {
  // Couleurs de marque
  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color accentYellow = Color(0xFFFFD54F);

  // Mode clair
  static const Color lightBackground = Color(0xFFF5F9FF);
  static const Color lightText = Color(0xFF1E1E1E);
  static const Color lightCard = Colors.white;

  // Mode sombre
  static const Color darkBackground = Color.fromARGB(255, 17, 21, 36);
  static const Color darkText = Color(0xFFEAEAEA);
  // rgb(12,15,27) -> hex 0C0F1B, add full opacity (0xFF)
  static const Color darkCard = Color(0xFF0A3D62);

  // ✅ Couleurs sémantiques
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA000);
  static const Color info = Color(0xFF29B6F6);

  // ⚪ Couleurs utilitaires / neutres
  static const Color gray100 = Color(0xFFF5F5F5);
  static const Color gray800 = Color.fromARGB(255, 10, 58, 92);
  static const Color darkTextSecondary = Color(0xFFA0A0A0);
  static const Color lightTextSecondary = Color(0xFF666666);

  // Dégradé principal
  static const LinearGradient mainGradient = LinearGradient(
    colors: [primaryBlue, accentYellow],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
