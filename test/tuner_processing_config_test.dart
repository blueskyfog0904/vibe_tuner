import 'package:flutter_test/flutter_test.dart';
import 'package:vibetuner/features/tuner_engine/domain/entities/tuner_processing_config.dart';

void main() {
  test('default processing config has valid ranges', () {
    const config = TunerProcessingConfig.defaults();

    expect(config.minRmsForPitch, greaterThan(0));
    expect(
      config.maxDetectableFrequency,
      greaterThan(config.minDetectableFrequency),
    );
    expect(config.smoothingWindowSize, greaterThan(0));
    expect(config.maxWindowsPerDetector, greaterThan(0));
    expect(config.detectorWindowSizes, isNotEmpty);
  });

  test('processing config map roundtrip keeps values', () {
    const config = TunerProcessingConfig(
      minRmsForPitch: 0.02,
      minDetectableFrequency: 70,
      maxDetectableFrequency: 1200,
      smoothingWindowSize: 7,
      maxWindowsPerDetector: 2,
      detectorWindowSizes: [1024],
      stringProfiles: [
        StringSensitivityProfile(
          stringNumber: 1,
          minFrequency: 286,
          maxFrequency: 380,
          rmsMultiplier: 0.7,
          smoothingWindowSize: 3,
          noSignalHoldMs: 700,
          noSignalDropFrames: 7,
        ),
      ],
    );

    final restored = TunerProcessingConfig.fromMap(config.toMap());

    expect(restored.minRmsForPitch, config.minRmsForPitch);
    expect(restored.minDetectableFrequency, config.minDetectableFrequency);
    expect(restored.maxDetectableFrequency, config.maxDetectableFrequency);
    expect(restored.smoothingWindowSize, config.smoothingWindowSize);
    expect(restored.maxWindowsPerDetector, config.maxWindowsPerDetector);
    expect(restored.detectorWindowSizes, config.detectorWindowSizes);
    expect(restored.stringProfiles, hasLength(1));
    expect(restored.stringProfiles.first.stringNumber, 1);
    expect(restored.stringProfiles.first.rmsMultiplier, 0.7);
  });
}
