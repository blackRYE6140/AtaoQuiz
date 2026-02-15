import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/pin_service.dart';
import '../services/security_config_service.dart';
import 'security_choice_dialog.dart';

class SecuritySetupDialog extends StatefulWidget {
  final bool isDark;

  const SecuritySetupDialog({super.key, required this.isDark});

  @override
  State<SecuritySetupDialog> createState() => _SecuritySetupDialogState();
}

class _SecuritySetupDialogState extends State<SecuritySetupDialog> {
  final PinService _pinService = PinService();
  final SecurityConfigService _securityConfig = SecurityConfigService();

  late TextEditingController _pinController;
  late TextEditingController _confirmPinController;
  late TextEditingController _oldPinController;

  SecurityType _currentSecurityType = SecurityType.none;
  String _currentStep =
      'overview'; // overview, setupPin, modifyPin, deletePin, changeMethod
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
    _confirmPinController = TextEditingController();
    _oldPinController = TextEditingController();
    _initializeSecurityStatus();
  }

  Future<void> _initializeSecurityStatus() async {
    final securityType = await _securityConfig.getSecurityType();

    setState(() {
      _currentSecurityType = securityType;
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _oldPinController.dispose();
    super.dispose();
  }

  void _showSecurityChoiceDialog() {
    showDialog(
      context: context,
      builder: (context) => SecurityChoiceDialog(
        isDark: widget.isDark,
        onSecurityConfigured: () {
          _initializeSecurityStatus();
          setState(() => _currentStep = 'overview');
        },
      ),
    );
  }

  Future<void> _setupPin() async {
    if (_pinController.text.length != 4 ||
        _confirmPinController.text.length != 4) {
      setState(() => _errorMessage = 'Le PIN doit contenir 4 chiffres.');
      return;
    }

    if (_pinController.text != _confirmPinController.text) {
      setState(() => _errorMessage = 'Les PINs ne correspondent pas.');
      return;
    }

    if (!_isNumeric(_pinController.text)) {
      setState(
        () => _errorMessage = 'Le PIN doit contenir uniquement des chiffres.',
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await _pinService.setPin(_pinController.text);

    setState(() => _isLoading = false);

    if (success) {
      await _securityConfig.setSecurityType(SecurityType.pin);
      if (mounted) {
        setState(() => _currentSecurityType = SecurityType.pin);
        _showSuccessSnackBar('Code PIN créé avec succès !');
        _clearFields();
        setState(() => _currentStep = 'overview');
      }
    } else {
      setState(() => _errorMessage = 'Erreur lors de la création du PIN.');
    }
  }

  Future<void> _modifyPin() async {
    if (_oldPinController.text.isEmpty) {
      setState(() => _errorMessage = 'Veuillez entrer votre ancien PIN.');
      return;
    }

    if (_pinController.text.length != 4 ||
        _confirmPinController.text.length != 4) {
      setState(
        () => _errorMessage = 'Le nouveau PIN doit contenir 4 chiffres.',
      );
      return;
    }

    if (_pinController.text != _confirmPinController.text) {
      setState(() => _errorMessage = 'Les nouveaux PINs ne correspondent pas.');
      return;
    }

    if (!_isNumeric(_pinController.text)) {
      setState(
        () => _errorMessage = 'Le PIN doit contenir uniquement des chiffres.',
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await _pinService.updatePin(
      _oldPinController.text,
      _pinController.text,
    );

    setState(() => _isLoading = false);

    if (success) {
      if (mounted) {
        _showSuccessSnackBar('Code PIN modifié avec succès !');
        _clearFields();
        setState(() => _currentStep = 'overview');
      }
    } else {
      setState(() => _errorMessage = 'Ancien PIN incorrect.');
    }
  }

  Future<void> _deletePin() async {
    if (_oldPinController.text.isEmpty) {
      setState(
        () => _errorMessage = 'Veuillez entrer votre PIN pour confirmer.',
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await _pinService.removePin(_oldPinController.text);

    setState(() => _isLoading = false);

    if (success) {
      await _securityConfig.disableSecurity();
      if (mounted) {
        setState(() {
          _currentSecurityType = SecurityType.none;
          _currentStep = 'overview';
        });
        _showSuccessSnackBar('Code PIN supprimé avec succès !');
        _clearFields();
      }
    } else {
      setState(() => _errorMessage = 'PIN incorrect. Suppression échouée.');
    }
  }

  void _clearFields() {
    _pinController.clear();
    _confirmPinController.clear();
    _oldPinController.clear();
    setState(() => _errorMessage = null);
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.success,
      ),
    );
  }

  bool _isNumeric(String value) {
    return int.tryParse(value) != null;
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
              _getTitle(),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 20),

            // Contenu selon l'étape
            if (_currentStep == 'overview') ...[
              _buildOverviewContent(),
            ] else if (_currentStep == 'setupPin') ...[
              _buildPinSetupForm(),
            ] else if (_currentStep == 'modifyPin') ...[
              _buildPinModifyForm(),
            ] else if (_currentStep == 'deletePin') ...[
              _buildPinDeleteForm(),
            ],

            const SizedBox(height: 24),

            // Message d'erreur
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.error.withOpacity(0.1),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.error,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Boutons d'action
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_currentStep != 'overview') {
                            setState(() {
                              _currentStep = 'overview';
                              _clearFields();
                            });
                          } else {
                            Navigator.pop(context);
                          }
                        },
                  child: Text(
                    _currentStep == 'overview' ? 'Fermer' : 'Retour',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: widget.isDark
                          ? AppColors.accentYellow
                          : AppColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_currentStep != 'overview')
                  ElevatedButton(
                    onPressed: _isLoading ? null : _getActionCallback(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentStep == 'deletePin'
                          ? AppColors.error
                          : (widget.isDark
                                ? AppColors.accentYellow
                                : AppColors.primaryBlue),
                    ),
                    child: Text(
                      _isLoading ? '...' : _getActionButtonText(),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: _currentStep == 'deletePin'
                            ? Colors.white
                            : (widget.isDark
                                  ? AppColors.darkText
                                  : Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    switch (_currentStep) {
      case 'setupPin':
        return 'Créer un code PIN';
      case 'modifyPin':
        return 'Modifier le code PIN';
      case 'deletePin':
        return 'Supprimer le code PIN';
      default:
        return 'Configuration de sécurité';
    }
  }

  String _getActionButtonText() {
    switch (_currentStep) {
      case 'setupPin':
        return 'Créer';
      case 'modifyPin':
        return 'Modifier';
      case 'deletePin':
        return 'Supprimer';
      default:
        return '';
    }
  }

  VoidCallback? _getActionCallback() {
    switch (_currentStep) {
      case 'setupPin':
        return _setupPin;
      case 'modifyPin':
        return _modifyPin;
      case 'deletePin':
        return _deletePin;
      default:
        return null;
    }
  }

  Widget _buildOverviewContent() {
    final securityLabel = _securityConfig.getSecurityTypeLabel(
      _currentSecurityType,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Statut actuel
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: widget.isDark
                ? AppColors.darkBackground.withOpacity(0.5)
                : AppColors.lightBackground,
            border: Border.all(
              color: widget.isDark
                  ? AppColors.accentYellow.withOpacity(0.2)
                  : AppColors.primaryBlue.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sécurité actuelle :',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: widget.isDark
                      ? AppColors.darkText.withOpacity(0.7)
                      : AppColors.lightText.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                securityLabel,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark
                      ? AppColors.accentYellow
                      : AppColors.primaryBlue,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Boutons d'action
        if (_currentSecurityType == SecurityType.pin)
          Column(
            children: [
              _buildActionButton(
                'Modifier le code PIN',
                Icons.edit,
                () => setState(() {
                  _currentStep = 'modifyPin';
                  _clearFields();
                }),
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                'Supprimer le code PIN',
                Icons.delete_outline,
                () => setState(() {
                  _currentStep = 'deletePin';
                  _clearFields();
                }),
                isDestructive: true,
              ),
            ],
          )
        else if (_currentSecurityType == SecurityType.biometric)
          _buildActionButton(
            'Changer la méthode de sécurité',
            Icons.security,
            _showSecurityChoiceDialog,
          )
        else
          _buildActionButton(
            'Configurer la sécurité',
            Icons.lock_open,
            _showSecurityChoiceDialog,
          ),

        const SizedBox(height: 12),

        if (_currentSecurityType != SecurityType.none)
          _buildActionButton(
            'Changer de méthode de sécurité',
            Icons.swap_horiz,
            _showSecurityChoiceDialog,
          ),
      ],
    );
  }

  Widget _buildPinSetupForm() {
    return Column(
      children: [
        _buildPinTextField(
          label: 'Nouveau code PIN',
          controller: _pinController,
        ),
        const SizedBox(height: 16),
        _buildPinTextField(
          label: 'Confirmer le code PIN',
          controller: _confirmPinController,
        ),
      ],
    );
  }

  Widget _buildPinModifyForm() {
    return Column(
      children: [
        _buildPinTextField(
          label: 'Ancien code PIN',
          controller: _oldPinController,
        ),
        const SizedBox(height: 16),
        _buildPinTextField(
          label: 'Nouveau code PIN',
          controller: _pinController,
        ),
        const SizedBox(height: 16),
        _buildPinTextField(
          label: 'Confirmer le nouveau code PIN',
          controller: _confirmPinController,
        ),
      ],
    );
  }

  Widget _buildPinDeleteForm() {
    return Column(
      children: [
        Text(
          'Entrez votre code PIN pour confirmer la suppression :',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: widget.isDark
                ? AppColors.darkText.withOpacity(0.8)
                : AppColors.lightText.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 16),
        _buildPinTextField(label: 'Code PIN', controller: _oldPinController),
      ],
    );
  }

  Widget _buildPinTextField({
    required String label,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 4,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Poppins',
          color: widget.isDark
              ? AppColors.accentYellow.withOpacity(0.7)
              : AppColors.primaryBlue.withOpacity(0.7),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: widget.isDark
                ? AppColors.accentYellow.withOpacity(0.3)
                : AppColors.primaryBlue.withOpacity(0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: widget.isDark
                ? AppColors.accentYellow.withOpacity(0.3)
                : AppColors.primaryBlue.withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: widget.isDark
                ? AppColors.accentYellow
                : AppColors.primaryBlue,
            width: 2,
          ),
        ),
        counterText: '',
      ),
      style: TextStyle(
        fontFamily: 'Poppins',
        color: widget.isDark ? AppColors.darkText : AppColors.lightText,
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isDestructive
              ? AppColors.error.withOpacity(0.1)
              : (widget.isDark
                    ? AppColors.darkBackground.withOpacity(0.5)
                    : AppColors.lightBackground),
          border: Border.all(
            color: isDestructive
                ? AppColors.error.withOpacity(0.3)
                : (widget.isDark
                      ? AppColors.accentYellow.withOpacity(0.2)
                      : AppColors.primaryBlue.withOpacity(0.2)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive
                  ? AppColors.error
                  : (widget.isDark
                        ? AppColors.accentYellow
                        : AppColors.primaryBlue),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDestructive
                    ? AppColors.error
                    : (widget.isDark
                          ? AppColors.darkText
                          : AppColors.lightText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
