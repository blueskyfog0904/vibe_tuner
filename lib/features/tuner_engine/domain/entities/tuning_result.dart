enum TuningStatus {
  noSignal,
  tooLow,
  perfect,  // Within +/- 5 cents
  tooHigh,
}

class TuningResult {
  final double frequency;
  final String noteName;
  final int octave;
  final double cents;
  final double targetFrequency;
  final TuningStatus status;

  const TuningResult({
    required this.frequency,
    required this.noteName,
    required this.octave,
    required this.cents,
    required this.targetFrequency,
    required this.status,
  });

  factory TuningResult.noSignal() {
    return const TuningResult(
      frequency: -1,
      noteName: '-',
      octave: 0,
      cents: 0,
      targetFrequency: 0,
      status: TuningStatus.noSignal,
    );
  }
}
