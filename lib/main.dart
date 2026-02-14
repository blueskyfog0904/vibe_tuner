import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/main_screen.dart';
import 'config/theme/app_theme.dart';
import 'core/logging/error_reporter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _initializeErrorReportingContext();
  _installGlobalErrorHandlers();
  runZonedGuarded(
    () {
      runApp(
        const ProviderScope(
          child: VibeTunerApp(),
        ),
      );
    },
    (error, stackTrace) {
      AppErrorReporter.reportFatal(
        error,
        stackTrace,
        source: 'zone',
      );
    },
  );
}

void _initializeErrorReportingContext() {
  const buildName = String.fromEnvironment(
    'FLUTTER_BUILD_NAME',
    defaultValue: 'unknown',
  );
  const buildNumber = String.fromEnvironment(
    'FLUTTER_BUILD_NUMBER',
    defaultValue: 'unknown',
  );
  AppErrorReporter.setGlobalContext(<String, Object?>{
    'appVersion': buildName,
    'buildNumber': buildNumber,
    'platform': defaultTargetPlatform.name,
  });
}

void _installGlobalErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppErrorReporter.reportFatal(
      details.exception,
      details.stack ?? StackTrace.current,
      source: 'flutter_framework',
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    AppErrorReporter.reportFatal(
      error,
      stackTrace,
      source: 'platform_dispatcher',
    );
    return true;
  };
}

class VibeTunerApp extends StatelessWidget {
  const VibeTunerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VibeTuner',
      theme: VibeTheme.darkTheme,
      home: const MainScreen(),
    );
  }
}
