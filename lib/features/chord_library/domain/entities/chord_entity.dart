import 'package:equatable/equatable.dart';

enum InstrumentType { guitar, ukulele }

class ChordEntity extends Equatable {
  final InstrumentType instrument;
  final String root;
  final String quality;
  final List<ChordPosition> positions;
  final List<String> tuning;
  final int capo;
  final BarreInfo? barre;

  const ChordEntity({
    required this.instrument,
    required this.root,
    required this.quality,
    required this.positions,
    required this.tuning,
    this.capo = 0,
    this.barre,
  });

  @override
  List<Object?> get props => [
        instrument,
        root,
        quality,
        positions,
        tuning,
        capo,
        barre,
      ];
}

class ChordPosition extends Equatable {
  final int string; // 1-based index (e.g., 6 for low E on guitar)
  final int fret;   // -1 for mute, 0 for open
  final int finger; // 0 for open, 1-4 for fingers

  const ChordPosition({
    required this.string,
    required this.fret,
    required this.finger,
  });

  @override
  List<Object?> get props => [string, fret, finger];
}

class BarreInfo extends Equatable {
  final int fret;
  final int startString;
  final int endString;

  const BarreInfo({
    required this.fret,
    required this.startString,
    required this.endString,
  });

  @override
  List<Object?> get props => [fret, startString, endString];
}
