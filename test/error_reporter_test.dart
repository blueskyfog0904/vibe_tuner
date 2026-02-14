import 'package:flutter_test/flutter_test.dart';
import 'package:vibetuner/core/logging/error_reporter.dart';

void main() {
  setUp(() {
    AppErrorReporter.setLoggingEnabledForTesting(false);
  });

  tearDown(() {
    AppErrorReporter.setSinkForTesting(null);
    AppErrorReporter.clearRecentErrors();
    AppErrorReporter.setGlobalContext(const <String, Object?>{});
    AppErrorReporter.setLoggingEnabledForTesting(true);
  });

  test('reportFatal forwards event to sink with fatal severity', () {
    ReportedError? captured;
    AppErrorReporter.setSinkForTesting((reported) {
      captured = reported;
    });

    final stack = StackTrace.current;
    AppErrorReporter.reportFatal(
      StateError('fatal-test'),
      stack,
      source: 'unit_test',
    );

    expect(captured, isNotNull);
    expect(captured!.severity, ErrorSeverity.fatal);
    expect(captured!.source, 'unit_test');
  });

  test('reportNonFatal forwards event to sink with non-fatal severity', () {
    ReportedError? captured;
    AppErrorReporter.setSinkForTesting((reported) {
      captured = reported;
    });

    final stack = StackTrace.current;
    AppErrorReporter.reportNonFatal(
      ArgumentError('non-fatal-test'),
      stack,
      source: 'unit_test',
    );

    expect(captured, isNotNull);
    expect(captured!.severity, ErrorSeverity.nonFatal);
    expect(captured!.source, 'unit_test');
  });

  test('reportNonFatal stores context and export includes it', () {
    AppErrorReporter.reportNonFatal(
      StateError('with-context'),
      StackTrace.current,
      source: 'unit_test',
      context: const <String, Object?>{
        'phase': 'start_capture',
        'sampleRate': 44100,
      },
    );

    final recent = AppErrorReporter.getRecentErrors();
    expect(recent.single.context['phase'], 'start_capture');
    expect(recent.single.context['sampleRate'], 44100);

    final text = AppErrorReporter.exportRecentErrorsText();
    expect(text, contains('context:'));
    expect(text, contains('phase=start_capture'));
    expect(text, contains('sampleRate=44100'));
  });

  test('global context is merged into reported error context', () {
    AppErrorReporter.setGlobalContext(const <String, Object?>{
      'appVersion': '1.2.3',
      'activeTab': 'tuner',
    });

    AppErrorReporter.reportNonFatal(
      StateError('global-context'),
      StackTrace.current,
      source: 'unit_test',
      context: const <String, Object?>{'phase': 'startup'},
    );

    final recent = AppErrorReporter.getRecentErrors();
    expect(recent.single.context['appVersion'], '1.2.3');
    expect(recent.single.context['activeTab'], 'tuner');
    expect(recent.single.context['phase'], 'startup');
  });

  test('keeps only recent 50 errors and returns newest first', () {
    for (var i = 0; i < 55; i++) {
      AppErrorReporter.reportNonFatal(
        StateError('non-fatal-$i'),
        StackTrace.current,
        source: 'unit_test',
      );
    }

    final recent = AppErrorReporter.getRecentErrors();
    expect(recent.length, 50);
    expect(recent.first.error.toString(), contains('non-fatal-54'));
    expect(recent.last.error.toString(), contains('non-fatal-5'));
  });

  test('export text is empty after clear', () {
    AppErrorReporter.reportFatal(
      StateError('fatal-before-clear'),
      StackTrace.current,
      source: 'unit_test',
    );

    expect(AppErrorReporter.exportRecentErrorsText(), isNotEmpty);
    AppErrorReporter.clearRecentErrors();
    expect(AppErrorReporter.exportRecentErrorsText(), isEmpty);
  });
}
