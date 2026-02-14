import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:logger/logger.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:pitch_detector_dart/pitch_detector_result.dart';

import '../../../../core/constants/audio_constants.dart';
import '../../../../core/math/note_calculator.dart';
import '../../domain/entities/tuning_result.dart';
import '../../domain/entities/tuner_processing_config.dart';
import '../../domain/repositories/pitch_repository.dart';

class PitchRepositoryImpl implements PitchRepository {
  final Logger _logger = Logger();
  TunerProcessingConfig _config = const TunerProcessingConfig.defaults();
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _responsePort;
  StreamSubscription? _responseSubscription;
  final StreamController<TuningResult> _pitchStreamController =
      StreamController.broadcast();

  @override
  Stream<TuningResult> get pitchStream => _pitchStreamController.stream;

  @override
  Future<void> initialize() async {
    if (_isolate != null && _sendPort != null) {
      _logger.d('PitchProcessor Isolate already initialized');
      return;
    }

    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _pitchProcessorEntryPoint,
      receivePort.sendPort,
    );

    _sendPort = await receivePort.first as SendPort;
    receivePort.close();

    _responsePort = ReceivePort();
    _sendPort!.send({'type': 'init', 'port': _responsePort!.sendPort});
    _sendPort!.send({'type': 'config', 'config': _config.toMap()});

    _responseSubscription = _responsePort!.listen((message) {
      if (message is TuningResult && !_pitchStreamController.isClosed) {
        _pitchStreamController.add(message);
      }
    });

    _logger.i('PitchProcessor Isolate initialized');
  }

  @override
  void updateProcessingConfig(TunerProcessingConfig config) {
    _config = config;
    if (_sendPort != null) {
      _sendPort!.send({'type': 'config', 'config': _config.toMap()});
    }
  }

  @override
  void updateInputSampleRate(double sampleRate) {
    if (sampleRate <= 0) return;
    if (_sendPort != null) {
      _sendPort!.send({'type': 'sample_rate', 'sampleRate': sampleRate});
    }
  }

  @override
  void addAudioData(List<double> buffer) {
    if (_sendPort != null) {
      _sendPort!.send({'type': 'data', 'buffer': buffer});
    }
  }

  @override
  void dispose() {
    _responseSubscription?.cancel();
    _responseSubscription = null;
    _responsePort?.close();
    _responsePort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _pitchStreamController.close();
    _logger.i('PitchProcessor Isolate disposed');
  }

  static void _pitchProcessorEntryPoint(SendPort mainSendPort) {
    const minNoiseFloor = 0.0005;
    const adaptiveNoiseMultiplier = 2.2;

    final ReceivePort isolateReceivePort = ReceivePort();
    mainSendPort.send(isolateReceivePort.sendPort);

    SendPort? replyPort;
    final noteCalculator = NoteCalculator();
    var config = const TunerProcessingConfig.defaults();
    var inputSampleRate = AudioConstants.sampleRate.toDouble();
    var detectorSizes = _sanitizeDetectorWindowSizes(
      config.detectorWindowSizes,
    );
    var detectors = _buildDetectors(inputSampleRate, detectorSizes);

    var isProcessing = false;
    List<double>? latestPendingBuffer;

    var noiseFloor = config.minRmsForPitch * 0.5;
    var noiseFloorInitialized = false;

    Future<void> processBuffer(List<double> buffer) async {
      final targetPort = replyPort;
      if (targetPort == null) return;
      if (buffer.isEmpty) {
        targetPort.send(TuningResult.noSignal());
        return;
      }

      try {
        _PitchFrameCandidate? bestCandidate;

        for (final windowSize in detectorSizes) {
          final detector = detectors[windowSize];
          if (detector == null || buffer.length < windowSize) continue;

          final hopSize = windowSize ~/ 4;
          final starts = _windowStartIndices(
            bufferLength: buffer.length,
            windowSize: windowSize,
            hopSize: hopSize,
            maxWindows: config.maxWindowsPerDetector,
          );

          for (final start in starts) {
            final window = buffer.sublist(start, start + windowSize);
            final rms = _calculateRms(window);

            if (!noiseFloorInitialized) {
              noiseFloor = rms;
              noiseFloorInitialized = true;
            } else if (rms < noiseFloor * 1.5) {
              noiseFloor = (noiseFloor * 0.98) + (rms * 0.02);
            }

            final adaptiveMinRms = math.max(
              config.minRmsForPitch,
              math.max(minNoiseFloor, noiseFloor * adaptiveNoiseMultiplier),
            );

            if (rms < adaptiveMinRms) continue;

            final PitchDetectorResult result = await detector
                .getPitchFromFloatBuffer(window);

            if (!_shouldEmitPitchResultWithMinRms(
              pitched: result.pitched,
              frequency: result.pitch,
              rms: rms,
              minRms: adaptiveMinRms,
              config: config,
            )) {
              continue;
            }

            final score = result.probability + (windowSize == 1024 ? 0.01 : 0);
            if (bestCandidate == null || score > bestCandidate.score) {
              bestCandidate = _PitchFrameCandidate(
                frequency: result.pitch,
                score: score,
              );
              if (score >= 0.98) {
                break;
              }
            }
          }
        }

        if (bestCandidate == null) {
          targetPort.send(TuningResult.noSignal());
          return;
        }

        targetPort.send(noteCalculator.calculate(bestCandidate.frequency));
      } catch (_) {
        targetPort.send(TuningResult.noSignal());
      }
    }

    void scheduleLatestProcessing() {
      if (isProcessing || latestPendingBuffer == null) return;
      final buffer = latestPendingBuffer!;
      latestPendingBuffer = null;
      isProcessing = true;
      processBuffer(buffer).whenComplete(() {
        isProcessing = false;
        scheduleLatestProcessing();
      });
    }

    isolateReceivePort.listen((message) {
      if (message is! Map) return;
      final type = message['type'];

      if (type == 'init') {
        replyPort = message['port'] as SendPort;
        return;
      }

      if (type == 'config') {
        final nextConfig = TunerProcessingConfig.fromMap(
          message['config'] as Map<String, Object?>,
        );
        final nextDetectorSizes = _sanitizeDetectorWindowSizes(
          nextConfig.detectorWindowSizes,
        );
        final shouldRebuildDetectors =
            nextDetectorSizes.length != detectorSizes.length ||
            nextDetectorSizes.any((size) => !detectorSizes.contains(size));
        config = nextConfig;
        if (shouldRebuildDetectors) {
          detectorSizes = nextDetectorSizes;
          detectors = _buildDetectors(inputSampleRate, detectorSizes);
        }
        return;
      }

      if (type == 'sample_rate') {
        final rawSampleRate = message['sampleRate'];
        if (rawSampleRate is num && rawSampleRate > 0) {
          final next = rawSampleRate.toDouble();
          if ((next - inputSampleRate).abs() >= 1.0) {
            inputSampleRate = next;
            detectors = _buildDetectors(inputSampleRate, detectorSizes);
          }
        }
        return;
      }

      if (type == 'data' && replyPort != null) {
        final rawBuffer = message['buffer'];
        if (rawBuffer is List<double>) {
          latestPendingBuffer = rawBuffer;
        } else if (rawBuffer is List) {
          latestPendingBuffer = rawBuffer.cast<double>();
        } else {
          return;
        }
        scheduleLatestProcessing();
      }
    });
  }

  static Map<int, PitchDetector> _buildDetectors(
    double sampleRate,
    List<int> sizes,
  ) {
    final map = <int, PitchDetector>{};
    for (final size in sizes) {
      map[size] = PitchDetector(audioSampleRate: sampleRate, bufferSize: size);
    }
    return map;
  }

  static List<int> _sanitizeDetectorWindowSizes(List<int> rawSizes) {
    final cleaned = rawSizes.where((size) => size > 0).toSet().toList()..sort();
    if (cleaned.isEmpty) return const [1024, 2048];
    return cleaned;
  }

  static List<int> _windowStartIndices({
    required int bufferLength,
    required int windowSize,
    required int hopSize,
    required int maxWindows,
  }) {
    if (bufferLength < windowSize || maxWindows <= 0) return const <int>[];

    final starts = <int>[];
    var start = bufferLength - windowSize;
    while (start >= 0 && starts.length < maxWindows) {
      starts.add(start);
      start -= hopSize;
    }
    return starts;
  }

  static bool _shouldEmitPitchResultWithMinRms({
    required bool pitched,
    required double frequency,
    required double rms,
    required double minRms,
    required TunerProcessingConfig config,
  }) {
    if (!pitched) return false;
    if (!frequency.isFinite || frequency <= 0) return false;
    if (rms < _minRmsForFrequency(config, frequency, minRms)) return false;
    if (frequency < config.minDetectableFrequency) return false;
    if (frequency > config.maxDetectableFrequency) return false;
    return true;
  }

  static bool shouldEmitPitchResult({
    required bool pitched,
    required double frequency,
    required double rms,
    required TunerProcessingConfig config,
  }) {
    if (!pitched) return false;
    if (rms < _minRmsForFrequency(config, frequency, config.minRmsForPitch)) {
      return false;
    }
    if (frequency < config.minDetectableFrequency) return false;
    if (frequency > config.maxDetectableFrequency) return false;
    return true;
  }

  static double _minRmsForFrequency(
    TunerProcessingConfig config,
    double frequency,
    double baselineMinRms,
  ) {
    final profile = config.profileForFrequency(frequency);
    if (profile == null) return baselineMinRms;
    final adjusted = baselineMinRms * profile.rmsMultiplier;
    return math.max(0.0001, adjusted);
  }

  static double _calculateRms(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    var sumSquares = 0.0;
    for (final sample in samples) {
      sumSquares += sample * sample;
    }
    return math.sqrt(sumSquares / samples.length);
  }
}

class _PitchFrameCandidate {
  final double frequency;
  final double score;

  const _PitchFrameCandidate({required this.frequency, required this.score});
}
