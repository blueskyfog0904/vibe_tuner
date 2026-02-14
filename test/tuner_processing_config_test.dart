import 'package:flutter_test/flutter_test.dart';
import 'package:vibetuner/features/tuner_engine/domain/entities/tuner_processing_config.dart';

void main() {
  test('default processing config has valid ranges', () {
    const config = TunerProcessingConfig.defaults();

    expect(config.minRmsForPitch, greaterThan(0));
    expect(config.maxDetectableFrequency, greaterThan(config.minDetectableFrequency));
    expect(config.smoothingWindowSize, greaterThan(0));
  });

  test('processing config map roundtrip keeps values', () {
    const config = TunerProcessingConfig(
      minRmsForPitch: 0.02,
      minDetectableFrequency: 70,
      maxDetectableFrequency: 1200,
      smoothingWindowSize: 7,
    );

    final restored = TunerProcessingConfig.fromMap(config.toMap());

    expect(restored.minRmsForPitch, config.minRmsForPitch);
    expect(restored.minDetectableFrequency, config.minDetectableFrequency);
    expect(restored.maxDetectableFrequency, config.maxDetectableFrequency);
    expect(restored.smoothingWindowSize, config.smoothingWindowSize);
  });
}
