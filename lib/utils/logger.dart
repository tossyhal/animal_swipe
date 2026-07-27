import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// アプリ全体で使用するロガー
///
/// リリースビルドでは出力を警告以上に絞る。Web ではブラウザのコンソールに
/// そのまま出るため、デバッグ用のログを残したままにすると利用者に
/// 内部情報が見えてしまう。
class AppLogger {
  AppLogger._();

  /// リリースビルドで出力する最低レベル。
  /// デバッグ・情報ログは開発時のみ意味があるので落とす。
  static final Level _level = kReleaseMode ? Level.warning : Level.debug;

  static final Logger _logger = Logger(
    level: _level,
    // logger の既定は DevelopmentFilter で、リリースビルドでは level に
    // かかわらず一切出力しない。それだと警告・エラーも、Sentry が使えない
    // ときのログだけのフォールバックも消えてしまうので、
    // リリースでは ProductionFilter（level 判定のみ）に差し替える。
    filter: kReleaseMode ? ProductionFilter() : DevelopmentFilter(),
    // PrettyPrinter はスタックトレースの整形にコストがかかるうえ、
    // 色や絵文字はリリースの出力先（ブラウザコンソール等）では邪魔になる。
    printer: kReleaseMode
        ? SimplePrinter(colors: false)
        : PrettyPrinter(
            methodCount: 2,
            errorMethodCount: 8,
            lineLength: 120,
            colors: true,
            printEmojis: true,
            dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
          ),
  );

  /// 現在有効な出力レベル（テスト・デバッグ用）
  static Level get level => _level;

  /// デバッグログ
  static void debug(dynamic message) {
    _logger.d(message);
  }

  /// 情報ログ
  static void info(dynamic message) {
    _logger.i(message);
  }

  /// 警告ログ
  static void warning(dynamic message) {
    _logger.w(message);
  }

  /// エラーログ
  static void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}
