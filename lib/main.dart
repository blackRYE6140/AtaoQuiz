import 'package:atao_quiz/screens/authentication/first_time_setup_screen.dart';
import 'package:atao_quiz/screens/authentication/system_auth_screen.dart';
import 'package:atao_quiz/screens/authentication/system_auth_manage_screen.dart';
import 'package:atao_quiz/screens/generatequiz/generate_quiz_screen.dart';
import 'package:atao_quiz/screens/generatequiz/quiz_list_screen.dart';
import 'package:atao_quiz/screens/home_screen.dart';
import 'package:atao_quiz/services/storage_service.dart';
import 'package:atao_quiz/services/system_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';
import 'theme/colors.dart';

// flutter analyze 2>&1 | grep "error"
// flutter build apk --release --split-per-abi

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Charger .env AVANT toute utilisation
  await _loadEnvironment();

  // 2. Initialiser SharedPreferences
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? saved = prefs.getString('themeMode');

  ThemeMode initialMode = ThemeMode.light;
  if (saved == 'dark') {
    initialMode = ThemeMode.dark;
  }

  // 3. Initialiser les services
  await StorageService().initialize(); // Juste pour être sûr

  // GeminiService s'initialisera lui-même quand nécessaire

  runApp(AtaoQuizApp(initialThemeMode: initialMode));
}

Future<void> _loadEnvironment() async {
  try {
    await dotenv.load(fileName: '.env');
    print(' Fichier .env chargé avec succès');

    // Vérifier que la clé existe
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      print(' GEMINI_API_KEY non définie dans .env');
    } else {
      print(' GEMINI_API_KEY trouvée (${apiKey.length} caractères)');
    }
  } catch (e) {
    print(' Erreur chargement .env: $e');
    // Créer un .env par défaut pour éviter les crashs
    dotenv.env['GEMINI_API_KEY'] = '';
  }
}

class AtaoQuizApp extends StatefulWidget {
  final ThemeMode? initialThemeMode;

  const AtaoQuizApp({super.key, this.initialThemeMode});

  @override
  State<AtaoQuizApp> createState() => _AtaoQuizAppState();
}

class _AtaoQuizAppState extends State<AtaoQuizApp> with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.light;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final _AppRouteObserver _routeObserver = _AppRouteObserver();
  final SystemAuthService _authService = SystemAuthService();
  bool _isNavigatingToLockScreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeMode = widget.initialThemeMode ?? ThemeMode.light;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lockAppOnResumeIfNeeded();
    }
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
    SharedPreferences.getInstance().then((prefs) {
      final String value = mode == ThemeMode.light ? 'light' : 'dark';
      prefs.setString('themeMode', value);
    });
  }

  Future<void> _lockAppOnResumeIfNeeded() async {
    if (_isNavigatingToLockScreen) {
      return;
    }

    final routeAtResume = _routeObserver.currentRouteName;
    if (_isExcludedFromResumeLock(routeAtResume)) {
      return;
    }

    final isSystemAuthEnabled = await _authService.isSystemAuthEnabled();
    if (!isSystemAuthEnabled) {
      return;
    }

    final currentRouteName = _routeObserver.currentRouteName;
    if (_isExcludedFromResumeLock(currentRouteName)) {
      return;
    }

    final shouldLockFromScreenOff = await _authService.consumeScreenOffFlag();
    if (!shouldLockFromScreenOff) {
      return;
    }

    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    _isNavigatingToLockScreen = true;
    navigator.pushNamedAndRemoveUntil('/system-auth', (route) => false);
    _isNavigatingToLockScreen = false;
  }

  bool _isExcludedFromResumeLock(String? routeName) {
    return routeName == '/' ||
        routeName == '/first-time-setup' ||
        routeName == '/system-auth';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AtaoQuiz',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      navigatorObservers: [_routeObserver],
      themeMode: _themeMode,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/first-time-setup': (context) => const FirstTimeSetupScreen(),
        '/system-auth': (context) => const SystemAuthScreen(),
        '/system-auth-manage': (context) => const SystemAuthManageScreen(),
        '/home': (context) => HomeScreen(
          onThemeModeChanged: _setThemeMode,
          currentThemeMode: _themeMode,
        ),
        '/quiz-list': (context) => const QuizListScreen(),
        '/generate-quiz': (context) => const GenerateQuizScreen(),
      },
    );
  }
}

/// Thème clair
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

class _AppRouteObserver extends NavigatorObserver {
  String? currentRouteName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRouteName = route.settings.name;
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRouteName = previousRoute?.settings.name;
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    currentRouteName = newRoute?.settings.name;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

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
