import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibetuner/features/tuner_engine/domain/entities/tuning_result.dart';
import 'package:vibetuner/features/tuner_engine/presentation/pages/tuner_page.dart';

void main() {
  testWidgets('readout shows in-tune status and stable badge', (tester) async {
    const result = TuningResult(
      frequency: 440.0,
      noteName: 'A',
      octave: 4,
      cents: 0.8,
      targetFrequency: 440.0,
      status: TuningStatus.perfect,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TunerReadout(
            result: result,
            stability: TunerStability.stable,
            tuningPresetLabel: 'Preset: Chromatic',
          ),
        ),
      ),
    );

    expect(find.text('A4'), findsOneWidget);
    expect(find.text('In Tune'), findsOneWidget);
    expect(find.text('STABLE'), findsOneWidget);
  });

  testWidgets('readout shows too-high status and cents sign', (tester) async {
    const result = TuningResult(
      frequency: 447.2,
      noteName: 'A',
      octave: 4,
      cents: 28.4,
      targetFrequency: 440.0,
      status: TuningStatus.tooHigh,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TunerReadout(
            result: result,
            stability: TunerStability.unstable,
            tuningPresetLabel: 'Preset: Chromatic',
          ),
        ),
      ),
    );

    expect(find.text('Too High'), findsOneWidget);
    expect(find.text('+28.4'), findsOneWidget);
    expect(find.text('UNSTABLE'), findsOneWidget);
  });

  test('assessStability classifies history by variance', () {
    expect(assessStability([0.1, 0.0, -0.2, 0.2]), TunerStability.stable);
    expect(assessStability([1.0, -3.0, 4.0, -1.0, 2.0]), TunerStability.settling);
    expect(assessStability([12, -10, 8, -14, 11]), TunerStability.unstable);
    expect(assessStability([0.0, 0.1]), TunerStability.unknown);
  });
}
