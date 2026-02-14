import 'package:flutter_test/flutter_test.dart';
import 'package:vibetuner/features/chord_library/domain/entities/chord_entity.dart';
import 'package:vibetuner/features/chord_library/presentation/providers/chord_library_provider.dart';

void main() {
  const chords = [
    ChordEntity(
      instrument: InstrumentType.guitar,
      root: 'C',
      quality: 'Major',
      positions: [],
      tuning: ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'],
    ),
    ChordEntity(
      instrument: InstrumentType.ukulele,
      root: 'Am',
      quality: 'Minor',
      positions: [],
      tuning: ['G4', 'C4', 'E4', 'A4'],
    ),
  ];

  test('returns all chords on empty query', () {
    final result = applyChordSearchQuery(chords, '');
    expect(result.length, 2);
  });

  test('matches root and quality case-insensitively', () {
    expect(applyChordSearchQuery(chords, 'c').length, 1);
    expect(applyChordSearchQuery(chords, 'minor').length, 1);
    expect(applyChordSearchQuery(chords, 'MAJOR').length, 1);
  });

  test('matches instrument text', () {
    final result = applyChordSearchQuery(chords, 'uku');
    expect(result.length, 1);
    expect(result.first.instrument, InstrumentType.ukulele);
  });
}
