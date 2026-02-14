import 'package:logger/logger.dart';

class AppLogger {
  final String scope;
  final Logger _logger;

  AppLogger(this.scope) : _logger = Logger();

  void debug(String message) => _logger.d('[$scope] $message');
  void info(String message) => _logger.i('[$scope] $message');
  void warn(String message) => _logger.w('[$scope] $message');
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _logger.e('[$scope] $message', error: error, stackTrace: stackTrace);
}
