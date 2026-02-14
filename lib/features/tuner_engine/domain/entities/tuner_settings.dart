enum TunerSensitivity { low, medium, high }

enum TuningPreset { chromatic, guitarStandard, ukuleleStandard }

class TunerSettings {
  final double a4Reference;
  final TunerSensitivity sensitivity;
  final double noiseGate;
  final TuningPreset tuningPreset;

  const TunerSettings({
    required this.a4Reference,
    required this.sensitivity,
    required this.noiseGate,
    required this.tuningPreset,
  });

  const TunerSettings.defaults()
      : a4Reference = 440.0,
        sensitivity = TunerSensitivity.medium,
        noiseGate = 0.01,
        tuningPreset = TuningPreset.chromatic;

  TunerSettings copyWith({
    double? a4Reference,
    TunerSensitivity? sensitivity,
    double? noiseGate,
    TuningPreset? tuningPreset,
  }) {
    return TunerSettings(
      a4Reference: a4Reference ?? this.a4Reference,
      sensitivity: sensitivity ?? this.sensitivity,
      noiseGate: noiseGate ?? this.noiseGate,
      tuningPreset: tuningPreset ?? this.tuningPreset,
    );
  }

  Map<String, Object> toMap() {
    return {
      'a4Reference': a4Reference,
      'sensitivity': sensitivity.name,
      'noiseGate': noiseGate,
      'tuningPreset': tuningPreset.name,
    };
  }

  factory TunerSettings.fromMap(Map<String, Object?> map) {
    return TunerSettings(
      a4Reference: (map['a4Reference'] as num?)?.toDouble() ?? 440.0,
      sensitivity: TunerSensitivity.values.firstWhere(
        (e) => e.name == map['sensitivity'],
        orElse: () => TunerSensitivity.medium,
      ),
      noiseGate: (map['noiseGate'] as num?)?.toDouble() ?? 0.01,
      tuningPreset: TuningPreset.values.firstWhere(
        (e) => e.name == map['tuningPreset'],
        orElse: () => TuningPreset.chromatic,
      ),
    );
  }
}
