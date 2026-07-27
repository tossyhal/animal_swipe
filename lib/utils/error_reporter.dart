import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'logger.dart';

/// クラッシュ・未処理例外の監視をまとめる窓口
///
/// ## DSN の扱い
///
/// DSN はビルド時に `--dart-define=SENTRY_DSN=...` で渡す。
/// **Flutter Web のビルド成果物からは `--dart-define` の値が読めるため、
/// これは秘匿手段ではない。** Sentry の DSN は元々クライアントに埋め込む前提の
/// 公開値（イベントの投稿にしか使えず、データの読み出しはできない）なので
/// この扱いで問題ないが、同じ手段で API キーを渡してはいけない。
///
/// DSN が未設定なら Sentry は初期化せず、ログ出力だけを行う。
/// 開発中やフォークでの動作に外部サービスの設定を必須にしないため。
class ErrorReporter {
  ErrorReporter._();

  /// ビルド時に注入される Sentry の DSN。未設定なら空文字。
  static const String _dsn = String.fromEnvironment('SENTRY_DSN');

  /// 監視が有効か（DSN が設定されていて、かつリリースビルド）
  ///
  /// デバッグビルドのエラーまで送るとノイズになるうえ、無料枠を食い潰す。
  static bool get isEnabled => _dsn.isNotEmpty && kReleaseMode;

  /// アプリ本体を監視下で起動する
  ///
  /// [appRunner] の中で `runApp` を呼ぶこと。Zone をまたぐ非同期エラーも
  /// 捕捉するため、Sentry の初期化と同じ Zone で起動する必要がある。
  static Future<void> runGuarded(FutureOr<void> Function() appRunner) async {
    _installHandlers();

    if (!isEnabled) {
      AppLogger.info('エラー監視は無効です（SENTRY_DSN 未設定、またはリリースビルドではない）');
      await appRunner();
      return;
    }

    // Sentry が appRunner を呼んだか、こちらの保険で呼んだかに関わらず
    // アプリの起動が一度だけになるようにする
    var appStarted = false;
    // appRunner 自身が投げたエラー。Sentry の初期化失敗とは区別する必要がある。
    Object? appError;
    StackTrace? appStackTrace;

    Future<void> startAppOnce() async {
      if (appStarted) return;
      appStarted = true;
      try {
        await appRunner();
      } catch (error, stackTrace) {
        // 起動処理の失敗こそ最も知りたいクラッシュなので、握る前に
        // 必ず Sentry へ送る。ここで握らないと SentryFlutter.init 越しに
        // 伝播し、下の catch が「初期化の失敗」と誤認してしまうため、
        // 「送ってから握って、あとで投げ直す」形にしている。
        await Sentry.captureException(error, stackTrace: stackTrace);
        appError = error;
        appStackTrace = stackTrace;
      }
    }

    try {
      await SentryFlutter.init((options) {
        options.dsn = _dsn;
        // 送信前にログへも残す。監視サービスが落ちていても手がかりが残るように。
        options.beforeSend = (event, hint) {
          AppLogger.error(
            'Sentry へ送信: ${event.exceptions?.firstOrNull?.value}',
          );
          return event;
        };
        // パフォーマンス計測は当面不要。無料枠を消費しないよう切っておく。
        options.tracesSampleRate = 0;
        // 個人情報は送らない
        options.sendDefaultPii = false;
      }, appRunner: startAppOnce);
    } catch (error, stackTrace) {
      // 監視はあくまで補助機能。DSN の書式不正やネイティブ統合の失敗で
      // SentryFlutter.init が投げると appRunner が呼ばれず、
      // 「監視が壊れているせいでアプリが起動しない」という最悪の状態になる。
      // 失敗しても必ずアプリは立ち上げる（fail open）。
      AppLogger.error('Sentry の初期化に失敗しました。監視なしで起動します', error, stackTrace);
    }

    // init が appRunner を呼ばずに終わった場合の保険
    await startAppOnce();

    // 起動処理自体の失敗は握り潰さない。監視の有無で挙動が変わらないよう、
    // 監視が無効なときと同じく呼び出し元へ伝播させる。
    final error = appError;
    if (error != null) {
      Error.throwWithStackTrace(error, appStackTrace ?? StackTrace.current);
    }
  }

  /// Flutter フレームワークと Dart ランタイムのエラーハンドラを接続する
  static void _installHandlers() {
    final previousOnError = FlutterError.onError;

    // build / layout / paint 中の例外
    FlutterError.onError = (details) {
      AppLogger.error(
        'FlutterError: ${details.exceptionAsString()}',
        details.exception,
        details.stack,
      );
      previousOnError?.call(details);
    };

    // Flutter が捕捉しない非同期エラー（Zone 外に漏れたもの）。
    // テストハーネスや embedder が既に登録している場合があるので、
    // FlutterError.onError と同様に既存のハンドラを潰さず連鎖させる。
    final previousPlatformOnError = PlatformDispatcher.instance.onError;

    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.error('PlatformDispatcher の未処理エラー', error, stack);
      // 既存のハンドラが「処理済み」と言うならそれを尊重する
      if (previousPlatformOnError?.call(error, stack) ?? false) return true;

      // 監視が有効なとき（＝本番）だけ「処理済み」として握り、
      // 利用者の画面が落ちるのを防ぐ。Sentry には既に記録されている。
      //
      // 監視が無効なデバッグ／フォークビルドでまで true を返すと、
      // 未捕捉の非同期エラーが握り潰されて Dart 本来の伝播・クラッシュが
      // 起きなくなり、開発時に不具合を見逃す。
      return isEnabled;
    };
  }
}
