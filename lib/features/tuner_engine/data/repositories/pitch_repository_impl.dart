import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:logger/logger.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:pitch_detector_dart/pitch_detector_result.dart';

import '../../../../core/constants/audio_constants.dart';
import '../../../../core/math/note_calculator.dart';
import '../../domain/entities/tuning_result.dart'; // Fixed import path
import '../../domain/entities/tuner_processing_config.dart';
import '../../domain/repositories/pitch_repository.dart'; // Fixed import path

class PitchRepositoryImpl implements PitchRepository {
  final Logger _logger = Logger();
  TunerProcessingConfig _config = const TunerProcessingConfig.defaults();
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _responsePort;
  StreamSubscription? _responseSubscription;
  final StreamController<TuningResult> _pitchStreamController = StreamController.broadcast();

  @override
  Stream<TuningResult> get pitchStream => _pitchStreamController.stream;

  @override
  Future<void> initialize() async {
    // Guard against repeated start/stop cycles spawning multiple isolates.
    if (_isolate != null && _sendPort != null) {
      _logger.d("PitchProcessor Isolate already initialized");
      return;
    }

    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_pitchProcessorEntryPoint, receivePort.sendPort);
    
    // Wait for the isolate to send its SendPort
    _sendPort = await receivePort.first as SendPort;
    receivePort.close();
    
    // Create a temporary receive port to get processed results back
    _responsePort = ReceivePort();
    _sendPort!.send({'type': 'init', 'port': _responsePort!.sendPort});
    _sendPort!.send({'type': 'config', 'config': _config.toMap()});

    // Listen for results from the isolate
    _responseSubscription = _responsePort!.listen((message) {
      if (message is TuningResult) {
        if (!_pitchStreamController.isClosed) {
          _pitchStreamController.add(message);
        }
      }
    });

    _logger.i("PitchProcessor Isolate initialized");
  }

  @override
  void updateProcessingConfig(TunerProcessingConfig config) {
    _config = config;
    if (_sendPort != null) {
      _sendPort!.send({'type': 'config', 'config': _config.toMap()});
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
    _logger.i("PitchProcessor Isolate disposed");
  }

  /// Entry point for the Isolate
  static void _pitchProcessorEntryPoint(SendPort mainSendPort) {
    final ReceivePort isolateReceivePort = ReceivePort();
    mainSendPort.send(isolateReceivePort.sendPort);

    SendPort? replyPort;
    final pitchDetector = PitchDetector(
      audioSampleRate: AudioConstants.sampleRate.toDouble(),
      bufferSize: AudioConstants.bufferSize,
    );
    final noteCalculator = NoteCalculator();
    var config = const TunerProcessingConfig.defaults();

    isolateReceivePort.listen((message) async { // Added async
      if (message is Map) {
        final type = message['type'];

        if (type == 'init') {
          replyPort = message['port'] as SendPort;
        } else if (type == 'config') {
          config = TunerProcessingConfig.fromMap(
            message['config'] as Map<String, Object?>,
          );
        } else if (type == 'data') {
          if (replyPort != null) {
            try {
              final buffer = message['buffer'] as List<double>;

              final rms = _calculateRms(buffer);
              if (rms < config.minRmsForPitch) {
                replyPort!.send(TuningResult.noSignal());
                return;
              }
              
              // Process pitch
              // pitch_detector_dart 0.0.7 uses getPitchFromFloatBuffer for List<double>
              final PitchDetectorResult result = await pitchDetector.getPitchFromFloatBuffer(buffer);
              
              if (shouldEmitPitchResult(
                pitched: result.pitched,
                frequency: result.pitch,
                rms: rms,
                config: config,
              )) {
                // Calculate Note & Cents
                final tuningResult = noteCalculator.calculate(result.pitch);
                replyPort!.send(tuningResult);
              } else {
                replyPort!.send(TuningResult.noSignal());
              }
            } catch (e) {
              replyPort!.send(TuningResult.noSignal());
            }
          }
        }
      }
    });
  }

  static bool shouldEmitPitchResult({
    required bool pitched,
    required double frequency,
    required double rms,
    required TunerProcessingConfig config,
  }) {
    if (!pitched) return false;
    if (rms < config.minRmsForPitch) return false;
    if (frequency < config.minDetectableFrequency) return false;
    if (frequency > config.maxDetectableFrequency) return false;
    return true;
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
