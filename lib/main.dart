import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/app_strings.dart';
import 'screens/start_screen.dart';
import 'screens/swipe_screen.dart';
import 'services/prefs_service.dart';
import 'utils/error_reporter.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // Flutterのウィジェットシステムを初期化。
  // Sentry の初期化にもバインディングが要るため、監視の開始より前に行う。
  WidgetsFlutterBinding.ensureInitialized();

  // 起動時の初期化ごと監視下に置く。
  // 画面向きの固定や SharedPreferences の取得が失敗した場合も、
  // 監視の外で main が終了してしまわないようにする。
  // runApp も必ずこの中で呼ぶこと（Zone をまたぐと捕捉できなくなる）。
  await ErrorReporter.runGuarded(() async {
    final futures = await Future.wait([
      // 画面の向きを縦画面に固定する
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
      SharedPreferences.getInstance(),
    ]);

    // SharedPreferences の初期化
    final prefs = futures[1] as SharedPreferences;
    final prefsService = PrefsService(prefs);

    runApp(
      ProviderScope(
        // prefsServiceProvider を上書きして、[PrefsService] を注入
        overrides: [prefsServiceProvider.overrideWithValue(prefsService)],
        child: const AnimalSwipeApp(),
      ),
    );
  });
}

class AnimalSwipeApp extends ConsumerWidget {
  const AnimalSwipeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 前回の選択が残っていれば、選び直しを挟まずスワイプ画面から始める。
    // 起動のたびに同じ選択をやり直させる必要はない。
    // 選択を変えたい場合はスワイプ画面の「選び直す」から戻れる。
    final hasSelection = ref
        .watch(prefsServiceProvider)
        .hasSelectedAnimalTypes();

    return MaterialApp(
      title: AppStrings.appTitle,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system,
      home: hasSelection ? const SwipeScreen() : const StartScreen(),
    );
  }
}
