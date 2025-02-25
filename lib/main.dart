import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/start_screen.dart';
import 'screens/swipe_screen.dart';
import 'services/prefs_service.dart';

Future<void> main() async {
  // Flutterのウィジェットシステムを初期化
  WidgetsFlutterBinding.ensureInitialized();

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
    // ローカルストレージから選択済み動物タイプの有無を確認
    final prefsService = ref.watch(prefsServiceProvider);
    final hasSelectedAnimalTypes = prefsService.hasSelectedAnimalTypes();

    return MaterialApp(
      title: 'AnimalSwipe',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system, // システム設定に合わせてテーマを切り替え
      // 選択済みの動物タイプがある場合は SwipeScreen、ない場合は StartScreen を表示
      home: hasSelectedAnimalTypes ? const SwipeScreen() : const StartScreen(),
    );
  }
}
