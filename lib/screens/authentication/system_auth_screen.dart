import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../services/system_auth_service.dart';

class SystemAuthScreen extends StatefulWidget {
  const SystemAuthScreen({super.key});

  @override
  State<SystemAuthScreen> createState() => _SystemAuthScreenState();
}

class _SystemAuthScreenState extends State<SystemAuthScreen> {
  final SystemAuthService _authService = SystemAuthService();
  bool _isAuthenticating = false;
  String? _errorMessage;
  int _attemptCount = 0;
  static const int _maxAttempts = 5;
  List<DeviceLockType> _lockTypes = [];
  bool _securityChanged = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(
      const Duration(milliseconds: 300),
      _checkSecurityAndStartAuth,
    );
  }

  Future<void> _checkSecurityAndStartAuth() async {
    try {
      // Vérifier si la sécurité a changé
      final hasChanged = await _authService.hasSecurityConfigChanged();
      print('[SystemAuth] Security config changed: $hasChanged');

      if (hasChanged) {
        // La sécurité a changé, verrouiller l'app
        if (mounted) {
          setState(() => _securityChanged = true);
          _showSecurityChangeDialog();
        }
        return;
      }

      // Charger les types de verrous
      final lockTypes = await _authService.getEnabledLockTypes();
      print('[SystemAuth] Enabled lock types: $lockTypes');

      if (lockTypes.isEmpty) {
        print(
          '[SystemAuth] ERROR: No lock types found! System auth may not be properly configured.',
        );
        if (mounted) {
          setState(() {
            _errorMessage =
                'Erreur: L\'authentification système n\'est pas configurée correctement.';
            _isAuthenticating = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _lockTypes = lockTypes);
        _startAuthentication();
      }
    } catch (e) {
      print('[SystemAuth] ERROR in _checkSecurityAndStartAuth: $e');
      if (mounted) {
        setState(() {
          _errorMessage =
              'Erreur lors du chargement de l\'authentification: $e';
          _isAuthenticating = false;
        });
      }
    }
  }

  void _showSecurityChangeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Configuration de sécurité modifiée'),
        content: const Text(
          'La configuration de sécurité de votre appareil a changé. '
          'Pour des raisons de sécurité, vous devez reconfigurer AtaoQuiz.\n\n'
          'L\'application va redémarrer.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushReplacementNamed('/');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _startAuthentication() async {
    if (_isAuthenticating ||
        _attemptCount >= _maxAttempts ||
        _securityChanged) {
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final reason = _lockTypes.isNotEmpty
          ? 'Authentifiez-vous avec ${_authService.getLockTypeLabel(_lockTypes.first)}'
          : 'Authentifiez-vous pour accéder à AtaoQuiz';

      print('[SystemAuth] Starting authentication with reason: $reason');

      final isAuthenticated = await _authService.authenticateWithSystem(
        reason: reason,
      );

      print('[SystemAuth] Authentication result: $isAuthenticated');

      if (!mounted) return;

      if (isAuthenticated) {
        print('[SystemAuth] Authentication successful, navigating to home');
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        _attemptCount++;
        print(
          '[SystemAuth] Authentication failed. Attempts: $_attemptCount/$_maxAttempts',
        );

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
      print('[SystemAuth] ERROR during authentication: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur: $e';
          _isAuthenticating = false;
        });
      }
    }
  }

  void _onRetry() {
    setState(() => _errorMessage = null);
    _startAuthentication();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_securityChanged) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                // Icône
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

                // Titre
                Text(
                  _isAuthenticating
                      ? 'Authentification en cours...'
                      : 'Authentification requise',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 15),

                // Description
                if (_lockTypes.isNotEmpty)
                  Text(
                    'Utilisez ${_lockTypes.map((t) => _authService.getLockTypeLabel(t)).join(', ')}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                const SizedBox(height: 40),

                // Spinner d'authentification
                if (_isAuthenticating)
                  Column(
                    children: [
                      CircularProgressIndicator(
                        color: isDark
                            ? AppColors.accentYellow
                            : AppColors.primaryBlue,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Veuillez patienter...',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  )
                else if (_errorMessage != null)
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red[400],
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Colors.red[400],
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      if (_attemptCount < _maxAttempts)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _onRetry,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? AppColors.accentYellow
                                  : AppColors.primaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Réessayer',
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
                      Icon(
                        Icons.fingerprint,
                        size: 80,
                        color: isDark
                            ? AppColors.accentYellow.withOpacity(0.5)
                            : AppColors.primaryBlue.withOpacity(0.5),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Appuyez sur votre capteur d\'empreinte\nou utilisez votre visage',
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
                  ),

                const SizedBox(height: 40),

                // Aide
                if (!_isAuthenticating)
                  GestureDetector(
                    onTap: _startAuthentication,
                    child: Text(
                      'Cliquez pour réessayer',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: isDark
                            ? AppColors.accentYellow
                            : AppColors.primaryBlue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
