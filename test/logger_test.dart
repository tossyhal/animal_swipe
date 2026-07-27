// test/logger_test.dart
import 'package:animal_swipe/utils/error_reporter.dart';
import 'package:animal_swipe/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

void main() {
  group('AppLogger のレベル制御', () {
    test('リリースビルドでは警告以上のみ出力する', () {
      // テストは常にデバッグビルドで走るため、ここでは
      // 「レベルがビルドモードに追随している」ことを検証する。
      if (kReleaseMode) {
        expect(AppLogger.level, Level.warning);
      } else {
        expect(AppLogger.level, Level.debug);
      }
    });

    test('debug より warning の方が高い順位である', () {
      // Level.value が大きいほど深刻。リリースで warning に絞ると
      // debug / info が落ちることを、列挙の順序として確認する。
      expect(Level.warning.value, greaterThan(Level.debug.value));
      expect(Level.warning.value, greaterThan(Level.info.value));
      expect(Level.error.value, greaterThanOrEqualTo(Level.warning.value));
    });

    test('各ログメソッドが例外を投げない', () {
      expect(() => AppLogger.debug('debug'), returnsNormally);
      expect(() => AppLogger.info('info'), returnsNormally);
      expect(() => AppLogger.warning('warning'), returnsNormally);
      expect(
        () => AppLogger.error('error', Exception('boom'), StackTrace.current),
        returnsNormally,
      );
    });
  });

  group('ErrorReporter', () {
    test('DSN 未設定なら監視は無効', () {
      // テスト実行時は --dart-define=SENTRY_DSN を渡していないため無効。
      // 外部サービスの設定なしでもアプリが動くことを保証する。
      expect(ErrorReporter.isEnabled, isFalse);
    });

    test('監視が無効でも appRunner は実行される', () async {
      var ran = false;
      await ErrorReporter.runGuarded(() {
        ran = true;
      });
      expect(ran, isTrue, reason: 'DSN 未設定でもアプリは起動すること');
    });

    test('appRunner が投げてもハンドラの接続は済んでいる', () async {
      // 起動処理そのものが失敗した場合でも、そのエラーが監視の外へ
      // 素通りしないこと（runGuarded が握り潰さずに伝播させる）
      await expectLater(
        ErrorReporter.runGuarded(() => throw Exception('起動失敗')),
        throwsA(isA<Exception>()),
      );
      expect(FlutterError.onError, isNotNull);
    });

    test('既存の FlutterError.onError を潰さず連鎖させる', () async {
      final previous = FlutterError.onError;
      addTearDown(() => FlutterError.onError = previous);

      var previousCalled = false;
      FlutterError.onError = (_) => previousCalled = true;

      await ErrorReporter.runGuarded(() {});
      FlutterError.onError!(
        FlutterErrorDetails(exception: Exception('test'), library: 'test'),
      );

      expect(previousCalled, isTrue, reason: '先に登録されていたハンドラも呼ばれること');
    });

    test('既存の PlatformDispatcher.onError を潰さず連鎖させる', () async {
      final previous = PlatformDispatcher.instance.onError;
      addTearDown(() => PlatformDispatcher.instance.onError = previous);

      var previousCalled = false;
      PlatformDispatcher.instance.onError = (_, _) {
        previousCalled = true;
        return true;
      };

      await ErrorReporter.runGuarded(() {});
      PlatformDispatcher.instance.onError!(
        Exception('test'),
        StackTrace.current,
      );

      expect(previousCalled, isTrue, reason: '先に登録されていたハンドラも呼ばれること');
    });

    test('監視が無効なら未捕捉エラーを処理済みにしない', () async {
      final previous = PlatformDispatcher.instance.onError;
      addTearDown(() => PlatformDispatcher.instance.onError = previous);
      PlatformDispatcher.instance.onError = null;

      await ErrorReporter.runGuarded(() {});

      // 監視が無効（テスト環境）で true を返すと、未捕捉の非同期エラーが
      // 握り潰されて開発時に不具合を見逃す
      expect(
        PlatformDispatcher.instance.onError!(
          Exception('test'),
          StackTrace.current,
        ),
        isFalse,
        reason: 'デバッグ時は Dart 本来の伝播を妨げないこと',
      );
    });

    test('runGuarded 後に FlutterError.onError が接続されている', () async {
      await ErrorReporter.runGuarded(() {});
      expect(FlutterError.onError, isNotNull);

      // 接続したハンドラが例外を投げないこと（起動直後のエラーで
      // 二重に落ちるのを防ぐ）
      expect(
        () => FlutterError.onError!(
          FlutterErrorDetails(
            exception: Exception('test'),
            stack: StackTrace.current,
            library: 'logger_test',
          ),
        ),
        returnsNormally,
      );
    });
  });
}
