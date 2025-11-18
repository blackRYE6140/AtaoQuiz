import 'package:atao_quiz/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'theme/colors.dart';

Future<void> main() async {
  runApp(const AtaoQuizApp());
}

class AtaoQuizApp extends StatefulWidget {
  const AtaoQuizApp({super.key});

  @override
  State<AtaoQuizApp> createState() => _AtaoQuizAppState();
}

class _AtaoQuizAppState extends State<AtaoQuizApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AtaoQuiz',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => HomeScreen(
          onThemeModeChanged: _setThemeMode,
          currentThemeMode: _themeMode,
        ),
      },
    );
  }
}

///  Thème clair
final ThemeData _lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: AppColors.primaryBlue,
  scaffoldBackgroundColor: AppColors.lightBackground,
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontFamily: 'Poppins', color: AppColors.lightText),
  ),
  fontFamily: 'Poppins',
  colorScheme: const ColorScheme.light(
    primary: AppColors.primaryBlue,
    secondary: AppColors.accentYellow,
  ),
);

/// Thème sombre
final ThemeData _darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: AppColors.accentYellow,
  scaffoldBackgroundColor: AppColors.darkBackground,
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontFamily: 'Poppins', color: AppColors.darkText),
  ),
  fontFamily: 'Poppins',
  colorScheme: const ColorScheme.dark(
    primary: AppColors.accentYellow,
    secondary: AppColors.primaryBlue,
  ),
);
