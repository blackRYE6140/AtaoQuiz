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
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Êtes-vous sûr de vouloir désactiver la sécurité de AtaoQuiz ?',
                    style: TextStyle(fontFamily: 'Poppins', color: titleColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Méthodes de sécurité actuelles:',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 10),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _buildLockTypeChips(
                        isDark: dialogIsDark,
                        primaryColor: primaryColor,
                        textColor: titleColor,
                      ),
                    ),
                ],
              ),
            ),
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

  List<Widget> _buildLockTypeChips({
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
  }) {
    return _enabledLockTypes.map((type) {
      return Chip(
        avatar: Icon(_lockTypeIcon(type), size: 16, color: primaryColor),
        label: Text(
          _authService.getLockTypeLabel(type),
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: textColor,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        side: BorderSide(color: primaryColor.withValues(alpha: 0.35)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      );
    }).toList();
  }

  BoxDecoration _surfaceDecoration(bool isDark) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  IconData _lockTypeIcon(DeviceLockType type) {
    switch (type) {
      case DeviceLockType.biometric:
        return Icons.fingerprint;
      case DeviceLockType.password:
        return Icons.password;
      case DeviceLockType.pattern:
        return Icons.gesture;
      case DeviceLockType.pin:
        return Icons.pin;
      case DeviceLockType.none:
        return Icons.lock_open;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de la sécurité'),
        centerTitle: true,
        iconTheme: IconThemeData(color: primaryColor),
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: primaryColor,
        ),
        backgroundColor: isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
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
          : LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = constraints.maxWidth < 380
                    ? 12.0
                    : 16.0;
                final maxContentWidth = constraints.maxWidth > 760
                    ? 760.0
                    : constraints.maxWidth;

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 16,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_errorMessage != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: warningBackground,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          if (!_isSystemAuthEnabled)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  decoration: _surfaceDecoration(isDark),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: infoBackground,
                                          child: Icon(
                                            Icons.shield_outlined,
                                            color: primaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Protection désactivée',
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: textColor,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Active la sécurité pour verrouiller AtaoQuiz avec empreinte, PIN ou mot de passe.',
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 13,
                                                  color: secondaryTextColor,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    onPressed: _enableSystemAuth,
                                    icon: const Icon(Icons.lock_open),
                                    label: const Text('Activer la sécurité'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: onPrimaryColor,
                                      textStyle: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  decoration: _surfaceDecoration(isDark),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: infoBackground,
                                      child: Icon(
                                        Icons.verified_user,
                                        color: primaryColor,
                                      ),
                                    ),
                                    title: Text(
                                      'Sécurité activée',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'AtaoQuiz est protégé par l\'authentification système.',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  decoration: _surfaceDecoration(isDark),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Méthodes utilisées',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
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
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: _buildLockTypeChips(
                                              isDark: isDark,
                                              primaryColor: primaryColor,
                                              textColor: textColor,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  decoration: _surfaceDecoration(
                                    isDark,
                                  ).copyWith(color: warningBackground),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              color: primaryColor,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Conseils',
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: primaryColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Si vous désactivez la sécurité:\n'
                                          '• N\'importe qui peut accéder à AtaoQuiz\n'
                                          '• Vos données seront moins protégées\n'
                                          '• Il faudra reconfigurer pour réactiver',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 12,
                                            color: secondaryTextColor,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  height: 52,
                                  child: OutlinedButton.icon(
                                    onPressed: _disableSystemAuth,
                                    icon: const Icon(Icons.lock_reset),
                                    label: const Text('Désactiver la sécurité'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryColor,
                                      side: BorderSide(
                                        color: primaryColor.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                      textStyle: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
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
              },
            ),
    );
  }
}
