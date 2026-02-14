import '../../../../core/constants/audio_constants.dart';

class TunerProcessingConfig {
  final double minRmsForPitch;
  final double minDetectableFrequency;
  final double maxDetectableFrequency;
  final int smoothingWindowSize;

  const TunerProcessingConfig({
    required this.minRmsForPitch,
    required this.minDetectableFrequency,
    required this.maxDetectableFrequency,
    required this.smoothingWindowSize,
  });

  const TunerProcessingConfig.defaults()
      : minRmsForPitch = AudioConstants.minRmsForPitch,
        minDetectableFrequency = AudioConstants.minDetectableFrequency,
        maxDetectableFrequency = AudioConstants.maxDetectableFrequency,
        smoothingWindowSize = AudioConstants.smoothingWindowSize;

  TunerProcessingConfig copyWith({
    double? minRmsForPitch,
    double? minDetectableFrequency,
    double? maxDetectableFrequency,
    int? smoothingWindowSize,
  }) {
    return TunerProcessingConfig(
      minRmsForPitch: minRmsForPitch ?? this.minRmsForPitch,
      minDetectableFrequency:
          minDetectableFrequency ?? this.minDetectableFrequency,
      maxDetectableFrequency:
          maxDetectableFrequency ?? this.maxDetectableFrequency,
      smoothingWindowSize: smoothingWindowSize ?? this.smoothingWindowSize,
    );
  }

  Map<String, Object> toMap() {
    return {
      'minRmsForPitch': minRmsForPitch,
      'minDetectableFrequency': minDetectableFrequency,
      'maxDetectableFrequency': maxDetectableFrequency,
      'smoothingWindowSize': smoothingWindowSize,
    };
  }

  factory TunerProcessingConfig.fromMap(Map<String, Object?> map) {
    return TunerProcessingConfig(
      minRmsForPitch: (map['minRmsForPitch'] as num).toDouble(),
      minDetectableFrequency: (map['minDetectableFrequency'] as num).toDouble(),
      maxDetectableFrequency: (map['maxDetectableFrequency'] as num).toDouble(),
      smoothingWindowSize: (map['smoothingWindowSize'] as num).toInt(),
    );
  }
}
