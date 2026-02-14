import 'package:flutter_test/flutter_test.dart';
import 'package:vibetuner/features/chord_library/presentation/painters/fretboard_painter.dart';

void main() {
  group('displayFretForCapo', () {
    test('keeps mute and open semantics', () {
      expect(FretboardRenderUtils.displayFretForCapo(fret: -1, capo: 2), -1);
      expect(FretboardRenderUtils.displayFretForCapo(fret: 0, capo: 2), 0);
    });

    test('returns relative fret when capo exists', () {
      expect(FretboardRenderUtils.displayFretForCapo(fret: 3, capo: 0), 3);
      expect(FretboardRenderUtils.displayFretForCapo(fret: 3, capo: 2), 1);
      expect(FretboardRenderUtils.displayFretForCapo(fret: 2, capo: 2), 0);
      expect(FretboardRenderUtils.displayFretForCapo(fret: 1, capo: 2), 0);
    });
  });

  group('normalizeBarreRange', () {
    test('normalizes reversed string order', () {
      final range = FretboardRenderUtils.normalizeBarreRange(
        startString: 1,
        endString: 6,
        stringCount: 6,
      );
      expect(range, isNotNull);
      expect(range!.startString, 6);
      expect(range.endString, 1);
    });

    test('rejects out-of-range strings', () {
      final tooLow = FretboardRenderUtils.normalizeBarreRange(
        startString: 0,
        endString: 4,
        stringCount: 6,
      );
      final tooHigh = FretboardRenderUtils.normalizeBarreRange(
        startString: 1,
        endString: 7,
        stringCount: 6,
      );
      expect(tooLow, isNull);
      expect(tooHigh, isNull);
    });
  });
}
