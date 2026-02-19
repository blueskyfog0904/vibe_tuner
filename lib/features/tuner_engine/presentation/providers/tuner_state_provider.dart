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
      // Keep repository lifecycle tied to notifier lifecycle.
      final pitchRepo = ref.watch(pitchRepositoryProvider);
      final config = ref.read(tunerProcessingConfigProvider);
      final settings =
          ref.read(tunerSettingsProvider).valueOrNull ??
          const TunerSettings.defaults();
      final notifier = TunerStateNotifier(ref, pitchRepo, config, settings);

      ref.listen(tunerProcessingConfigProvider, (_, next) {
        notifier.updateProcessingConfig(next);
      });
      ref.listen(tunerSettingsProvider, (_, next) {
        final current = next.valueOrNull ?? const TunerSettings.defaults();
        notifier.updateTuningSettings(current);
      });
      return notifier;
    });

class TunerStateNotifier extends StateNotifier<TuningResult> {
  final Ref _ref;
  final PitchRepository _pitchRepo;
  TunerProcessingConfig _config;
  TunerSettings _settings;
  late Set<String>? _allowedNotes;
  late Set<int>? _allowedMidiNumbers;
  final Logger _logger = Logger();
  final Queue<double> _frequencyBuffer = Queue<double>();
  late NoteCalculator _noteCalculator;
  StreamSubscription? _audioSubscription;
  StreamSubscription? _pitchSubscription;
  DateTime? _lastDetectedAt;
  TuningResult? _lastDetectedResult;
  StringSensitivityProfile? _activeStringProfile;
  int _pendingNoSignalFrames = 0;
  double? _lastInputSampleRate;
  Future<void> _lifecycleOps = Future<void>.value();
  TuningStatus _stableStatus = TuningStatus.noSignal;
  TuningStatus? _pendingStatus;
  int _pendingStatusFrames = 0;
  double? _smoothedCents;

  static const int _requiredStableStatusFrames = 2;

  TunerStateNotifier(this._ref, this._pitchRepo, this._config, this._settings)
    : super(TuningResult.noSignal()) {
    _rebuildDerivedSettings();
    start();
  }

  void updateProcessingConfig(TunerProcessingConfig config) {
    _config = config;
    _pitchRepo.updateProcessingConfig(config);
  }

  void updateTuningSettings(TunerSettings settings) {
    _settings = settings;
    _rebuildDerivedSettings();
  }

  void _rebuildDerivedSettings() {
    _noteCalculator = NoteCalculator(
      a4Reference: _settings.a4Reference,
      perfectCentsThreshold: perfectCentsThresholdFromSensitivity(
        _settings.sensitivity,
      ),
    );
    _allowedNotes = allowedNoteNamesFromPreset(_settings.tuningPreset);
    _allowedMidiNumbers = allowedMidiNumbersFromPreset(_settings.tuningPreset);
  }

  Future<void> start() async {
    return _enqueueLifecycleOp(_startInternal);
  }

  Future<void> _startInternal() async {
    if (_audioSubscription != null) return;

    _logger.i("TunerStateNotifier: Starting...");
    _pendingNoSignalFrames = 0;
    _lastDetectedAt = null;
    _lastDetectedResult = null;
    _activeStringProfile = null;
    _lastInputSampleRate = null;
    _frequencyBuffer.clear();
    _stableStatus = TuningStatus.noSignal;
    _pendingStatus = null;
    _pendingStatusFrames = 0;
    _smoothedCents = null;
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
          final noSignalHoldMs =
              _activeStringProfile?.noSignalHoldMs ??
              AudioConstants.noSignalHoldMs;
          final noSignalDropFrames =
              _activeStringProfile?.noSignalDropFrames ??
              AudioConstants.noSignalDropFrames;
          final withinHoldWindow =
              _lastDetectedAt != null &&
              now.difference(_lastDetectedAt!).inMilliseconds <= noSignalHoldMs;
          final belowDropFrames = _pendingNoSignalFrames < noSignalDropFrames;

          if ((withinHoldWindow || belowDropFrames) &&
              _lastDetectedResult != null) {
            state = _lastDetectedResult!;
            return;
          }

          _frequencyBuffer.clear();
          _lastDetectedResult = null;
          _activeStringProfile = null;
          _stableStatus = TuningStatus.noSignal;
          _pendingStatus = null;
          _pendingStatusFrames = 0;
          _smoothedCents = null;
          state = rawResult;
          return;
        }

        _pendingNoSignalFrames = 0;
        _lastDetectedAt = DateTime.now();
        _activeStringProfile = _config.profileForFrequency(rawResult.frequency);
        final smoothingWindowSize =
            _activeStringProfile?.smoothingWindowSize ??
            _config.smoothingWindowSize;
        _frequencyBuffer.add(rawResult.frequency);
        while (_frequencyBuffer.length > smoothingWindowSize) {
          _frequencyBuffer.removeFirst();
        }

        final averageFreq =
            _frequencyBuffer.reduce((a, b) => a + b) / _frequencyBuffer.length;

        final smoothedResult = _noteCalculator.calculate(
          averageFreq,
          allowedNoteNames: _allowedNotes,
          allowedMidiNumbers: _allowedMidiNumbers,
        );

        final smoothedCents = _smoothCents(
          rawCents: smoothedResult.cents,
          smoothingWindowSize: smoothingWindowSize,
        );
        final stableStatus = _stabilizeStatus(smoothedResult.status);
        _smoothedCents = smoothedCents;

        final filteredResult = TuningResult(
          frequency: averageFreq,
          noteName: smoothedResult.noteName,
          octave: smoothedResult.octave,
          cents: smoothedCents,
          targetFrequency: smoothedResult.targetFrequency,
          status: stableStatus,
        );
        _lastDetectedResult = filteredResult;
        hapticManager.feedback(filteredResult.status);
        state = filteredResult;
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
    return _enqueueLifecycleOp(_stopInternal);
  }

  Future<void> _stopInternal() async {
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
    _activeStringProfile = null;
    _lastInputSampleRate = null;
    _stableStatus = TuningStatus.noSignal;
    _pendingStatus = null;
    _pendingStatusFrames = 0;
    _smoothedCents = null;
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

  Future<void> _enqueueLifecycleOp(Future<void> Function() op) {
    _lifecycleOps = _lifecycleOps.then((_) => op()).catchError((_) {});
    return _lifecycleOps;
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }

  double _smoothCents({
    required double rawCents,
    required int smoothingWindowSize,
  }) {
    final previous = _smoothedCents;
    if (previous == null) return rawCents;

    final alpha = _centsSmoothingFactor(smoothingWindowSize);
    return previous + (rawCents - previous) * alpha;
  }

  double _centsSmoothingFactor(int smoothingWindowSize) {
    final normalizedWindow = smoothingWindowSize.clamp(2, 12);
    return (0.45 - (normalizedWindow - 2) * 0.015).clamp(0.16, 0.45);
  }

  TuningStatus _stabilizeStatus(TuningStatus candidateStatus) {
    if (candidateStatus == TuningStatus.noSignal) {
      _stableStatus = TuningStatus.noSignal;
      _pendingStatus = null;
      _pendingStatusFrames = 0;
      return TuningStatus.noSignal;
    }

    if (_pendingStatus != candidateStatus) {
      _pendingStatus = candidateStatus;
      _pendingStatusFrames = 1;
      return _stableStatus;
    }

    _pendingStatusFrames++;
    if (_pendingStatusFrames >= _requiredStableStatusFrames) {
      _stableStatus = candidateStatus;
      _pendingStatus = null;
      _pendingStatusFrames = 0;
      return _stableStatus;
    }

    return _stableStatus;
  }
}
