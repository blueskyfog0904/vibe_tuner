import 'dart:math';
import '../../features/tuner_engine/domain/entities/tuning_result.dart';

class NoteCalculator {
  static const List<String> _noteNames = [
    "C",
    "C#",
    "D",
    "D#",
    "E",
    "F",
    "F#",
    "G",
    "G#",
    "A",
    "A#",
    "B",
  ];
  static const Map<String, int> _noteIndexMap = {
    'C': 0,
    'C#': 1,
    'D': 2,
    'D#': 3,
    'E': 4,
    'F': 5,
    'F#': 6,
    'G': 7,
    'G#': 8,
    'A': 9,
    'A#': 10,
    'B': 11,
  };

  final double a4Reference;
  final double perfectCentsThreshold;

  const NoteCalculator({
    this.a4Reference = 440.0,
    this.perfectCentsThreshold = 5.0,
  });

  /// Calculates the TuningResult for a given frequency.
  /// Returns TuningResult.noSignal() if frequency is below reasonable threshold (e.g. 20Hz).
  TuningResult calculate(
    double frequency, {
    Set<String>? allowedNoteNames,
    Set<int>? allowedMidiNumbers,
  }) {
    if (frequency < 20.0) {
      return TuningResult.noSignal();
    }

    final int roundedMidi = _closestMidiForFrequency(
      frequency,
      allowedNoteNames: allowedNoteNames,
      allowedMidiNumbers: allowedMidiNumbers,
    );

    // 2. Determine Note Name & Octave
    final int noteIndex = roundedMidi % 12;
    final int octave = (roundedMidi / 12).floor() - 1;
    final String noteName = _noteNames[noteIndex];

    // 3. Calculate Target Frequency for the closest note
    final double targetFrequency =
        a4Reference * pow(2, (roundedMidi - 69) / 12);

    // 4. Calculate Cents
    // cents = 1200 * log2(f / target_f)
    final double cents = 1200 * (log(frequency / targetFrequency) / log(2));

    // 5. Determine Status
    TuningStatus status;
    if (cents.abs() <= perfectCentsThreshold) {
      status = TuningStatus.perfect;
    } else if (cents > perfectCentsThreshold) {
      status = TuningStatus.tooHigh;
    } else {
      status = TuningStatus.tooLow;
    }

    return TuningResult(
      frequency: frequency,
      noteName: noteName,
      octave: octave,
      cents: cents,
      targetFrequency: targetFrequency,
      status: status,
    );
  }

  int _closestMidiForFrequency(
    double frequency, {
    Set<String>? allowedNoteNames,
    Set<int>? allowedMidiNumbers,
  }) {
    final midiNumber = 69 + 12 * (log(frequency / a4Reference) / log(2));
    final defaultRounded = midiNumber.round();
    final normalizedAllowedMidi = allowedMidiNumbers
        ?.where((midi) => midi >= 0 && midi <= 127)
        .toSet();
    if (normalizedAllowedMidi != null && normalizedAllowedMidi.isNotEmpty) {
      var bestMidi = defaultRounded;
      var bestDistance = double.infinity;
      for (final midi in normalizedAllowedMidi) {
        final freq = a4Reference * pow(2, (midi - 69) / 12);
        final distance = (freq - frequency).abs();
        if (distance < bestDistance) {
          bestDistance = distance;
          bestMidi = midi;
        }
      }
      return bestMidi;
    }

    final normalizedAllowed = allowedNoteNames
        ?.map((e) => e.toUpperCase())
        .where(_noteIndexMap.containsKey)
        .toSet();
    if (normalizedAllowed == null || normalizedAllowed.isEmpty) {
      return defaultRounded;
    }

    var bestMidi = defaultRounded;
    var bestDistance = double.infinity;
    for (var midi = 24; midi <= 96; midi++) {
      final noteName = _noteNames[midi % 12].toUpperCase();
      if (!normalizedAllowed.contains(noteName)) continue;
      final freq = a4Reference * pow(2, (midi - 69) / 12);
      final distance = (freq - frequency).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestMidi = midi;
      }
    }
    return bestMidi;
  }
}
