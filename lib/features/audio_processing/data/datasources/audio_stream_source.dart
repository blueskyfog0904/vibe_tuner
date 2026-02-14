import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/constants/audio_constants.dart';
import '../../../../core/logging/error_reporter.dart';

import 'package:logger/logger.dart';

class AudioStreamSource {
  final FlutterAudioCapture _audioCapture = FlutterAudioCapture();
  final StreamController<List<double>> _audioStreamController =
      StreamController.broadcast();
  final Logger _logger = Logger();
  bool _isCapturing = false;

  Stream<List<double>> get audioStream => _audioStreamController.stream;
  double? get actualSampleRate => _audioCapture.actualSampleRate;

  /// 오디오 캡쳐 시작
  Future<Either<Failure, void>> startCapture() async {
    if (_isCapturing) {
      return const Right(null);
    }
    try {
      await _audioCapture.init(); // Initialize the plugin
      _logger.d("AudioCapture initialized");

      await _audioCapture.start(
        (dynamic obj) {
          // flutter_audio_capture returns Float32List in most cases on mobile
          if (obj is Float32List) {
            _audioStreamController.add(obj.toList());
          } else if (obj is List<double>) {
            _audioStreamController.add(obj);
          } else if (obj is List) {
            _audioStreamController.add(obj.cast<double>());
          }
          // _logger.d("Data received: ${obj.runtimeType}"); // Too verbose
        },
        (Object e) {
          _logger.e("Audio Capture Error: $e");
          _isCapturing = false;
          AppErrorReporter.reportNonFatal(
            e,
            StackTrace.current,
            source: 'audio_stream_source.capture_callback',
            context: <String, Object?>{
              'sampleRate': AudioConstants.sampleRate,
              'bufferSize': AudioConstants.bufferSize,
            },
          );
          _audioStreamController.addError(AudioFailure(e.toString()));
        },
        sampleRate: AudioConstants.sampleRate,
        bufferSize: AudioConstants.bufferSize,
      );
      _isCapturing = true;
      return const Right(null);
    } catch (e, stackTrace) {
      _isCapturing = false;
      AppErrorReporter.reportNonFatal(
        e,
        stackTrace,
        source: 'audio_stream_source.start_capture',
        context: <String, Object?>{
          'sampleRate': AudioConstants.sampleRate,
          'bufferSize': AudioConstants.bufferSize,
        },
      );
      return Left(AudioFailure("Failed to start audio capture: $e"));
    }
  }

  /// 오디오 캡쳐 중지
  Future<void> stopCapture() async {
    if (!_isCapturing) return;
    try {
      await _audioCapture.stop();
    } catch (e, stackTrace) {
      AppErrorReporter.reportNonFatal(
        e,
        stackTrace,
        source: 'audio_stream_source.stop_capture',
      );
    } finally {
      // Always clear local capture flag so future restarts are not blocked.
      _isCapturing = false;
    }
  }

  void dispose() {
    _audioStreamController.close();
  }
}
