import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/biometric_auth_service.dart';

class BiometricAuthScreen extends StatefulWidget {
  const BiometricAuthScreen({super.key});

  @override
  State<BiometricAuthScreen> createState() => _BiometricAuthScreenState();
}

class _BiometricAuthScreenState extends State<BiometricAuthScreen> {
  final BiometricAuthService _bioAuthService = BiometricAuthService();
  bool _isAuthenticating = false;
  String? _errorMessage;
  int _attemptCount = 0;
  static const int _maxAttempts = 5;

  @override
  void initState() {
    super.initState();
    // Lancer l'authentification au démarrage
    Future.delayed(const Duration(milliseconds: 300), _startAuthentication);
  }

  Future<void> _startAuthentication() async {
    if (_isAuthenticating || _attemptCount >= _maxAttempts) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final isAuthenticated = await _bioAuthService.authenticate();

      if (!mounted) return;

      if (isAuthenticated) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        _attemptCount++;
        if (_attemptCount >= _maxAttempts) {
          setState(() {
            _errorMessage = 'Trop de tentatives. Redémarrez l\'application.';
            _isAuthenticating = false;
          });
        } else {
          setState(() {
            _errorMessage =
                'Authentification échouée (${_maxAttempts - _attemptCount} tentatives restantes)';
            _isAuthenticating = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur: $e';
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icône biométrique
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? AppColors.accentYellow.withOpacity(0.1)
                      : AppColors.primaryBlue.withOpacity(0.1),
                ),
                child: Icon(
                  Icons.fingerprint,
                  size: 60,
                  color: isDark
                      ? AppColors.accentYellow
                      : AppColors.primaryBlue,
                ),
              ),

              const SizedBox(height: 30),

              // Titre
              Text(
                'Authentification',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),

              const SizedBox(height: 12),

              // Sous-titre
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _isAuthenticating
                      ? 'Veuillez vous authentifier pour continuer'
                      : 'Appuyez pour vous authentifier',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: isDark
                        ? AppColors.darkText.withOpacity(0.8)
                        : AppColors.lightText.withOpacity(0.8),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Message d'erreur
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.error.withOpacity(0.1),
                  ),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: AppColors.error,
                    ),
                  ),
                ),

              if (_errorMessage != null) const SizedBox(height: 30),

              // Bouton de réessai ou charge
              if (_isAuthenticating)
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(
                      isDark ? AppColors.accentYellow : AppColors.primaryBlue,
                    ),
                  ),
                )
              else if (_attemptCount < _maxAttempts)
                ElevatedButton(
                  onPressed: _startAuthentication,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? AppColors.accentYellow
                        : AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Réessayer',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkText : Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
