import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/biometric_auth_service.dart';
import '../services/security_config_service.dart';

class SecurityChoiceDialog extends StatefulWidget {
  final bool isDark;
  final VoidCallback? onSecurityConfigured;

  const SecurityChoiceDialog({
    super.key,
    required this.isDark,
    this.onSecurityConfigured,
  });

  @override
  State<SecurityChoiceDialog> createState() => _SecurityChoiceDialogState();
}

class _SecurityChoiceDialogState extends State<SecurityChoiceDialog> {
  final BiometricAuthService _bioAuthService = BiometricAuthService();
  final SecurityConfigService _securityConfig = SecurityConfigService();
  bool _isChecking = true;
  bool _isBiometricAvailable = false;
  String _biometricDescription = '';

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final isBioAvailable = await _bioAuthService.isBiometricAvailable();
    final bioDescription = await _bioAuthService
        .getSecurityMethodsDescription();

    setState(() {
      _isBiometricAvailable = isBioAvailable;
      _biometricDescription = bioDescription;
      _isChecking = false;
    });
  }

  Future<void> _selectSecurityType(SecurityType type) async {
    await _securityConfig.setSecurityType(type);
    if (mounted) {
      Navigator.pop(context);
      widget.onSecurityConfigured?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre
            Text(
              'Choisir une méthode de sécurité',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),

            const SizedBox(height: 12),

            // Description
            Text(
              'Sélectionnez comment vous souhaitez sécuriser votre application :',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: widget.isDark
                    ? AppColors.darkText.withOpacity(0.7)
                    : AppColors.lightText.withOpacity(0.7),
              ),
            ),

            const SizedBox(height: 24),

            if (_isChecking)
              Center(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      widget.isDark
                          ? AppColors.accentYellow
                          : AppColors.primaryBlue,
                    ),
                  ),
                ),
              )
            else
              Column(
                children: [
                  // Option Biométrie
                  if (_isBiometricAvailable)
                    _buildSecurityOption(
                      title: 'Biométrie du téléphone',
                      description: 'Utilisez $_biometricDescription',
                      icon: Icons.fingerprint,
                      onTap: () => _selectSecurityType(SecurityType.biometric),
                    )
                  else
                    _buildSecurityOption(
                      title: 'Biométrie du téléphone',
                      description: 'Non disponible sur votre téléphone',
                      icon: Icons.fingerprint,
                      enabled: false,
                    ),

                  const SizedBox(height: 12),

                  // Option Code PIN
                  _buildSecurityOption(
                    title: 'Code PIN personnalisé',
                    description: '4 chiffres uniquement',
                    icon: Icons.password,
                    onTap: () => _selectSecurityType(SecurityType.pin),
                  ),

                  const SizedBox(height: 12),

                  // Option Aucune sécurité
                  _buildSecurityOption(
                    title: 'Pas de sécurité',
                    description: 'Accès direct à l\'application',
                    icon: Icons.lock_open,
                    onTap: () => _selectSecurityType(SecurityType.none),
                    isDestructive: true,
                  ),
                ],
              ),

            const SizedBox(height: 20),

            // Bouton Fermer
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Fermer',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: widget.isDark
                        ? AppColors.accentYellow
                        : AppColors.primaryBlue,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityOption({
    required String title,
    required String description,
    required IconData icon,
    VoidCallback? onTap,
    bool enabled = true,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: enabled
              ? (widget.isDark
                    ? AppColors.darkBackground.withOpacity(0.5)
                    : AppColors.lightBackground)
              : (widget.isDark
                    ? AppColors.darkBackground.withOpacity(0.2)
                    : AppColors.lightBackground.withOpacity(0.5)),
          border: Border.all(
            color: !enabled
                ? AppColors.darkTextSecondary.withOpacity(0.3)
                : (isDestructive
                      ? AppColors.error.withOpacity(0.3)
                      : (widget.isDark
                            ? AppColors.accentYellow.withOpacity(0.2)
                            : AppColors.primaryBlue.withOpacity(0.2))),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: !enabled
                      ? AppColors.darkTextSecondary.withOpacity(0.5)
                      : (isDestructive
                            ? AppColors.error
                            : (widget.isDark
                                  ? AppColors.accentYellow
                                  : AppColors.primaryBlue)),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: !enabled
                          ? AppColors.darkTextSecondary.withOpacity(0.5)
                          : (widget.isDark
                                ? AppColors.darkText
                                : AppColors.lightText),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: !enabled
                    ? AppColors.darkTextSecondary.withOpacity(0.4)
                    : (widget.isDark
                          ? AppColors.darkText.withOpacity(0.6)
                          : AppColors.lightText.withOpacity(0.6)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
