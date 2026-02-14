enum TunerSensitivity { low, medium, high }

enum TuningPreset { chromatic, guitarStandard, ukuleleStandard }

class TunerSettings {
  final double a4Reference;
  final TunerSensitivity sensitivity;
  final double noiseGate;
  final TuningPreset tuningPreset;
  final bool lowLatencyMode;
  final Map<int, double> stringSensitivities;
  final Map<int, int> stringHoldMs;
  final Map<int, int> stringStabilityWindows;

  const TunerSettings({
    required this.a4Reference,
    required this.sensitivity,
    required this.noiseGate,
    required this.tuningPreset,
    this.lowLatencyMode = false,
    this.stringSensitivities = defaultStringSensitivities,
    this.stringHoldMs = defaultStringHoldMs,
    this.stringStabilityWindows = defaultStringStabilityWindows,
  });

  const TunerSettings.defaults()
    : a4Reference = 440.0,
      sensitivity = TunerSensitivity.medium,
      noiseGate = 0.005,
      tuningPreset = TuningPreset.chromatic,
      lowLatencyMode = false,
      stringSensitivities = defaultStringSensitivities,
      stringHoldMs = defaultStringHoldMs,
      stringStabilityWindows = defaultStringStabilityWindows;

  TunerSettings copyWith({
    double? a4Reference,
    TunerSensitivity? sensitivity,
    double? noiseGate,
    TuningPreset? tuningPreset,
    bool? lowLatencyMode,
    Map<int, double>? stringSensitivities,
    Map<int, int>? stringHoldMs,
    Map<int, int>? stringStabilityWindows,
  }) {
    return TunerSettings(
      a4Reference: a4Reference ?? this.a4Reference,
      sensitivity: sensitivity ?? this.sensitivity,
      noiseGate: noiseGate ?? this.noiseGate,
      tuningPreset: tuningPreset ?? this.tuningPreset,
      lowLatencyMode: lowLatencyMode ?? this.lowLatencyMode,
      stringSensitivities: stringSensitivities ?? this.stringSensitivities,
      stringHoldMs: stringHoldMs ?? this.stringHoldMs,
      stringStabilityWindows:
          stringStabilityWindows ?? this.stringStabilityWindows,
    );
  }

  double sensitivityForString(int stringNumber) {
    return stringSensitivities[stringNumber] ??
        defaultStringSensitivities[stringNumber] ??
        1.0;
  }

  int holdMsForString(int stringNumber) {
    return stringHoldMs[stringNumber] ??
        defaultStringHoldMs[stringNumber] ??
        300;
  }

  int stabilityWindowForString(int stringNumber) {
    return stringStabilityWindows[stringNumber] ??
        defaultStringStabilityWindows[stringNumber] ??
        4;
  }

  Map<String, Object> toMap() {
    return {
      'a4Reference': a4Reference,
      'sensitivity': sensitivity.name,
      'noiseGate': noiseGate,
      'tuningPreset': tuningPreset.name,
      'lowLatencyMode': lowLatencyMode,
      'stringSensitivities': stringSensitivities.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'stringHoldMs': stringHoldMs.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'stringStabilityWindows': stringStabilityWindows.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    };
  }

  factory TunerSettings.fromMap(Map<String, Object?> map) {
    final parsedSensitivities = <int, double>{};
    final parsedHoldMs = <int, int>{};
    final parsedStabilityWindows = <int, int>{};
    final rawSensitivities = map['stringSensitivities'];
    if (rawSensitivities is Map) {
      for (final entry in rawSensitivities.entries) {
        final parsedKey = int.tryParse(entry.key.toString());
        final rawValue = entry.value;
        if (parsedKey == null || rawValue is! num) continue;
        parsedSensitivities[parsedKey] = rawValue.toDouble();
      }
    }
    final rawHoldMs = map['stringHoldMs'];
    if (rawHoldMs is Map) {
      for (final entry in rawHoldMs.entries) {
        final parsedKey = int.tryParse(entry.key.toString());
        final rawValue = entry.value;
        if (parsedKey == null || rawValue is! num) continue;
        parsedHoldMs[parsedKey] = rawValue.toInt();
      }
    }
    final rawStabilityWindows = map['stringStabilityWindows'];
    if (rawStabilityWindows is Map) {
      for (final entry in rawStabilityWindows.entries) {
        final parsedKey = int.tryParse(entry.key.toString());
        final rawValue = entry.value;
        if (parsedKey == null || rawValue is! num) continue;
        parsedStabilityWindows[parsedKey] = rawValue.toInt();
      }
    }

    return TunerSettings(
      a4Reference: (map['a4Reference'] as num?)?.toDouble() ?? 440.0,
      sensitivity: TunerSensitivity.values.firstWhere(
        (e) => e.name == map['sensitivity'],
        orElse: () => TunerSensitivity.medium,
      ),
      noiseGate: (map['noiseGate'] as num?)?.toDouble() ?? 0.005,
      tuningPreset: TuningPreset.values.firstWhere(
        (e) => e.name == map['tuningPreset'],
        orElse: () => TuningPreset.chromatic,
      ),
      lowLatencyMode: map['lowLatencyMode'] as bool? ?? false,
      stringSensitivities: {
        ...defaultStringSensitivities,
        ...parsedSensitivities,
      },
      stringHoldMs: {...defaultStringHoldMs, ...parsedHoldMs},
      stringStabilityWindows: {
        ...defaultStringStabilityWindows,
        ...parsedStabilityWindows,
      },
    );
  }
}

const defaultStringSensitivities = <int, double>{
  1: 1.0,
  2: 1.0,
  3: 1.0,
  4: 1.0,
  5: 1.0,
  6: 1.0,
};

const defaultStringHoldMs = <int, int>{
  1: 700,
  2: 520,
  3: 500,
  4: 400,
  5: 360,
  6: 400,
};

const defaultStringStabilityWindows = <int, int>{
  1: 3,
  2: 4,
  3: 4,
  4: 5,
  5: 9,
  6: 5,
};
