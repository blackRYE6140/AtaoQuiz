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

  @override
  void dispose() {
    _authService.stopAuthentication();
    super.dispose();
  }

  Future<void> _checkSecurityAndStartAuth() async {
    try {
      // Vérifier si la sécurité a changé
      final hasChanged = await _authService.hasSecurityConfigChanged();
      print('[SystemAuth] Security config changed: $hasChanged');

      if (hasChanged) {
        await _handleSecurityConfigurationChanged();
        return;
      }

      // Charger les types de verrous
      final lockTypes = await _authService.getEnabledLockTypes();
      print('[SystemAuth] Enabled lock types: $lockTypes');

      if (lockTypes.isEmpty) {
        print(
          '[SystemAuth] ERROR: No lock types found! System auth may not be properly configured.',
        );
        await _handleSecurityConfigurationChanged();
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

  Future<void> _handleSecurityConfigurationChanged() async {
    if (!mounted) return;

    setState(() {
      _securityChanged = true;
      _isAuthenticating = false;
    });

    // Désactiver l'état d'auth pour éviter une boucle de verrouillage.
    await _authService.disableSystemAuth();

    if (!mounted) return;
    _showSecurityChangeDialog();
  }

  void _showSecurityChangeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Configuration de sécurité modifiée'),
        content: const Text(
          'La configuration de sécurité de votre appareil a changé. '
          'Pour des raisons de sécurité, vous devez reconfigurer AtaoQuiz.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/first-time-setup', (route) => false);
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
      final preferredLockType = _lockTypes.contains(DeviceLockType.biometric)
          ? DeviceLockType.biometric
          : (_lockTypes.isNotEmpty ? _lockTypes.first : null);
      final reason = _lockTypes.isNotEmpty
          ? 'Authentifiez-vous avec ${_authService.getLockTypeLabel(preferredLockType!)}'
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
        final authErrorCode = _authService.lastAuthErrorCode;
        final authErrorMessage = _authService.lastAuthErrorMessage;
        if (authErrorCode != null || authErrorMessage != null) {
          print(
            '[SystemAuth] Authentication detail code=$authErrorCode message=$authErrorMessage',
          );
        }

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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double horizontalPadding = constraints.maxWidth < 360
                ? 16
                : constraints.maxWidth < 640
                ? 24
                : 32;
            final bool isCompactHeight = constraints.maxHeight < 680;
            final double contentMaxWidth = constraints.maxWidth > 700
                ? 460
                : constraints.maxWidth;
            final double circleSize = (constraints.maxWidth * 0.24)
                .clamp(82.0, 110.0)
                .toDouble();
            final double lockIconSize = (circleSize * 0.6).clamp(46.0, 64.0);
            final double titleFontSize = (constraints.maxWidth * 0.06)
                .clamp(20.0, 26.0)
                .toDouble();
            final double bodyFontSize = isCompactHeight ? 13 : 14;
            final double sectionSpacing = isCompactHeight ? 26 : 36;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icône
                        Container(
                          width: circleSize,
                          height: circleSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? AppColors.accentYellow.withOpacity(0.1)
                                : AppColors.primaryBlue.withOpacity(0.1),
                          ),
                          child: Icon(
                            Icons.lock,
                            size: lockIconSize,
                            color: isDark
                                ? AppColors.accentYellow
                                : AppColors.primaryBlue,
                          ),
                        ),
                        SizedBox(height: isCompactHeight ? 20 : 30),

                        // Titre
                        Text(
                          _isAuthenticating
                              ? 'Authentification en cours...'
                              : 'Authentification requise',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 12),

                        // Description
                        if (_lockTypes.isNotEmpty)
                          Text(
                            'Utilisez ${_lockTypes.map((t) => _authService.getLockTypeLabel(t)).join(', ')}',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: bodyFontSize,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),

                        SizedBox(height: sectionSpacing),

                        // Spinner d'authentification
                        if (_isAuthenticating)
                          Column(
                            children: [
                              CircularProgressIndicator(
                                color: isDark
                                    ? AppColors.accentYellow
                                    : AppColors.primaryBlue,
                              ),
                              SizedBox(height: isCompactHeight ? 14 : 20),
                              Text(
                                'Veuillez patienter...',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: bodyFontSize,
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
                                width: double.infinity,
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
                                        fontSize: bodyFontSize,
                                        color: Colors.red[400],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: isCompactHeight ? 20 : 28),
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
                                        color: isDark
                                            ? Colors.black
                                            : Colors.white,
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
                                size: (circleSize * 0.8).clamp(56.0, 88.0),
                                color: isDark
                                    ? AppColors.accentYellow.withOpacity(0.5)
                                    : AppColors.primaryBlue.withOpacity(0.5),
                              ),
                              SizedBox(height: isCompactHeight ? 14 : 20),
                              Text(
                                'Appuyez sur votre capteur d\'empreinte\nou utilisez votre visage',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: bodyFontSize,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),

                        SizedBox(height: sectionSpacing),

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
          },
        ),
      ),
    );
  }
}
