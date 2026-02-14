import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/chord_repository_impl.dart';
import '../../domain/entities/chord_entity.dart';

class ChordSearchFilterState {
  final InstrumentType instrument;
  final String query;
  final String? root;
  final String? quality;

  const ChordSearchFilterState({
    this.instrument = InstrumentType.guitar,
    this.query = '',
    this.root,
    this.quality,
  });

  ChordSearchFilterState copyWith({
    InstrumentType? instrument,
    String? query,
    String? root,
    String? quality,
    bool clearRoot = false,
    bool clearQuality = false,
  }) {
    return ChordSearchFilterState(
      instrument: instrument ?? this.instrument,
      query: query ?? this.query,
      root: clearRoot ? null : (root ?? this.root),
      quality: clearQuality ? null : (quality ?? this.quality),
    );
  }
}

class ChordLibraryMetaState {
  final Set<String> favoriteChordKeys;
  final List<String> recentChordKeys;

  const ChordLibraryMetaState({
    this.favoriteChordKeys = const <String>{},
    this.recentChordKeys = const <String>[],
  });

  ChordLibraryMetaState copyWith({
    Set<String>? favoriteChordKeys,
    List<String>? recentChordKeys,
  }) {
    return ChordLibraryMetaState(
      favoriteChordKeys: favoriteChordKeys ?? this.favoriteChordKeys,
      recentChordKeys: recentChordKeys ?? this.recentChordKeys,
    );
  }
}

final chordRepositoryProvider = Provider<ChordRepositoryImpl>((ref) {
  return ChordRepositoryImpl();
});

final chordLibraryMetaProvider =
    AsyncNotifierProvider<ChordLibraryMetaNotifier, ChordLibraryMetaState>(
  ChordLibraryMetaNotifier.new,
);

final chordSearchFilterProvider =
    StateProvider<ChordSearchFilterState>((ref) => const ChordSearchFilterState());

final debouncedChordQueryProvider = FutureProvider<String>((ref) async {
  final query = ref.watch(chordSearchFilterProvider.select((s) => s.query));
  await Future<void>.delayed(const Duration(milliseconds: 300));
  return query.trim().toLowerCase();
});

final chordListProvider = FutureProvider<List<ChordEntity>>((ref) async {
  final repository = ref.read(chordRepositoryProvider);
  final filter = ref.watch(chordSearchFilterProvider);
  final debouncedQuery = await ref.watch(debouncedChordQueryProvider.future);

  await repository.initialize();

  final base = repository.getChords(
    instrument: filter.instrument,
    root: filter.root,
    quality: filter.quality,
  );

  return applyChordSearchQuery(base, debouncedQuery);
});

final chordFilterOptionsProvider =
    FutureProvider<({List<String> roots, List<String> qualities})>((ref) async {
  final repository = ref.read(chordRepositoryProvider);
  final instrument = ref.watch(chordSearchFilterProvider.select((s) => s.instrument));
  await repository.initialize();
  final chords = repository.getChords(instrument: instrument);

  final roots = chords.map((e) => e.root).toSet().toList()..sort();
  final qualities = chords.map((e) => e.quality).toSet().toList()..sort();
  return (roots: roots, qualities: qualities);
});

List<ChordEntity> applyChordSearchQuery(List<ChordEntity> chords, String query) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return chords;
  return chords.where((chord) {
    final root = chord.root.toLowerCase();
    final quality = chord.quality.toLowerCase();
    final instrument = chord.instrument.name.toLowerCase();
    return root.contains(normalizedQuery) ||
        quality.contains(normalizedQuery) ||
        instrument.contains(normalizedQuery);
  }).toList();
}

class ChordLibraryMetaNotifier extends AsyncNotifier<ChordLibraryMetaState> {
  static const String _favoritesKey = 'chord_library_favorites_v1';
  static const String _recentKey = 'chord_library_recent_v1';
  static const int _recentLimit = 30;

  SharedPreferences? _prefs;

  @override
  Future<ChordLibraryMetaState> build() async {
    _prefs = await SharedPreferences.getInstance();
    final favorites = _prefs!.getStringList(_favoritesKey) ?? const <String>[];
    final recent = _prefs!.getStringList(_recentKey) ?? const <String>[];
    return ChordLibraryMetaState(
      favoriteChordKeys: favorites.toSet(),
      recentChordKeys: recent,
    );
  }

  Future<void> toggleFavorite(String chordKey) async {
    final current = state.valueOrNull ?? const ChordLibraryMetaState();
    final updatedFavorites = current.favoriteChordKeys.toSet();
    if (updatedFavorites.contains(chordKey)) {
      updatedFavorites.remove(chordKey);
    } else {
      updatedFavorites.add(chordKey);
    }
    final next = current.copyWith(favoriteChordKeys: updatedFavorites);
    state = AsyncData(next);
    await _prefs?.setStringList(_favoritesKey, updatedFavorites.toList());
  }

  Future<void> markViewed(String chordKey) async {
    final current = state.valueOrNull ?? const ChordLibraryMetaState();
    final updatedRecent = <String>[
      chordKey,
      ...current.recentChordKeys.where((e) => e != chordKey),
    ];
    if (updatedRecent.length > _recentLimit) {
      updatedRecent.removeRange(_recentLimit, updatedRecent.length);
    }
    final next = current.copyWith(recentChordKeys: updatedRecent);
    state = AsyncData(next);
    await _prefs?.setStringList(_recentKey, updatedRecent);
  }
}

String chordStorageKey(ChordEntity chord) {
  return [
    chord.instrument.name,
    chord.root,
    chord.quality,
    'capo:${chord.capo}',
  ].join('|');
}

List<ChordEntity> sortChordsByRecent(
  List<ChordEntity> chords,
  List<String> recentChordKeys,
) {
  if (recentChordKeys.isEmpty) return chords;
  final indexMap = <String, int>{};
  for (var i = 0; i < recentChordKeys.length; i++) {
    indexMap[recentChordKeys[i]] = i;
  }
  final sorted = [...chords];
  sorted.sort((a, b) {
    final aIdx = indexMap[chordStorageKey(a)];
    final bIdx = indexMap[chordStorageKey(b)];
    if (aIdx == null && bIdx == null) return 0;
    if (aIdx == null) return 1;
    if (bIdx == null) return -1;
    return aIdx.compareTo(bIdx);
  });
  return sorted;
}
