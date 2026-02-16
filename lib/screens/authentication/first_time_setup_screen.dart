import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/colors.dart';
import '../../services/system_auth_service.dart';

class FirstTimeSetupScreen extends StatefulWidget {
  const FirstTimeSetupScreen({super.key});

  @override
  State<FirstTimeSetupScreen> createState() => _FirstTimeSetupScreenState();
}

class _FirstTimeSetupScreenState extends State<FirstTimeSetupScreen> {
  final SystemAuthService _authService = SystemAuthService();
  bool _isLoading = true;
  bool _isDeviceSecured = false;
  String _securityMethodsDescription = '';
  bool _setupComplete = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkDeviceSecurity();
  }

  Future<void> _checkDeviceSecurity() async {
    setState(() => _isLoading = true);

    try {
      final isSecured = await _authService.isDeviceSecured();
      final description = await _authService.getSecurityMethodsDescription();

      setState(() {
        _isDeviceSecured = isSecured;
        _securityMethodsDescription = description;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _enableSystemAuth() async {
    setState(() => _isLoading = true);

    try {
      print('[FirstTimeSetup] Enabling system auth...');
      final success = await _authService.enableSystemAuth();
      print('[FirstTimeSetup] enableSystemAuth result: $success');

      if (!mounted) return;

      if (success) {
        await _markSetupCompleted();

        print('[FirstTimeSetup] System auth enabled successfully');
        setState(() {
          _setupComplete = true;
          _isLoading = false;
        });

        // Attendre 1 seconde avant de naviguer
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            print('[FirstTimeSetup] Navigating to home');
            Navigator.of(context).pushReplacementNamed('/home');
          }
        });
      } else {
        print('[FirstTimeSetup] System auth failed to enable');
        setState(() {
          _errorMessage = 'Impossible d\'activer l\'authentification système';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[FirstTimeSetup] ERROR enabling system auth: $e');
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _skipSetup() async {
    await _markSetupCompleted();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> _markSetupCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_time_setup', false);
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading && !_setupComplete)
                  Column(
                    children: [
                      CircularProgressIndicator(
                        color: isDark
                            ? AppColors.accentYellow
                            : AppColors.primaryBlue,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Vérification de la sécurité de votre appareil...',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                else if (_setupComplete)
                  Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green.withOpacity(0.1),
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          size: 60,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'Authentification configurée !',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Votre appareil est sécurisé avec AtaoQuiz',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                else if (!_isDeviceSecured)
                  Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withOpacity(0.1),
                        ),
                        child: Icon(
                          Icons.lock_open,
                          size: 60,
                          color: Colors.red[400],
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'Appareil non sécurisé',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Vous n\'utilisez pas de verrou de sécurité sur votre appareil.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Pour une meilleure sécurité, veuillez activer un verrou (PIN, motif, mot de passe ou biométrie) dans les paramètres de votre appareil.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: Colors.red[400],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _skipSetup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? AppColors.accentYellow
                                : AppColors.primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Continuer sans sécurité',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
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
                          Icons.lock,
                          size: 60,
                          color: isDark
                              ? AppColors.accentYellow
                              : AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'Configuration de la sécurité',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Votre appareil supporte:',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _securityMethodsDescription,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.accentYellow
                              : AppColors.primaryBlue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'AtaoQuiz utilisera la sécurité de votre appareil pour vous protéger.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      if (_errorMessage != null)
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Colors.red[400],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _enableSystemAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? AppColors.accentYellow
                                : AppColors.primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Activer la sécurité',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _skipSetup,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark
                                  ? AppColors.accentYellow
                                  : AppColors.primaryBlue,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Ignorer pour le moment',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.accentYellow
                                  : AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
