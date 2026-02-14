import 'dart:async';
import 'dart:isolate';
// import 'package:logger/logger.dart'; // Unused
import 'bandpass_filter.dart';
import '../../../../core/constants/audio_constants.dart';

/// 메시트 타입 정의 (Internal usage only)
// class _IsolateMessage { ... } // Unused

class AudioProcessor {
  Isolate? _isolate;
  SendPort? _sendPort;
  StreamController<List<double>>? _processedDataController;
  // final Logger _logger = Logger(); // Unused
  // bool _isFocusMode = false; // Unused in main isolate logic except for setter

  Stream<List<double>> get processedStream => _processedDataController?.stream ?? Stream.empty();

  void setFocusMode(bool enabled) {
    // _isFocusMode = enabled;
    if (_sendPort != null) {
      _sendPort!.send({'type': 'config', 'focusMode': enabled});
    }
  }

  Future<void> initialize() async {
    _processedDataController = StreamController.broadcast();
    ReceivePort receivePort = ReceivePort();
    
    _isolate = await Isolate.spawn(_audioProcessorEntryPoint, receivePort.sendPort);
    
    // 첫 번째 메시지는 SendPort입니다.
    _sendPort = await receivePort.first as SendPort;
    
    ReceivePort responsePort = ReceivePort();
    _sendPort!.send({'type': 'init', 'port': responsePort.sendPort});
    
    responsePort.listen((message) {
      if (message is List<double>) {
        _processedDataController?.add(message);
      }
    });
  }

  void process(List<double> data) {
    if (_sendPort != null) {
      _sendPort!.send({'type': 'data', 'data': data});
    }
  }

  void dispose() {
    _isolate?.kill();
    _processedDataController?.close();
  }

  static void _audioProcessorEntryPoint(SendPort mainSendPort) {
    ReceivePort isolateReceivePort = ReceivePort();
    mainSendPort.send(isolateReceivePort.sendPort);

    final filter = BandpassFilter(sampleRate: AudioConstants.sampleRate);
    SendPort? replyPort;
    bool focusMode = false; 

    isolateReceivePort.listen((message) {
      if (message is Map) {
        final type = message['type'];
        
        if (type == 'init') {
          replyPort = message['port'] as SendPort;
        } else if (type == 'config') {
          focusMode = message['focusMode'] as bool;
        } else if (type == 'data') {
          final data = message['data'] as List<double>;
          if (replyPort != null) {
            if (focusMode) {
              final filtered = filter.process(data);
              replyPort!.send(filtered);
            } else {
              // Bypass
              replyPort!.send(data);
            }
          }
        }
      }
    });
  }
}
