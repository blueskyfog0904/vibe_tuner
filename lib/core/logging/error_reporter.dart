import 'dart:async';

import 'app_logger.dart';

enum ErrorSeverity { fatal, nonFatal }

class ReportedError {
  final Object error;
  final StackTrace stackTrace;
  final String source;
  final ErrorSeverity severity;
  final DateTime timestamp;
  final Map<String, Object?> context;

  const ReportedError({
    required this.error,
    required this.stackTrace,
    required this.source,
    required this.severity,
    required this.timestamp,
    this.context = const <String, Object?>{},
  });
}

typedef ErrorSink = void Function(ReportedError reported);

class AppErrorReporter {
  static final AppLogger _logger = AppLogger('ErrorReporter');
  static ErrorSink? _sink;
  static bool _loggingEnabled = true;
  static const int _maxRecentErrors = 50;
  static final List<ReportedError> _recentErrors = <ReportedError>[];
  static final Map<String, Object?> _globalContext = <String, Object?>{};
  static final StreamController<List<ReportedError>> _recentErrorsController =
      StreamController<List<ReportedError>>.broadcast();

  static void setSinkForTesting(ErrorSink? sink) {
    _sink = sink;
  }

  static void setLoggingEnabledForTesting(bool enabled) {
    _loggingEnabled = enabled;
  }

  static void setGlobalContext(Map<String, Object?> context) {
    _globalContext
      ..clear()
      ..addAll(context);
  }

  static void putGlobalContext(String key, Object? value) {
    _globalContext[key] = value;
  }

  static void removeGlobalContext(String key) {
    _globalContext.remove(key);
  }

  static Map<String, Object?> getGlobalContext() {
    return Map<String, Object?>.unmodifiable(_globalContext);
  }

  static List<ReportedError> getRecentErrors() {
    return List<ReportedError>.unmodifiable(_recentErrors.reversed);
  }

  static Stream<List<ReportedError>> recentErrorsStream() {
    return _recentErrorsController.stream;
  }

  static void clearRecentErrors() {
    _recentErrors.clear();
    _recentErrorsController.add(getRecentErrors());
  }

  static void reportFatal(
    Object error,
    StackTrace stackTrace, {
    String source = 'unknown',
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    final reported = ReportedError(
      error: error,
      stackTrace: stackTrace,
      source: source,
      severity: ErrorSeverity.fatal,
      timestamp: DateTime.now(),
      context: _mergeContext(context),
    );
    _record(reported);
    _sink?.call(reported);
    if (_loggingEnabled) {
      _logger.error(
        'Fatal error from $source',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static void reportNonFatal(
    Object error,
    StackTrace stackTrace, {
    String source = 'unknown',
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    final reported = ReportedError(
      error: error,
      stackTrace: stackTrace,
      source: source,
      severity: ErrorSeverity.nonFatal,
      timestamp: DateTime.now(),
      context: _mergeContext(context),
    );
    _record(reported);
    _sink?.call(reported);
    if (_loggingEnabled) {
      _logger.warn('Non-fatal error from $source: $error');
    }
  }

  static String exportRecentErrorsText() {
    final buffer = StringBuffer();
    for (final reported in getRecentErrors()) {
      final severity = reported.severity == ErrorSeverity.fatal
          ? 'fatal'
          : 'non_fatal';
      buffer.writeln(
        '[${reported.timestamp.toIso8601String()}] '
        '$severity @ ${reported.source}: ${reported.error}',
      );
      if (reported.context.isNotEmpty) {
        final contextText = reported.context.entries
            .map((entry) => '${entry.key}=${entry.value}')
            .join(', ');
        buffer.writeln('  context: $contextText');
      }
      final stackLines = reported.stackTrace
          .toString()
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .take(8);
      for (final line in stackLines) {
        buffer.writeln('  $line');
      }
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }

  static void _record(ReportedError reported) {
    _recentErrors.add(reported);
    if (_recentErrors.length > _maxRecentErrors) {
      _recentErrors.removeAt(0);
    }
    _recentErrorsController.add(getRecentErrors());
  }

  static Map<String, Object?> _mergeContext(Map<String, Object?> localContext) {
    if (_globalContext.isEmpty) return localContext;
    if (localContext.isEmpty) return Map<String, Object?>.from(_globalContext);
    return <String, Object?>{
      ..._globalContext,
      ...localContext,
    };
  }
}
