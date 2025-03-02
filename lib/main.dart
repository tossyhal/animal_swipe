import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/start_screen.dart';
import 'services/prefs_service.dart';

Future<void> main() async {
  // Flutterのウィジェットシステムを初期化
  WidgetsFlutterBinding.ensureInitialized();

  // 画面の向きを縦画面に固定する
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // .env ファイルの読み込み
  await dotenv.load(fileName: ".env");

  // SharedPreferences の初期化
  final prefs = await SharedPreferences.getInstance();
  final prefsService = PrefsService(prefs);

  runApp(
    ProviderScope(
      // prefsServiceProvider を上書きして、[PrefsService] を注入
      overrides: [prefsServiceProvider.overrideWithValue(prefsService)],
      child: const AnimalSwipeApp(),
    ),
  );
}

class AnimalSwipeApp extends ConsumerWidget {
  const AnimalSwipeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'AnimalSwipe',
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF78A083),
          primaryContainer: const Color(0xFFD8E9DD),
          onPrimaryContainer: const Color(0xFF2C4B34),
          secondary: const Color(0xFFE8A87C),
          tertiary: const Color(0xFFF5C09A),
          surface: Colors.white,
          error: const Color(0xFFE76F51),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontFamily: 'MPLUSRounded1c',
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
          bodyLarge: TextStyle(fontFamily: 'MPLUSRounded1c', fontSize: 16),
          bodyMedium: TextStyle(fontFamily: 'MPLUSRounded1c', fontSize: 14),
        ),
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF78A083),
            foregroundColor: Colors.white,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Color(0xFF78A083),
          foregroundColor: Colors.white,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'MPLUSRounded1c',
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF78A083),
          primaryContainer: const Color(0xFF2C4B34),
          onPrimaryContainer: const Color(0xFFD8E9DD),
          secondary: const Color(0xFFE8A87C),
          tertiary: const Color(0xFFF5C09A),
          surface: const Color(0xFF1E1E1E),
          error: const Color(0xFFE76F51),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontFamily: 'MPLUSRounded1c',
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'MPLUSRounded1c',
            fontSize: 16,
            color: Colors.white,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'MPLUSRounded1c',
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        cardTheme: CardTheme(
          elevation: 4,
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF78A083),
            foregroundColor: Colors.white,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Color(0xFF2C4B34),
          foregroundColor: Colors.white,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'MPLUSRounded1c',
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      // 常に StartScreen を表示
      home: const StartScreen(),
    );
  }
}
