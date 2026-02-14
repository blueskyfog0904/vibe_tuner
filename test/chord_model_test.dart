import 'package:flutter_test/flutter_test.dart';
import 'package:vibetuner/features/chord_library/data/models/chord_model.dart';
import 'package:vibetuner/features/chord_library/domain/entities/chord_entity.dart';

void main() {
  test('parses legacy chord json with safe defaults', () {
    final chord = ChordModel.fromJson({
      'instrument': 'guitar',
      'root': 'C',
      'quality': 'Major',
      'positions': [
        {'string': 6, 'fret': -1, 'finger': 0},
        {'string': 5, 'fret': 3, 'finger': 3},
      ],
    });

    expect(chord.instrument, InstrumentType.guitar);
    expect(chord.capo, 0);
    expect(chord.barre, isNull);
    expect(chord.tuning, ['E2', 'A2', 'D3', 'G3', 'B3', 'E4']);
    expect(chord.positions.length, 2);
  });

  test('parses extended chord json with tuning capo and barre', () {
    final chord = ChordModel.fromJson({
      'instrument': 'guitar',
      'root': 'F',
      'quality': 'Major',
      'tuning': ['D2', 'G2', 'C3', 'F3', 'A3', 'D4'],
      'capo': 1,
      'barre': {
        'fret': 1,
        'startString': 6,
        'endString': 1,
      },
      'positions': [
        {'string': 6, 'fret': 1, 'finger': 1},
        {'string': 5, 'fret': 3, 'finger': 3},
      ],
    });

    expect(chord.instrument, InstrumentType.guitar);
    expect(chord.capo, 1);
    expect(chord.tuning, ['D2', 'G2', 'C3', 'F3', 'A3', 'D4']);
    expect(chord.barre, isNotNull);
    expect(chord.barre!.fret, 1);
    expect(chord.barre!.startString, 6);
    expect(chord.barre!.endString, 1);
  });
}
