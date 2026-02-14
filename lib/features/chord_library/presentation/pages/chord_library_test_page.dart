import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/chord_entity.dart';
import '../providers/chord_library_provider.dart';
import '../painters/fretboard_painter.dart';

class ChordLibraryTestPage extends ConsumerWidget {
  const ChordLibraryTestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(chordSearchFilterProvider);
    final chordListAsync = ref.watch(chordListProvider);
    final filterOptionsAsync = ref.watch(chordFilterOptionsProvider);
    final metaState = ref.watch(chordLibraryMetaProvider).valueOrNull ??
        const ChordLibraryMetaState();

    return Scaffold(
      appBar: AppBar(title: const Text("Phase 3: Chord Data Test")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) {
                    ref.read(chordSearchFilterProvider.notifier).state =
                        filter.copyWith(query: value);
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search root, quality, instrument',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                filterOptionsAsync.when(
                  data: (options) {
                    return Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<InstrumentType>(
                            initialValue: filter.instrument,
                            decoration: const InputDecoration(
                              labelText: 'Instrument',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: InstrumentType.guitar,
                                child: Text('Guitar'),
                              ),
                              DropdownMenuItem(
                                value: InstrumentType.ukulele,
                                child: Text('Ukulele'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              ref.read(chordSearchFilterProvider.notifier).state =
                                  filter.copyWith(
                                instrument: value,
                                clearRoot: true,
                                clearQuality: true,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: filter.root,
                            decoration: const InputDecoration(
                              labelText: 'Root',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All'),
                              ),
                              ...options.roots.map(
                                (root) => DropdownMenuItem<String?>(
                                  value: root,
                                  child: Text(root),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              ref.read(chordSearchFilterProvider.notifier).state =
                                  filter.copyWith(root: value, clearRoot: value == null);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: filter.quality,
                            decoration: const InputDecoration(
                              labelText: 'Quality',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All'),
                              ),
                              ...options.qualities.map(
                                (quality) => DropdownMenuItem<String?>(
                                  value: quality,
                                  child: Text(quality),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              ref.read(chordSearchFilterProvider.notifier).state =
                                  filter.copyWith(quality: value, clearQuality: value == null);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Expanded(
            child: chordListAsync.when(
              data: (chords) {
                final ordered = sortChordsByRecent(chords, metaState.recentChordKeys);
                if (ordered.isEmpty) {
                  return const Center(
                    child: Text('No chords found. Try broadening your filters.'),
                  );
                }
                return ListView.builder(
                  itemCount: ordered.length,
                  itemBuilder: (context, index) {
                    final chord = ordered[index];
                    final storageKey = chordStorageKey(chord);
                    final isFavorite = metaState.favoriteChordKeys.contains(storageKey);
                    final recentIndex = metaState.recentChordKeys.indexOf(storageKey);
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      color: Colors.grey[900],
                      child: InkWell(
                        onTap: () {
                          ref.read(chordLibraryMetaProvider.notifier).markViewed(storageKey);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            "${chord.root} ${chord.quality}",
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: isFavorite
                                              ? 'Remove favorite'
                                              : 'Add favorite',
                                          onPressed: () {
                                            ref
                                                .read(chordLibraryMetaProvider.notifier)
                                                .toggleFavorite(storageKey);
                                          },
                                          icon: Icon(
                                            isFavorite ? Icons.star : Icons.star_border,
                                            color: isFavorite
                                                ? Colors.amberAccent
                                                : Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      chord.instrument.name.toUpperCase(),
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                    if (recentIndex >= 0) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        "Recent #${recentIndex + 1}",
                                        style: const TextStyle(
                                          color: Colors.tealAccent,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                    if (chord.capo > 0) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        "Capo ${chord.capo}",
                                        style:
                                            const TextStyle(color: Colors.lightBlueAccent),
                                      ),
                                    ],
                                    if (chord.barre != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        "Barre F${chord.barre!.fret} (${chord.barre!.startString}-${chord.barre!.endString})",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 120,
                                height: 160,
                                child: CustomPaint(
                                  painter: FretboardPainter(chord: chord),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              error: (err, _) => Center(child: Text("Error: $err")),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}
