import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      perfectCentsThreshold:
          perfectCentsThresholdFromSensitivity(TunerSensitivity.high),
    );
    final loose = NoteCalculator(
      perfectCentsThreshold:
          perfectCentsThresholdFromSensitivity(TunerSensitivity.low),
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

    final current = container.read(tunerSettingsProvider).valueOrNull;
    expect(current, isNotNull);
    expect(current!.a4Reference, 432.0);
    expect(current.sensitivity, TunerSensitivity.high);
    expect(current.noiseGate, 0.02);
    expect(current.tuningPreset, TuningPreset.guitarStandard);
  });

  test('normalizers clamp and snap values safely', () {
    expect(normalizeA4Reference(431.2), 432.0);
    expect(normalizeA4Reference(439.9), 440.0);
    expect(normalizeNoiseGate(-1), minNoiseGate);
    expect(normalizeNoiseGate(1), maxNoiseGate);
  });

  test('preset provides expected allowed note names', () {
    expect(allowedNoteNamesFromPreset(TuningPreset.chromatic), isNull);
    expect(
      allowedNoteNamesFromPreset(TuningPreset.guitarStandard),
      {'E', 'A', 'D', 'G', 'B'},
    );
    expect(
      allowedNoteNamesFromPreset(TuningPreset.ukuleleStandard),
      {'G', 'C', 'E', 'A'},
    );
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
}
