import 'package:flutter_test/flutter_test.dart';
import 'package:vibetuner/features/tuner_engine/data/repositories/pitch_repository_impl.dart';
import 'package:vibetuner/features/tuner_engine/domain/entities/tuner_processing_config.dart';

void main() {
  const config = TunerProcessingConfig(
    minRmsForPitch: 0.01,
    minDetectableFrequency: 50,
    maxDetectableFrequency: 1500,
    smoothingWindowSize: 5,
  );

  test('rejects unpitched input', () {
    final shouldEmit = PitchRepositoryImpl.shouldEmitPitchResult(
      pitched: false,
      frequency: 440,
      rms: 0.03,
      config: config,
    );

    expect(shouldEmit, isFalse);
  });

  test('rejects low-rms noisy frame', () {
    final shouldEmit = PitchRepositoryImpl.shouldEmitPitchResult(
      pitched: true,
      frequency: 440,
      rms: 0.001,
      config: config,
    );

    expect(shouldEmit, isFalse);
  });

  test('rejects out-of-range frequency', () {
    final tooLow = PitchRepositoryImpl.shouldEmitPitchResult(
      pitched: true,
      frequency: 30,
      rms: 0.03,
      config: config,
    );
    final tooHigh = PitchRepositoryImpl.shouldEmitPitchResult(
      pitched: true,
      frequency: 2000,
      rms: 0.03,
      config: config,
    );

    expect(tooLow, isFalse);
    expect(tooHigh, isFalse);
  });

  test('accepts valid pitched frame within threshold', () {
    final shouldEmit = PitchRepositoryImpl.shouldEmitPitchResult(
      pitched: true,
      frequency: 440,
      rms: 0.03,
      config: config,
    );

    expect(shouldEmit, isTrue);
  });
}
