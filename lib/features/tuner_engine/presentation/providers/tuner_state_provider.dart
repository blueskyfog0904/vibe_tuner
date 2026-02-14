import 'dart:async';
import 'dart:collection';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../../core/constants/audio_constants.dart';
import '../../../../core/logging/error_reporter.dart';
import '../../../../core/math/note_calculator.dart';
import '../../../audio_processing/presentation/providers/audio_state_provider.dart';
import '../../data/repositories/pitch_repository_impl.dart';
import '../../domain/entities/tuning_result.dart';
import '../../domain/entities/tuner_processing_config.dart';
import '../../domain/entities/tuner_settings.dart';
import '../../domain/repositories/pitch_repository.dart';
import '../../services/haptic_manager.dart';
import 'tuner_settings_provider.dart';

/// Tuner Repository Provider
/// Using autoDispose to ensure disposal when not used
final pitchRepositoryProvider = Provider.autoDispose<PitchRepository>((ref) {
  final repo = PitchRepositoryImpl();
  ref.onDispose(() => repo.dispose());
  return repo;
});

/// Haptic Manager Provider
final hapticManagerProvider = Provider<HapticManager>((ref) => HapticManager());

/// Main Tuner State Provider
final tunerStateProvider =
    StateNotifierProvider.autoDispose<TunerStateNotifier, TuningResult>((ref) {
      // We watch the pitch repo so that if it changes (recreated), we recreate the notifier.
      // Also keeps the repo alive as long as the notifier is alive.
      final pitchRepo = ref.watch(pitchRepositoryProvider);
      final config = ref.watch(tunerProcessingConfigProvider);
      final settings =
          ref.watch(tunerSettingsProvider).valueOrNull ??
          const TunerSettings.defaults();
      return TunerStateNotifier(ref, pitchRepo, config, settings);
    });

class TunerStateNotifier extends StateNotifier<TuningResult> {
  static const int _noSignalHoldMs = AudioConstants.noSignalHoldMs;
  static const int _noSignalDropFrames = AudioConstants.noSignalDropFrames;

  final Ref _ref;
  final PitchRepository _pitchRepo;
  final TunerProcessingConfig _config;
  final TunerSettings _settings;
  late final Set<String>? _allowedNotes;
  final Logger _logger = Logger();
  final Queue<double> _frequencyBuffer = Queue<double>();
  late final NoteCalculator _noteCalculator;
  StreamSubscription? _audioSubscription;
  StreamSubscription? _pitchSubscription;
  DateTime? _lastDetectedAt;
  TuningResult? _lastDetectedResult;
  int _pendingNoSignalFrames = 0;
  double? _lastInputSampleRate;

  TunerStateNotifier(this._ref, this._pitchRepo, this._config, this._settings)
    : super(TuningResult.noSignal()) {
    _noteCalculator = NoteCalculator(
      a4Reference: _settings.a4Reference,
      perfectCentsThreshold: perfectCentsThresholdFromSensitivity(
        _settings.sensitivity,
      ),
    );
    _allowedNotes = allowedNoteNamesFromPreset(_settings.tuningPreset);
    // _initialize(); // Don't auto-start. Let the UI control it.
    // Or auto-start if that's the default behavior expected.
    // For integration, let's allow manual start/stop.
    // But to keep backward compatibility with existing tests, maybe auto-start?
    // Let's stick to explicit start() call in the UI or auto-start here but provide stop().
    start();
  }

  Future<void> start() async {
    if (_audioSubscription != null) return; // Already started

    _logger.i("TunerStateNotifier: Starting...");
    _pendingNoSignalFrames = 0;
    _lastDetectedAt = null;
    _lastDetectedResult = null;
    _lastInputSampleRate = null;
    _frequencyBuffer.clear();
    final audioSource = _ref.read(audioSourceProvider);
    final hapticManager = _ref.read(hapticManagerProvider);

    // Align tuner audio route/behavior with real-time input+output needs.
    try {
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.allowAirPlay,
          avAudioSessionMode: AVAudioSessionMode.measurement,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.game,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ),
      );
    } catch (e) {
      _logger.w("Failed to configure audio session for tuner: $e");
      AppErrorReporter.reportNonFatal(
        e,
        StackTrace.current,
        source: 'tuner_state.audio_session_configure',
      );
    }

    // 1. Initialize Pitch Repo (spawns isolate)
    try {
      await _pitchRepo.initialize();
      _pitchRepo.updateProcessingConfig(_config);
    } catch (error, stackTrace) {
      AppErrorReporter.reportNonFatal(
        error,
        stackTrace,
        source: 'tuner_state.pitch_repo_initialize',
        context: <String, Object?>{
          'noiseGate': _config.minRmsForPitch,
          'smoothingWindow': _config.smoothingWindowSize,
        },
      );
      _logger.e('Failed to initialize pitch repo: $error');
      return;
    }

    // 2. Subscribe to Pitch Stream
    _pitchSubscription = _pitchRepo.pitchStream.listen(
      (rawResult) {
        if (!mounted) return;
        if (rawResult.status == TuningStatus.noSignal) {
          _pendingNoSignalFrames++;
          final now = DateTime.now();
          final withinHoldWindow =
              _lastDetectedAt != null &&
              now.difference(_lastDetectedAt!).inMilliseconds <=
                  _noSignalHoldMs;
          final belowDropFrames = _pendingNoSignalFrames < _noSignalDropFrames;

          if ((withinHoldWindow || belowDropFrames) &&
              _lastDetectedResult != null) {
            state = _lastDetectedResult!;
            return;
          }

          _frequencyBuffer.clear();
          _lastDetectedResult = null;
          state = rawResult;
          return;
        }

        _pendingNoSignalFrames = 0;
        _lastDetectedAt = DateTime.now();
        _frequencyBuffer.add(rawResult.frequency);
        if (_frequencyBuffer.length > _config.smoothingWindowSize) {
          _frequencyBuffer.removeFirst();
        }

        final averageFreq =
            _frequencyBuffer.reduce((a, b) => a + b) / _frequencyBuffer.length;

        final smoothedResult = _noteCalculator.calculate(
          averageFreq,
          allowedNoteNames: _allowedNotes,
        );
        _lastDetectedResult = smoothedResult;
        hapticManager.feedback(smoothedResult.status);
        state = smoothedResult;
      },
      onError: (Object error, StackTrace stackTrace) {
        AppErrorReporter.reportNonFatal(
          error,
          stackTrace,
          source: 'tuner_state.pitch_stream',
          context: <String, Object?>{
            'noiseGate': _config.minRmsForPitch,
            'smoothingWindow': _config.smoothingWindowSize,
          },
        );
      },
    );

    // 3. Pipe Audio Data to Pitch Repo
    _audioSubscription = audioSource.audioStream.listen(
      (buffer) {
        final sampleRate = audioSource.actualSampleRate;
        if (sampleRate != null &&
            sampleRate > 0 &&
            (_lastInputSampleRate == null ||
                (sampleRate - _lastInputSampleRate!).abs() >= 1.0)) {
          _pitchRepo.updateInputSampleRate(sampleRate);
          _lastInputSampleRate = sampleRate;
        }
        _pitchRepo.addAudioData(buffer);
      },
      onError: (Object error, StackTrace stackTrace) {
        AppErrorReporter.reportNonFatal(
          error,
          stackTrace,
          source: 'tuner_state.audio_stream',
          context: <String, Object?>{
            'noiseGate': _config.minRmsForPitch,
            'smoothingWindow': _config.smoothingWindowSize,
          },
        );
      },
    );

    // 4. Start Audio Capture
    final result = await audioSource.startCapture();
    result.fold((failure) {
      _logger.e("Failed to start audio capture: ${failure.message}");
      AppErrorReporter.reportNonFatal(
        StateError(failure.message),
        StackTrace.current,
        source: 'tuner_state.start_capture',
      );
    }, (_) => _logger.i("Audio capture started successfully"));
  }

  Future<void> stop() async {
    _logger.i("TunerStateNotifier: Stopping...");
    try {
      await _audioSubscription?.cancel();
      await _pitchSubscription?.cancel();
    } catch (error, stackTrace) {
      AppErrorReporter.reportNonFatal(
        error,
        stackTrace,
        source: 'tuner_state.stop_subscriptions',
      );
    }
    _audioSubscription = null;
    _pitchSubscription = null;
    _pendingNoSignalFrames = 0;
    _lastDetectedAt = null;
    _lastDetectedResult = null;
    _lastInputSampleRate = null;
    _frequencyBuffer.clear();
    try {
      await _ref.read(audioSourceProvider).stopCapture();
    } catch (error, stackTrace) {
      AppErrorReporter.reportNonFatal(
        error,
        stackTrace,
        source: 'tuner_state.stop_capture',
      );
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
