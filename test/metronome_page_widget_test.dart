import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibetuner/features/metronome/presentation/pages/metronome_page.dart';

void main() {
  testWidgets('metronome page renders controls', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MetronomePage(),
        ),
      ),
    );

    expect(find.text('Metronome'), findsOneWidget);
    expect(find.text('100 BPM'), findsOneWidget);
    expect(find.text('Tap Tempo'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('start button toggles to stop', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MetronomePage(),
        ),
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pump();

    expect(find.text('Stop'), findsOneWidget);
  });
}
