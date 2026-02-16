import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/colors.dart';
import '../services/system_auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _shadowController;
  late Animation<double> _shadowAnimation;
  Timer? _navigationTimer;
  final SystemAuthService _authService = SystemAuthService();

  @override
  void initState() {
    super.initState();

    _shadowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // Animation: centre → droite → centre → gauche → centre
    _shadowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 60.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 60.0, end: 0.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -60.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -60.0, end: 0.0), weight: 1),
    ]).animate(_shadowController);

    _shadowController.repeat();

    _navigationTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _navigateToHome();
      }
    });
  }

  Future<void> _navigateToHome() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isFirstTime = prefs.getBool('is_first_time_setup') ?? true;

      if (mounted) {
        late String route;

        if (isFirstTime) {
          // Première fois: afficher l'écran de configuration
          route = '/first-time-setup';
          // Marquer comme non-première fois après
          await prefs.setBool('is_first_time_setup', false);
        } else {
          // Vérifier si l'auth système est activée
          final isSystemAuthEnabled = await _authService.isSystemAuthEnabled();

          if (isSystemAuthEnabled) {
            route = '/system-auth';
          } else {
            route = '/home';
          }
        }

        Navigator.of(context).pushReplacementNamed(route);
      }
    } catch (e) {
      print('Erreur navigation splash: $e');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _shadowController.stop();
    _shadowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo + animated shadow
              SizedBox(
                width: 460,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _shadowAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shadowAnimation.value, 0),
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentYellow.withOpacity(
                                    0.6,
                                  ),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    Image.asset(
                      isDark ? 'assets/logo_dark.png' : 'assets/logo_light.png',
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),

              // Slogan juste sous le logo
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Text(
                  "Ataovy lalao ny fianarana,\ miaraka amin'ny AtaoQuiz!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.accentYellow
                        : AppColors.primaryBlue,
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
