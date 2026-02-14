import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibetuner/core/constants/audio_constants.dart';
import 'package:vibetuner/core/math/note_calculator.dart';
import 'package:vibetuner/features/tuner_engine/domain/entities/tuning_result.dart';
import 'package:vibetuner/features/tuner_engine/domain/entities/tuner_settings.dart';
import 'package:vibetuner/features/tuner_engine/presentation/providers/tuner_settings_provider.dart';

void main() {
  test('note calculator reflects custom A4 reference', () {
    const calc440 = NoteCalculator(a4Reference: 440.0);
    const calc432 = NoteCalculator(a4Reference: 432.0);

    final r440 = calc440.calculate(440.0);
    final r432 = calc432.calculate(440.0);

    expect(r440.cents.abs() < 0.01, isTrue);
    expect(r432.cents.abs() > 1.0, isTrue);
  });

  test('sensitivity changes perfect cents threshold', () {
    final strict = NoteCalculator(
      perfectCentsThreshold: perfectCentsThresholdFromSensitivity(
        TunerSensitivity.high,
      ),
    );
    final loose = NoteCalculator(
      perfectCentsThreshold: perfectCentsThresholdFromSensitivity(
        TunerSensitivity.low,
      ),
    );

    final strictResult = strict.calculate(442.0);
    final looseResult = loose.calculate(442.0);

    expect(strictResult.status, isNot(TuningStatus.perfect));
    expect(looseResult.status, TuningStatus.perfect);
  });

  test('settings provider persists updates', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(tunerSettingsProvider.future);
    final notifier = container.read(tunerSettingsProvider.notifier);

    await notifier.setA4Reference(432.0);
    await notifier.setSensitivity(TunerSensitivity.high);
    await notifier.setNoiseGate(0.02);
    await notifier.setTuningPreset(TuningPreset.guitarStandard);
    await notifier.setLowLatencyMode(true);
    await notifier.setStringSensitivity(1, 1.65);
    await notifier.setStringSensitivity(5, 0.75);
    await notifier.setStringHoldMs(2, 640);
    await notifier.setStringStabilityWindow(3, 7);

    final current = container.read(tunerSettingsProvider).valueOrNull;
    expect(current, isNotNull);
    expect(current!.a4Reference, 432.0);
    expect(current.sensitivity, TunerSensitivity.high);
    expect(current.noiseGate, 0.02);
    expect(current.tuningPreset, TuningPreset.guitarStandard);
    expect(current.lowLatencyMode, isTrue);
    expect(current.sensitivityForString(1), closeTo(1.65, 0.0001));
    expect(current.sensitivityForString(5), closeTo(0.75, 0.0001));
    expect(current.holdMsForString(2), 640);
    expect(current.stabilityWindowForString(3), 7);
  });

  test('normalizers clamp and snap values safely', () {
    expect(normalizeA4Reference(431.2), 432.0);
    expect(normalizeA4Reference(439.9), 440.0);
    expect(normalizeNoiseGate(-1), minNoiseGate);
    expect(normalizeNoiseGate(1), maxNoiseGate);
  });

  test('preset provides expected allowed note names', () {
    expect(allowedNoteNamesFromPreset(TuningPreset.chromatic), isNull);
    expect(allowedNoteNamesFromPreset(TuningPreset.guitarStandard), {
      'E',
      'A',
      'D',
      'G',
      'B',
    });
    expect(allowedNoteNamesFromPreset(TuningPreset.ukuleleStandard), {
      'G',
      'C',
      'E',
      'A',
    });
  });

  test('preset provides expected fixed midi targets', () {
    expect(allowedMidiNumbersFromPreset(TuningPreset.chromatic), isNull);
    expect(allowedMidiNumbersFromPreset(TuningPreset.guitarStandard), {
      40,
      45,
      50,
      55,
      59,
      64,
    });
    expect(allowedMidiNumbersFromPreset(TuningPreset.ukuleleStandard), {
      67,
      60,
      64,
      69,
    });
  });

  test('preset frequency range is narrowed for tuning presets', () {
    expect(frequencyRangeFromPreset(TuningPreset.guitarStandard), (
      65.0,
      1000.0,
    ));
    expect(frequencyRangeFromPreset(TuningPreset.ukuleleStandard), (
      240.0,
      470.0,
    ));
    expect(frequencyRangeFromPreset(TuningPreset.chromatic), (
      AudioConstants.minDetectableFrequency,
      AudioConstants.maxDetectableFrequency,
    ));
  });

  test('note calculator can constrain to allowed notes', () {
    const calc = NoteCalculator(a4Reference: 440.0);

    final unconstrained = calc.calculate(415.3); // near G#4/A♭4
    final constrained = calc.calculate(
      415.3,
      allowedNoteNames: {'G', 'A', 'B', 'C', 'D', 'E'},
    );

    expect(unconstrained.noteName, isNot('A'));
    expect(constrained.noteName, anyOf('G', 'A'));
  });

  test('note calculator can constrain to fixed midi targets', () {
    const calc = NoteCalculator(a4Reference: 440.0);

    final constrained = calc.calculate(
      164.8, // E3 harmonic-like frequency
      allowedMidiNumbers: {40, 45, 50, 55, 59, 64}, // guitar open strings
    );

    const openStringTargets = <double>[
      82.4069, // E2
      110.0, // A2
      146.8324, // D3
      195.9977, // G3
      246.9417, // B3
      329.6276, // E4
    ];
    final isOpenStringTarget = openStringTargets.any(
      (target) => (constrained.targetFrequency - target).abs() < 0.6,
    );
    expect(isOpenStringTarget, isTrue);
  });

  test(
    'string sensitivity affects guitar profile threshold multiplier',
    () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(tunerSettingsProvider.future);
      final notifier = container.read(tunerSettingsProvider.notifier);

      await notifier.setTuningPreset(TuningPreset.guitarStandard);
      await notifier.setStringSensitivity(1, 2.0); // max sensitivity

      final config = container.read(tunerProcessingConfigProvider);
      final firstStringProfile = config.stringProfiles.firstWhere(
        (p) => p.stringNumber == 1,
      );

      // Base 0.70 / sensitivity(2.0) = 0.35 (lower threshold => more sensitive).
      expect(firstStringProfile.rmsMultiplier, closeTo(0.35, 0.0001));
    },
  );

  test(
    'low latency mode reduces detector workload in processing config',
    () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(tunerSettingsProvider.future);
      final notifier = container.read(tunerSettingsProvider.notifier);

      await notifier.setTuningPreset(TuningPreset.guitarStandard);
      await notifier.setLowLatencyMode(true);

      final config = container.read(tunerProcessingConfigProvider);
      expect(config.maxWindowsPerDetector, 1);
      expect(config.detectorWindowSizes, [1024, 2048]);

      final fifthString = config.stringProfiles.firstWhere(
        (p) => p.stringNumber == 5,
      );
      expect(fifthString.noSignalHoldMs, lessThanOrEqualTo(260));
      expect(fifthString.noSignalDropFrames, lessThanOrEqualTo(2));
      expect(fifthString.smoothingWindowSize, lessThanOrEqualTo(4));
    },
  );

  test('iPhone 11 Pro guitar preset applies recommended values', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(tunerSettingsProvider.future);
    final notifier = container.read(tunerSettingsProvider.notifier);
    await notifier.applyIphone11ProGuitarPreset();

    final current = container.read(tunerSettingsProvider).valueOrNull;
    expect(current, isNotNull);
    expect(current!.tuningPreset, TuningPreset.guitarStandard);
    expect(current.lowLatencyMode, isTrue);
    expect(current.noiseGate, closeTo(0.0045, 0.0001));
    expect(
      current.stringSensitivities,
      iphone11ProRecommendedStringSensitivities,
    );
    expect(current.stringHoldMs, iphone11ProRecommendedStringHoldMs);
    expect(
      current.stringStabilityWindows,
      iphone11ProRecommendedStabilityWindows,
    );
  });
}
