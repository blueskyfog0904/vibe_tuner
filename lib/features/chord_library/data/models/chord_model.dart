import '../../domain/entities/chord_entity.dart';

class ChordModel extends ChordEntity {
  const ChordModel({
    required super.instrument,
    required super.root,
    required super.quality,
    required super.positions,
    required super.tuning,
    super.capo,
    super.barre,
  });

  factory ChordModel.fromJson(Map<String, dynamic> json) {
    final instrument = _parseInstrument(json['instrument'] as String);
    return ChordModel(
      instrument: instrument,
      root: json['root'] as String,
      quality: json['quality'] as String,
      positions: (json['positions'] as List)
          .map((e) => ChordPositionModel.fromJson(e))
          .toList(),
      tuning: _parseTuning(json['tuning'], instrument),
      capo: (json['capo'] as num?)?.toInt() ?? 0,
      barre: json['barre'] == null
          ? null
          : BarreInfoModel.fromJson(json['barre'] as Map<String, dynamic>),
    );
  }

  static InstrumentType _parseInstrument(String value) {
    switch (value.toLowerCase()) {
      case 'ukulele':
        return InstrumentType.ukulele;
      default:
        return InstrumentType.guitar;
    }
  }

  static List<String> _parseTuning(dynamic value, InstrumentType instrument) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return _defaultTuning(instrument);
  }

  static List<String> _defaultTuning(InstrumentType instrument) {
    switch (instrument) {
      case InstrumentType.ukulele:
        return const ['G4', 'C4', 'E4', 'A4'];
      case InstrumentType.guitar:
        return const ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'];
    }
  }
}

class ChordPositionModel extends ChordPosition {
  const ChordPositionModel({
    required super.string,
    required super.fret,
    required super.finger,
  });

  factory ChordPositionModel.fromJson(Map<String, dynamic> json) {
    return ChordPositionModel(
      string: (json['string'] as num).toInt(),
      fret: (json['fret'] as num).toInt(),
      finger: (json['finger'] as num).toInt(),
    );
  }
}

class BarreInfoModel extends BarreInfo {
  const BarreInfoModel({
    required super.fret,
    required super.startString,
    required super.endString,
  });

  factory BarreInfoModel.fromJson(Map<String, dynamic> json) {
    return BarreInfoModel(
      fret: (json['fret'] as num).toInt(),
      startString: (json['startString'] as num).toInt(),
      endString: (json['endString'] as num).toInt(),
    );
  }
}
