class MetronomeState {
  final bool isRunning;
  final int bpm;
  final int beatsPerMeasure;
  final int currentBeat;

  const MetronomeState({
    required this.isRunning,
    required this.bpm,
    required this.beatsPerMeasure,
    required this.currentBeat,
  });

  const MetronomeState.initial()
      : isRunning = false,
        bpm = 100,
        beatsPerMeasure = 4,
        currentBeat = 0;

  MetronomeState copyWith({
    bool? isRunning,
    int? bpm,
    int? beatsPerMeasure,
    int? currentBeat,
  }) {
    return MetronomeState(
      isRunning: isRunning ?? this.isRunning,
      bpm: bpm ?? this.bpm,
      beatsPerMeasure: beatsPerMeasure ?? this.beatsPerMeasure,
      currentBeat: currentBeat ?? this.currentBeat,
    );
  }
}
