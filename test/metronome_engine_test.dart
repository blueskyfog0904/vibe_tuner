import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibetuner/features/metronome/domain/logic/metronome_engine.dart';

void main() {
  test('millisecondsPerBeat uses clamped BPM values', () {
    expect(MetronomeEngine.millisecondsPerBeat(120), 500);
    expect(MetronomeEngine.millisecondsPerBeat(30), 2000);
    expect(
      MetronomeEngine.millisecondsPerBeat(10),
      MetronomeEngine.millisecondsPerBeat(MetronomeEngine.minBpm),
    );
    expect(
      MetronomeEngine.millisecondsPerBeat(400),
      MetronomeEngine.millisecondsPerBeat(MetronomeEngine.maxBpm),
    );
  });

  test('bpmFromTapIntervals estimates tempo and clamps', () {
    final bpm120 = MetronomeEngine.bpmFromTapIntervals(
      const [
        Duration(milliseconds: 500),
        Duration(milliseconds: 500),
        Duration(milliseconds: 500),
      ],
    );
    expect(bpm120, 120);

    final tooFast = MetronomeEngine.bpmFromTapIntervals(
      const [Duration(milliseconds: 50)],
    );
    expect(tooFast, MetronomeEngine.maxBpm);
  });

  test('clamps BPM and beats-per-measure into valid range', () {
    final engine = MetronomeEngine();
    addTearDown(engine.dispose);

    engine.setBpm(10);
    expect(engine.state.bpm, MetronomeEngine.minBpm);
    engine.setBpm(300);
    expect(engine.state.bpm, MetronomeEngine.maxBpm);

    engine.setBeatsPerMeasure(1);
    expect(engine.state.beatsPerMeasure, MetronomeEngine.minBeatsPerMeasure);
    engine.setBeatsPerMeasure(24);
    expect(engine.state.beatsPerMeasure, MetronomeEngine.maxBeatsPerMeasure);
  });

  test('cycles beats in measure while running', () {
    final ticks = <int>[];
    final engine = MetronomeEngine(
      onTick: (beat, _) => ticks.add(beat),
    );
    addTearDown(engine.dispose);

    engine.setBeatsPerMeasure(4);
    engine.start();

    expect(engine.state.isRunning, isTrue);
    expect(engine.state.currentBeat, 1);

    engine.debugTick();
    expect(engine.state.currentBeat, 2);
    engine.debugTick();
    expect(engine.state.currentBeat, 3);
    engine.debugTick();
    expect(engine.state.currentBeat, 4);
    engine.debugTick();
    expect(engine.state.currentBeat, 1);

    expect(ticks.first, 1);
  });

  test('pauses on background and resumes on foreground', () {
    final engine = MetronomeEngine();
    addTearDown(engine.dispose);

    engine.start();
    expect(engine.state.isRunning, isTrue);

    engine.handleLifecycle(AppLifecycleState.paused);
    expect(engine.state.isRunning, isFalse);

    engine.handleLifecycle(AppLifecycleState.resumed);
    expect(engine.state.isRunning, isTrue);
  });
}
