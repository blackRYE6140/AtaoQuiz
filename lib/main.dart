import 'package:atao_quiz/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';
import 'theme/colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  // saved value: 'light' | 'dark'
  final String? saved = prefs.getString('themeMode');

  // default to light if no preference
  ThemeMode initialMode = ThemeMode.light;
  if (saved == 'dark') {
    initialMode = ThemeMode.dark;
  }

  runApp(AtaoQuizApp(initialThemeMode: initialMode));
}

class AtaoQuizApp extends StatefulWidget {
  final ThemeMode? initialThemeMode;

  const AtaoQuizApp({super.key, this.initialThemeMode});

  @override
  State<AtaoQuizApp> createState() => _AtaoQuizAppState();
}

class _AtaoQuizAppState extends State<AtaoQuizApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    // Apply initial theme from widget only once during init
    _themeMode = widget.initialThemeMode ?? ThemeMode.light;
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
    // persist the selection (only 'light' or 'dark')
    SharedPreferences.getInstance().then((prefs) {
      final String value = mode == ThemeMode.light ? 'light' : 'dark';
      prefs.setString('themeMode', value);
    });
  }

  @override
  Widget build(BuildContext context) {
    // initial theme already applied in initState
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
