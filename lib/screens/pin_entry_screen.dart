import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/pin_service.dart';

class PinEntryScreen extends StatefulWidget {
  const PinEntryScreen({super.key});

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  final PinService _pinService = PinService();
  String _enteredPin = '';
  bool _isLoading = false;
  String? _errorMessage;
  int _attemptCount = 0;
  static const int _maxAttempts = 5;

  Future<void> _verifyPin() async {
    if (_enteredPin.length != 4) return;

    setState(() => _isLoading = true);

    final isValid = await _pinService.verifyPin(_enteredPin);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (isValid) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      _attemptCount++;
      if (_attemptCount >= _maxAttempts) {
        setState(
          () => _errorMessage = 'Trop de tentatives. Réessayez plus tard.',
        );
      } else {
        setState(
          () => _errorMessage =
              'PIN incorrect (${_maxAttempts - _attemptCount} tentatives restantes)',
        );
      }
      // Réinitialiser le PIN après erreur
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _enteredPin = '');
        }
      });
    }
  }

  void _onPinDigitPressed(String digit) {
    if (_enteredPin.length < 4 && _attemptCount < _maxAttempts) {
      setState(() {
        _enteredPin += digit;
        _errorMessage = null;
      });

      if (_enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
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
              // Titre
              Text(
                'Saisissez votre code PIN',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 30),

              // Affichage du PIN (points)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? AppColors.accentYellow
                              : AppColors.primaryBlue,
                          width: 2,
                        ),
                        color: index < _enteredPin.length
                            ? (isDark
                                  ? AppColors.accentYellow
                                  : AppColors.primaryBlue)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Message d'erreur
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Clavier numérique
              if (_attemptCount < _maxAttempts)
                SizedBox(
                  width: 300,
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.5,
                        ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      if (index < 9) {
                        final digit = (index + 1).toString();
                        return _buildPinButton(
                          digit,
                          isDark,
                          () => _onPinDigitPressed(digit),
                        );
                      } else if (index == 9) {
                        return _buildPinButton(
                          '0',
                          isDark,
                          () => _onPinDigitPressed('0'),
                        );
                      } else {
                        return _buildBackspaceButton(isDark);
                      }
                    },
                  ),
                ),

              if (_attemptCount >= _maxAttempts)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'Trop de tentatives. Redémarrez l\'application.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinButton(String digit, bool isDark, VoidCallback onPressed) {
    return GestureDetector(
      onTap: _isLoading ? null : onPressed,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            digit,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton(bool isDark) {
    return GestureDetector(
      onTap: _isLoading ? null : _onBackspace,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            color: isDark ? AppColors.accentYellow : AppColors.primaryBlue,
            size: 24,
          ),
        ),
      ),
    );
  }
}
