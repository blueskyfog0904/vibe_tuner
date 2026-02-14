import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibetuner/features/chord_library/domain/entities/chord_entity.dart';
import 'package:vibetuner/features/chord_library/presentation/providers/chord_library_provider.dart';

void main() {
  test('chordStorageKey is deterministic for same chord shape', () {
    const chord = ChordEntity(
      instrument: InstrumentType.guitar,
      root: 'C',
      quality: 'Major',
      positions: [],
      tuning: ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'],
      capo: 1,
    );

    final a = chordStorageKey(chord);
    final b = chordStorageKey(chord);
    expect(a, b);
  });

  test('sortChordsByRecent moves recently viewed chords to front', () {
    const cMajor = ChordEntity(
      instrument: InstrumentType.guitar,
      root: 'C',
      quality: 'Major',
      positions: [],
      tuning: ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'],
    );
    const gMajor = ChordEntity(
      instrument: InstrumentType.guitar,
      root: 'G',
      quality: 'Major',
      positions: [],
      tuning: ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'],
    );

    final sorted = sortChordsByRecent(
      [cMajor, gMajor],
      [chordStorageKey(gMajor)],
    );
    expect(sorted.first.root, 'G');
  });

  test('meta notifier persists favorites and recents', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(chordLibraryMetaProvider.future);
    final notifier = container.read(chordLibraryMetaProvider.notifier);

    await notifier.toggleFavorite('guitar|C|Major|capo:0');
    await notifier.markViewed('guitar|C|Major|capo:0');
    await notifier.markViewed('guitar|G|Major|capo:0');

    final state = container.read(chordLibraryMetaProvider).valueOrNull;
    expect(state, isNotNull);
    expect(state!.favoriteChordKeys.contains('guitar|C|Major|capo:0'), isTrue);
    expect(state.recentChordKeys.first, 'guitar|G|Major|capo:0');

    final prefs = await SharedPreferences.getInstance();
    final savedFavorites = prefs.getStringList('chord_library_favorites_v1') ?? [];
    final savedRecent = prefs.getStringList('chord_library_recent_v1') ?? [];
    expect(savedFavorites.contains('guitar|C|Major|capo:0'), isTrue);
    expect(savedRecent.first, 'guitar|G|Major|capo:0');
  });
}
