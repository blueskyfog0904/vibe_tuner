import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/metronome_state.dart';
import '../../domain/logic/metronome_engine.dart';
import '../providers/metronome_provider.dart';

class MetronomePage extends ConsumerStatefulWidget {
  const MetronomePage({super.key});

  @override
  ConsumerState<MetronomePage> createState() => _MetronomePageState();
}

class _MetronomePageState extends ConsumerState<MetronomePage> {
  final Queue<DateTime> _tapTimes = Queue<DateTime>();

  void _onTapTempo() {
    final now = DateTime.now();
    _tapTimes.addLast(now);
    while (_tapTimes.length > 6) {
      _tapTimes.removeFirst();
    }
    if (_tapTimes.length < 2) return;

    final intervals = <Duration>[];
    for (var i = 1; i < _tapTimes.length; i++) {
      intervals.add(_tapTimes.elementAt(i).difference(_tapTimes.elementAt(i - 1)));
    }
    final bpm = MetronomeEngine.bpmFromTapIntervals(intervals);
    ref.read(metronomeProvider.notifier).setBpm(bpm);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(metronomeProvider);
    final notifier = ref.read(metronomeProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Metronome')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              '${state.bpm} BPM',
              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
            ),
            Slider(
              value: state.bpm.toDouble(),
              min: MetronomeEngine.minBpm.toDouble(),
              max: MetronomeEngine.maxBpm.toDouble(),
              divisions: MetronomeEngine.maxBpm - MetronomeEngine.minBpm,
              label: '${state.bpm}',
              onChanged: (value) {
                notifier.setBpm(value.round());
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Beats/Measure:'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: state.beatsPerMeasure,
                  items: const [2, 3, 4, 5, 6, 7, 8]
                      .map(
                        (beats) => DropdownMenuItem(
                          value: beats,
                          child: Text('$beats/4'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) notifier.setBeatsPerMeasure(value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            BeatIndicatorRow(state: state),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _onTapTempo,
                    child: const Text('Tap Tempo'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (state.isRunning) {
                        notifier.stop();
                      } else {
                        notifier.start();
                      }
                    },
                    child: Text(state.isRunning ? 'Stop' : 'Start'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Tip: Tap 4~6 times for stable tempo detection.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class BeatIndicatorRow extends StatelessWidget {
  final MetronomeState state;

  const BeatIndicatorRow({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(state.beatsPerMeasure, (index) {
        final beat = index + 1;
        final isActive = state.isRunning && state.currentBeat == beat;
        final isAccent = beat == 1;
        final color = isActive
            ? (isAccent ? Colors.redAccent : Colors.lightBlueAccent)
            : Colors.grey.shade300;
        return Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black12),
          ),
        );
      }),
    );
  }
}
