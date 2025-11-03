import 'package:logger/logger.dart';

/// アプリ全体で使用するロガー
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

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
