import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../services/system_auth_service.dart';

class SystemAuthManageScreen extends StatefulWidget {
  const SystemAuthManageScreen({super.key});

  @override
  State<SystemAuthManageScreen> createState() => _SystemAuthManageScreenState();
}

class _SystemAuthManageScreenState extends State<SystemAuthManageScreen> {
  final SystemAuthService _authService = SystemAuthService();
  bool _isLoading = true;
  bool _isSystemAuthEnabled = false;
  List<DeviceLockType> _enabledLockTypes = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAuthStatus();
  }

  Future<void> _loadAuthStatus() async {
    setState(() => _isLoading = true);

    try {
      final isEnabled = await _authService.isSystemAuthEnabled();
      final lockTypes = isEnabled
          ? await _authService.getAvailableLockTypes()
          : <DeviceLockType>[];

      setState(() {
        _isSystemAuthEnabled = isEnabled;
        _enabledLockTypes = lockTypes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _disableSystemAuth() async {
    // Afficher un dialogue de confirmation
    final shouldDisable = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogIsDark = Theme.of(context).brightness == Brightness.dark;
        final titleColor = dialogIsDark
            ? AppColors.darkText
            : AppColors.lightText;
        final secondaryColor = dialogIsDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary;
        final cardColor = dialogIsDark
            ? AppColors.darkCard
            : AppColors.lightCard;
        final primaryColor = dialogIsDark
            ? AppColors.accentYellow
            : AppColors.primaryBlue;

        return AlertDialog(
          backgroundColor: cardColor,
          title: Text(
            'Désactiver la sécurité',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Êtes-vous sûr de vouloir désactiver la sécurité de AtaoQuiz ?',
                style: TextStyle(fontFamily: 'Poppins', color: titleColor),
              ),
              const SizedBox(height: 15),
              Text(
                'Méthodes de sécurité actuelles:',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 8),
              if (_enabledLockTypes.isEmpty)
                Text(
                  'Aucune méthode détectée',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: secondaryColor,
                  ),
                )
              else
                ..._enabledLockTypes.map(
                  (type) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text(
                      '• ${_authService.getLockTypeLabel(type)}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: secondaryColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Annuler',
                style: TextStyle(fontFamily: 'Poppins', color: primaryColor),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Désactiver',
                style: TextStyle(fontFamily: 'Poppins', color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDisable != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isVerified = await _authService.authenticateWithSystem(
        reason: 'Confirmez votre identité pour désactiver la sécurité AtaoQuiz',
      );

      if (!isVerified) {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Vérification d\'identité requise pour désactiver la sécurité';
          _isLoading = false;
        });
        return;
      }

      final success = await _authService.disableSystemAuth();

      if (!mounted) return;

      if (success) {
        setState(() {
          _isSystemAuthEnabled = false;
          _enabledLockTypes = [];
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sécurité désactivée'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Impossible de désactiver la sécurité';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _enableSystemAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isDeviceSecured = await _authService.isDeviceSecured();
      if (!isDeviceSecured) {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Aucun verrou système détecté. Activez un PIN/mot de passe/biométrie dans les paramètres du téléphone.';
          _isLoading = false;
        });
        return;
      }

      final success = await _authService.enableSystemAuth();
      if (!mounted) return;

      if (success) {
        final lockTypes = await _authService.getAvailableLockTypes();
        if (!mounted) return;

        setState(() {
          _isSystemAuthEnabled = true;
          _enabledLockTypes = lockTypes;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sécurité activée'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _errorMessage =
              'Impossible d\'activer la sécurité. Vérifiez la configuration de verrouillage Android.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppColors.accentYellow
        : AppColors.primaryBlue;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final secondaryTextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final onPrimaryColor = isDark ? Colors.black : Colors.white;
    final infoBackground = primaryColor.withValues(alpha: 0.12);
    final warningBackground = AppColors.error.withValues(alpha: 0.12);
    final neutralBackground = secondaryTextColor.withValues(alpha: 0.12);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de la sécurité'),
        backgroundColor: isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
        foregroundColor: textColor,
        elevation: 0,
      ),
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? AppColors.accentYellow : AppColors.primaryBlue,
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: warningBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    if (!_isSystemAuthEnabled)
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: infoBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: primaryColor),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'L\'authentification système est désactivée.',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _enableSystemAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
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
                                  color: onPrimaryColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Authentification système',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: neutralBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: AppColors.success,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Activée',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Méthodes de sécurité utilisées:',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: secondaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_enabledLockTypes.isEmpty)
                                  Text(
                                    'Aucune méthode détectée',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      color: secondaryTextColor,
                                    ),
                                  )
                                else
                                  ..._enabledLockTypes.map(
                                    (type) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            '• ',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: primaryColor,
                                            ),
                                          ),
                                          Text(
                                            _authService.getLockTypeLabel(type),
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 13,
                                              color: textColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          Text(
                            'Risques de sécurité',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: warningBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Si vous désactivez la sécurité:',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.error,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '• N\'importe qui peut accéder à AtaoQuiz\n'
                                  '• Vos données seront moins protégées\n'
                                  '• Il faudra reconfigurer pour réactiver',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _disableSystemAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Désactiver la sécurité',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
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
    );
  }
}
