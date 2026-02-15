import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/pin_service.dart';

class PinSetupDialog extends StatefulWidget {
  final bool isDark;

  const PinSetupDialog({super.key, required this.isDark});

  @override
  State<PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<PinSetupDialog> {
  final PinService _pinService = PinService();
  late TextEditingController _pinController;
  late TextEditingController _confirmPinController;
  late TextEditingController _oldPinController;

  String _currentStep = 'initial'; // initial, setup, verify, modify, delete
  String? _errorMessage;
  bool _isLoading = false;
  bool _hasPinSet = false;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
    _confirmPinController = TextEditingController();
    _oldPinController = TextEditingController();
    _checkPinStatus();
  }

  Future<void> _checkPinStatus() async {
    final hasPin = await _pinService.hasPinSet();
    setState(() => _hasPinSet = hasPin);
    if (!hasPin) {
      setState(() => _currentStep = 'setup');
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _oldPinController.dispose();
    super.dispose();
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
      if (mounted) {
        Navigator.pop(context, true);
        _showSuccessSnackBar('Code PIN créé avec succès !');
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
        Navigator.pop(context, true);
        _showSuccessSnackBar('Code PIN modifié avec succès !');
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
      if (mounted) {
        Navigator.pop(context, true);
        _showSuccessSnackBar('Code PIN supprimé avec succès !');
      }
    } else {
      setState(() => _errorMessage = 'PIN incorrect. Suppression échouée.');
    }
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

            // Boutons de sélection du mode (si PIN existe)
            if (_hasPinSet && _currentStep == 'initial') ...[
              _buildModeButton('Modifier le code PIN', Icons.edit, () {
                setState(() {
                  _currentStep = 'modify';
                  _errorMessage = null;
                  _oldPinController.clear();
                  _pinController.clear();
                  _confirmPinController.clear();
                });
              }),
              const SizedBox(height: 12),
              _buildModeButton(
                'Supprimer le code PIN',
                Icons.delete_outline,
                () {
                  setState(() {
                    _currentStep = 'delete';
                    _errorMessage = null;
                    _oldPinController.clear();
                  });
                },
                isDestructive: true,
              ),
              const SizedBox(height: 20),
            ],

            // Forme de création
            if (_currentStep == 'setup') ...[
              _buildPinTextField(
                label: 'Nouveau code PIN',
                controller: _pinController,
                isDark: widget.isDark,
              ),
              const SizedBox(height: 16),
              _buildPinTextField(
                label: 'Confirmer le code PIN',
                controller: _confirmPinController,
                isDark: widget.isDark,
              ),
            ],

            // Forme de modification
            if (_currentStep == 'modify') ...[
              _buildPinTextField(
                label: 'Ancien code PIN',
                controller: _oldPinController,
                isDark: widget.isDark,
              ),
              const SizedBox(height: 16),
              _buildPinTextField(
                label: 'Nouveau code PIN',
                controller: _pinController,
                isDark: widget.isDark,
              ),
              const SizedBox(height: 16),
              _buildPinTextField(
                label: 'Confirmer le nouveau code PIN',
                controller: _confirmPinController,
                isDark: widget.isDark,
              ),
            ],

            // Forme de suppression
            if (_currentStep == 'delete') ...[
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
              _buildPinTextField(
                label: 'Code PIN',
                controller: _oldPinController,
                isDark: widget.isDark,
              ),
            ],

            // Message d'erreur
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
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
            ],

            const SizedBox(height: 24),

            // Boutons d'action
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_currentStep != 'initial') {
                            setState(() => _currentStep = 'initial');
                          } else {
                            Navigator.pop(context);
                          }
                        },
                  child: Text(
                    _currentStep == 'initial' ? 'Fermer' : 'Retour',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: widget.isDark
                          ? AppColors.accentYellow
                          : AppColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_currentStep == 'setup') {
                            _setupPin();
                          } else if (_currentStep == 'modify') {
                            _modifyPin();
                          } else if (_currentStep == 'delete') {
                            _deletePin();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentStep == 'delete'
                        ? AppColors.error
                        : (widget.isDark
                              ? AppColors.accentYellow
                              : AppColors.primaryBlue),
                  ),
                  child: Text(
                    _isLoading ? '...' : _getActionButtonText(),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: _currentStep == 'delete'
                          ? Colors.white
                          : (widget.isDark ? AppColors.darkText : Colors.white),
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
      case 'setup':
        return 'Créer un code PIN';
      case 'modify':
        return 'Modifier le code PIN';
      case 'delete':
        return 'Supprimer le code PIN';
      default:
        return 'Code PIN';
    }
  }

  String _getActionButtonText() {
    switch (_currentStep) {
      case 'setup':
        return 'Créer';
      case 'modify':
        return 'Modifier';
      case 'delete':
        return 'Supprimer';
      default:
        return '';
    }
  }

  Widget _buildPinTextField({
    required String label,
    required TextEditingController controller,
    required bool isDark,
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
          color: isDark
              ? AppColors.accentYellow.withOpacity(0.7)
              : AppColors.primaryBlue.withOpacity(0.7),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark
                ? AppColors.accentYellow.withOpacity(0.3)
                : AppColors.primaryBlue.withOpacity(0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark
                ? AppColors.accentYellow.withOpacity(0.3)
                : AppColors.primaryBlue.withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? AppColors.accentYellow : AppColors.primaryBlue,
            width: 2,
          ),
        ),
        counterText: '',
      ),
      style: TextStyle(
        fontFamily: 'Poppins',
        color: isDark ? AppColors.darkText : AppColors.lightText,
      ),
    );
  }

  Widget _buildModeButton(
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
