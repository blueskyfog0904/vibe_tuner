import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart'; // Import Logger
import '../../data/datasources/audio_stream_source.dart';
import '../../domain/dsp/audio_processor.dart';

/// AudioProcessor Provider (Singleton-like within scope)
final audioProcessorProvider = Provider<AudioProcessor>((ref) {
  final processor = AudioProcessor();
  ref.onDispose(() => processor.dispose());
  return processor;
});

/// AudioStreamSource Provider
final audioSourceProvider = Provider<AudioStreamSource>((ref) {
  final source = AudioStreamSource();
  ref.onDispose(() => source.dispose());
  return source;
});

/// Audio Control State
class AudioControlState {
  final bool isFocusMode;
  final bool isRecording;
  final String? errorMessage;

  AudioControlState({
    this.isFocusMode = false,
    this.isRecording = false,
    this.errorMessage,
  });

  AudioControlState copyWith({
    bool? isFocusMode,
    bool? isRecording,
    String? errorMessage,
  }) {
    return AudioControlState(
      isFocusMode: isFocusMode ?? this.isFocusMode,
      isRecording: isRecording ?? this.isRecording,
      errorMessage: errorMessage,
    );
  }
}

/// Audio Control Notifier using Riverpod 2.0 Notifier
class AudioControlNotifier extends Notifier<AudioControlState> {
  
  @override
  AudioControlState build() {
    return AudioControlState();
  }

  void toggleFocusMode() {
    final processor = ref.read(audioProcessorProvider);
    final newMode = !state.isFocusMode;
    processor.setFocusMode(newMode);
    state = state.copyWith(isFocusMode: newMode);
  }

  void setRecordingState(bool isRecording) {
    state = state.copyWith(isRecording: isRecording);
  }
  
  void setError(String message) {
    state = state.copyWith(errorMessage: message);
  }
}

final audioControlProvider = NotifierProvider<AudioControlNotifier, AudioControlState>(AudioControlNotifier.new);

/// Processed Audio Stream Provider
/// UI listens to this.
final processedAudioStreamProvider = StreamProvider.autoDispose<List<double>>((ref) async* {
  final logger = Logger();
  logger.i("initializing processedAudioStreamProvider");

  // Visual feedback immediately
  yield [0.0]; 

  final processor = ref.watch(audioProcessorProvider);
  final source = ref.watch(audioSourceProvider);
  final controlNotifier = ref.read(audioControlProvider.notifier);
  
  // 1. Initialize Processor
  await processor.initialize();
  
  // 2. Setup Pipeline: Source -> Processor
  final sourceSubscription = source.audioStream.listen((data) {
    processor.process(data);
  });
  
  // 3. Start Capture
  final result = await source.startCapture();
  
  result.fold(
    (failure) {
      logger.e("Start capture failed: ${failure.message}");
      controlNotifier.setError(failure.message);
      // We don't throw here to avoid crashing the stream, but we yielded [0.0] so UI shows empty.
    },
    (_) {
      logger.i("Capture started successfully");
      controlNotifier.setRecordingState(true);
    },
  );

  // Cleanup on dispose
  ref.onDispose(() async {
    sourceSubscription.cancel();
    await source.stopCapture();
    controlNotifier.setRecordingState(false);
  });
  
  // 4. Yield the processed stream
  yield* processor.processedStream;
});
