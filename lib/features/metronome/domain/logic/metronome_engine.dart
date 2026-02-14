import 'dart:async';

import 'package:flutter/widgets.dart';

import '../entities/metronome_state.dart';

typedef MetronomeTickCallback = void Function(int beat, bool isAccent);

class MetronomeEngine {
  static const int minBpm = 30;
  static const int maxBpm = 240;
  static const int minBeatsPerMeasure = 2;
  static const int maxBeatsPerMeasure = 12;

  final MetronomeTickCallback? onTick;
  final void Function(MetronomeState state)? onStateChanged;

  MetronomeState _state = const MetronomeState.initial();
  Timer? _timer;
  bool _resumeOnForeground = false;

  MetronomeEngine({
    this.onTick,
    this.onStateChanged,
  });

  MetronomeState get state => _state;

  static int millisecondsPerBeat(int bpm) {
    final safeBpm = bpm.clamp(minBpm, maxBpm);
    return (60000 / safeBpm).round();
  }

  static int clampBpm(int bpm) => bpm.clamp(minBpm, maxBpm);

  static int clampBeatsPerMeasure(int beats) =>
      beats.clamp(minBeatsPerMeasure, maxBeatsPerMeasure);

  static int bpmFromTapIntervals(List<Duration> intervals) {
    if (intervals.isEmpty) return const MetronomeState.initial().bpm;
    final totalMs = intervals
        .map((e) => e.inMilliseconds)
        .where((ms) => ms > 0)
        .fold<int>(0, (sum, ms) => sum + ms);
    final count = intervals.where((e) => e.inMilliseconds > 0).length;
    if (count == 0) return const MetronomeState.initial().bpm;
    final avgMs = totalMs / count;
    final bpm = (60000 / avgMs).round();
    return clampBpm(bpm);
  }

  void setBpm(int bpm) {
    final next = clampBpm(bpm);
    if (_state.bpm == next) return;
    _state = _state.copyWith(bpm: next);
    _emitState();
    if (_state.isRunning) {
      _restartTicker();
    }
  }

  void setBeatsPerMeasure(int beats) {
    final next = clampBeatsPerMeasure(beats);
    if (_state.beatsPerMeasure == next) return;
    final adjustedBeat = _state.currentBeat > next ? 1 : _state.currentBeat;
    _state = _state.copyWith(
      beatsPerMeasure: next,
      currentBeat: adjustedBeat,
    );
    _emitState();
  }

  void start() {
    if (_state.isRunning) return;
    _state = _state.copyWith(isRunning: true, currentBeat: 1);
    _emitState();
    _emitTick();
    _restartTicker();
  }

  void stop({bool resetBeat = true}) {
    _timer?.cancel();
    _timer = null;
    _state = _state.copyWith(
      isRunning: false,
      currentBeat: resetBeat ? 0 : _state.currentBeat,
    );
    _emitState();
  }

  void handleLifecycle(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) {
      if (_resumeOnForeground) {
        _resumeOnForeground = false;
        start();
      }
      return;
    }

    final shouldPause = appState == AppLifecycleState.inactive ||
        appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.detached ||
        appState == AppLifecycleState.hidden;

    if (shouldPause && _state.isRunning) {
      _resumeOnForeground = true;
      stop(resetBeat: false);
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  void debugTick() {
    if (!_state.isRunning) return;
    _advanceBeat();
    _emitTick();
    _emitState();
  }

  void _restartTicker() {
    _timer?.cancel();
    final interval = Duration(milliseconds: millisecondsPerBeat(_state.bpm));
    _timer = Timer.periodic(interval, (_) {
      _advanceBeat();
      _emitTick();
      _emitState();
    });
  }

  void _advanceBeat() {
    final next = (_state.currentBeat % _state.beatsPerMeasure) + 1;
    _state = _state.copyWith(currentBeat: next);
  }

  void _emitTick() {
    onTick?.call(_state.currentBeat, _state.currentBeat == 1);
  }

  void _emitState() {
    onStateChanged?.call(_state);
  }
}
