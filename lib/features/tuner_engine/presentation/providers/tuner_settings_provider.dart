import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/audio_constants.dart';
import '../../domain/entities/tuner_processing_config.dart';
import '../../domain/entities/tuner_settings.dart';

final tunerSettingsProvider =
    AsyncNotifierProvider<TunerSettingsNotifier, TunerSettings>(
      TunerSettingsNotifier.new,
    );

final tunerProcessingConfigProvider = Provider<TunerProcessingConfig>((ref) {
  final settings =
      ref.watch(tunerSettingsProvider).valueOrNull ??
      const TunerSettings.defaults();
  final (minDetectableFrequency, maxDetectableFrequency) =
      frequencyRangeFromPreset(settings.tuningPreset);
  return TunerProcessingConfig(
    minRmsForPitch: settings.noiseGate,
    minDetectableFrequency: minDetectableFrequency,
    maxDetectableFrequency: maxDetectableFrequency,
    smoothingWindowSize: _smoothingWindowFromSensitivity(settings.sensitivity),
    maxWindowsPerDetector: settings.lowLatencyMode ? 1 : 4,
    detectorWindowSizes: const [1024, 2048],
    stringProfiles: _stringProfilesFromPreset(
      settings.tuningPreset,
      settings.stringSensitivities,
      settings.stringHoldMs,
      settings.stringStabilityWindows,
      settings.lowLatencyMode,
    ),
  );
});

int _smoothingWindowFromSensitivity(TunerSensitivity sensitivity) {
  return switch (sensitivity) {
    TunerSensitivity.high => 3,
    TunerSensitivity.medium => 5,
    TunerSensitivity.low => 8,
  };
}

List<StringSensitivityProfile> _stringProfilesFromPreset(
  TuningPreset preset,
  Map<int, double> stringSensitivities,
  Map<int, int> stringHoldMs,
  Map<int, int> stringStabilityWindows,
  bool lowLatencyMode,
) {
  double adjustedMultiplier({
    required int stringNumber,
    required double baseMultiplier,
  }) {
    final userSensitivity = normalizeStringSensitivity(
      stringSensitivities[stringNumber] ?? 1.0,
    );
    return baseMultiplier / userSensitivity;
  }

  final List<StringSensitivityProfile> baseProfiles = switch (preset) {
    TuningPreset.guitarStandard => _guitarBaseProfiles,
    TuningPreset.ukuleleStandard => _ukuleleBaseProfiles,
    // Keep 1~6 guitar-string controls effective in chromatic mode during guitar tests.
    TuningPreset.chromatic => _guitarBaseProfiles,
  };

  return baseProfiles.map((profile) {
    final adjusted = StringSensitivityProfile(
      stringNumber: profile.stringNumber,
      minFrequency: profile.minFrequency,
      maxFrequency: profile.maxFrequency,
      rmsMultiplier: adjustedMultiplier(
        stringNumber: profile.stringNumber,
        baseMultiplier: profile.rmsMultiplier,
      ),
      smoothingWindowSize: normalizeStringStabilityWindow(
        stringStabilityWindows[profile.stringNumber] ??
            profile.smoothingWindowSize,
      ),
      noSignalHoldMs: normalizeStringHoldMs(
        stringHoldMs[profile.stringNumber] ?? profile.noSignalHoldMs,
      ),
      noSignalDropFrames: profile.noSignalDropFrames,
    );
    return _latencyAdjustedProfile(adjusted, lowLatencyMode: lowLatencyMode);
  }).toList();
}

StringSensitivityProfile _latencyAdjustedProfile(
  StringSensitivityProfile profile, {
  required bool lowLatencyMode,
}) {
  if (!lowLatencyMode) return profile;
  final holdMs = switch (profile.stringNumber) {
    1 => profile.noSignalHoldMs.clamp(350, 650),
    2 => profile.noSignalHoldMs.clamp(320, 520),
    3 => profile.noSignalHoldMs.clamp(280, 460),
    _ => profile.noSignalHoldMs.clamp(120, 260),
  };
  final dropFrames = switch (profile.stringNumber) {
    1 || 2 || 3 => profile.noSignalDropFrames.clamp(2, 4),
    _ => profile.noSignalDropFrames.clamp(1, 2),
  };
  return StringSensitivityProfile(
    stringNumber: profile.stringNumber,
    minFrequency: profile.minFrequency,
    maxFrequency: profile.maxFrequency,
    rmsMultiplier: profile.rmsMultiplier,
    smoothingWindowSize: profile.smoothingWindowSize.clamp(2, 4),
    noSignalHoldMs: holdMs,
    noSignalDropFrames: dropFrames,
  );
}

const _guitarBaseProfiles = <StringSensitivityProfile>[
  // 6th string E2
  StringSensitivityProfile(
    stringNumber: 6,
    minFrequency: 72.0,
    maxFrequency: 96.0,
    rmsMultiplier: 1.00,
    smoothingWindowSize: 5,
    noSignalHoldMs: 400,
    noSignalDropFrames: 4,
  ),
  // 5th string A2: reduce sensitivity and stabilize.
  StringSensitivityProfile(
    stringNumber: 5,
    minFrequency: 96.0,
    maxFrequency: 132.0,
    rmsMultiplier: 1.18,
    smoothingWindowSize: 9,
    noSignalHoldMs: 360,
    noSignalDropFrames: 3,
  ),
  // 4th string D3
  StringSensitivityProfile(
    stringNumber: 4,
    minFrequency: 132.0,
    maxFrequency: 176.0,
    rmsMultiplier: 1.00,
    smoothingWindowSize: 5,
    noSignalHoldMs: 400,
    noSignalDropFrames: 4,
  ),
  // 3rd string G3: slightly more sensitive + longer sustain hold.
  StringSensitivityProfile(
    stringNumber: 3,
    minFrequency: 176.0,
    maxFrequency: 220.0,
    rmsMultiplier: 0.94,
    smoothingWindowSize: 4,
    noSignalHoldMs: 500,
    noSignalDropFrames: 5,
  ),
  // 2nd string B3: slightly more sensitive + longer sustain hold.
  StringSensitivityProfile(
    stringNumber: 2,
    minFrequency: 220.0,
    maxFrequency: 286.0,
    rmsMultiplier: 0.90,
    smoothingWindowSize: 4,
    noSignalHoldMs: 520,
    noSignalDropFrames: 5,
  ),
  // 1st string E4: significantly higher sensitivity.
  StringSensitivityProfile(
    stringNumber: 1,
    minFrequency: 286.0,
    maxFrequency: 380.0,
    rmsMultiplier: 0.70,
    smoothingWindowSize: 3,
    noSignalHoldMs: 700,
    noSignalDropFrames: 7,
  ),
];

const _ukuleleBaseProfiles = <StringSensitivityProfile>[
  StringSensitivityProfile(
    stringNumber: 4,
    minFrequency: 180.0,
    maxFrequency: 240.0,
    rmsMultiplier: 0.95,
    smoothingWindowSize: 4,
    noSignalHoldMs: 450,
    noSignalDropFrames: 4,
  ),
  StringSensitivityProfile(
    stringNumber: 3,
    minFrequency: 240.0,
    maxFrequency: 290.0,
    rmsMultiplier: 0.95,
    smoothingWindowSize: 4,
    noSignalHoldMs: 450,
    noSignalDropFrames: 4,
  ),
  StringSensitivityProfile(
    stringNumber: 2,
    minFrequency: 290.0,
    maxFrequency: 355.0,
    rmsMultiplier: 0.88,
    smoothingWindowSize: 4,
    noSignalHoldMs: 500,
    noSignalDropFrames: 5,
  ),
  StringSensitivityProfile(
    stringNumber: 1,
    minFrequency: 355.0,
    maxFrequency: 470.0,
    rmsMultiplier: 0.85,
    smoothingWindowSize: 3,
    noSignalHoldMs: 550,
    noSignalDropFrames: 5,
  ),
];

const minStringSensitivity = 0.5;
const maxStringSensitivity = 5.0;
const minStringHoldMs = 80;
const maxStringHoldMs = 1500;
const minStringStabilityWindow = 1;
const maxStringStabilityWindow = 12;
const iphone11ProRecommendedStringSensitivities = <int, double>{
  1: 3.8,
  2: 2.4,
  3: 2.2,
  4: 1.00,
  5: 0.72,
  6: 2.6,
};
const iphone11ProRecommendedStringHoldMs = <int, int>{
  1: 620,
  2: 520,
  3: 460,
  4: 240,
  5: 220,
  6: 260,
};
const iphone11ProRecommendedStabilityWindows = <int, int>{
  1: 4,
  2: 4,
  3: 4,
  4: 4,
  5: 4,
  6: 4,
};

double normalizeStringSensitivity(double value) =>
    value.clamp(minStringSensitivity, maxStringSensitivity);
int normalizeStringHoldMs(int value) =>
    value.clamp(minStringHoldMs, maxStringHoldMs);
int normalizeStringStabilityWindow(int value) =>
    value.clamp(minStringStabilityWindow, maxStringStabilityWindow);

String stringSensitivityLabel(int stringNumber) {
  return switch (stringNumber) {
    1 => '1st string (High E)',
    2 => '2nd string (B)',
    3 => '3rd string (G)',
    4 => '4th string (D)',
    5 => '5th string (A)',
    6 => '6th string (Low E)',
    _ => '$stringNumber string',
  };
}

const supportedA4References = <double>[432.0, 440.0];
const minNoiseGate = 0.001;
const maxNoiseGate = 0.05;

double normalizeA4Reference(double value) {
  return (value - 432.0).abs() <= (value - 440.0).abs() ? 432.0 : 440.0;
}

double normalizeNoiseGate(double value) =>
    value.clamp(minNoiseGate, maxNoiseGate);

double perfectCentsThresholdFromSensitivity(TunerSensitivity sensitivity) {
  return switch (sensitivity) {
    TunerSensitivity.high => 3.0,
    TunerSensitivity.medium => 5.0,
    TunerSensitivity.low => 8.0,
  };
}

Set<String>? allowedNoteNamesFromPreset(TuningPreset preset) {
  return switch (preset) {
    TuningPreset.chromatic => null,
    TuningPreset.guitarStandard => {'E', 'A', 'D', 'G', 'B'},
    TuningPreset.ukuleleStandard => {'G', 'C', 'E', 'A'},
  };
}

Set<int>? allowedMidiNumbersFromPreset(TuningPreset preset) {
  return switch (preset) {
    TuningPreset.chromatic => null,
    // E2 A2 D3 G3 B3 E4
    TuningPreset.guitarStandard => {40, 45, 50, 55, 59, 64},
    // G4 C4 E4 A4
    TuningPreset.ukuleleStandard => {67, 60, 64, 69},
  };
}

(double, double) frequencyRangeFromPreset(TuningPreset preset) {
  return switch (preset) {
    TuningPreset.guitarStandard => (65.0, 1000.0),
    TuningPreset.ukuleleStandard => (240.0, 470.0),
    TuningPreset.chromatic => (
      AudioConstants.minDetectableFrequency,
      AudioConstants.maxDetectableFrequency,
    ),
  };
}

class TunerSettingsNotifier extends AsyncNotifier<TunerSettings> {
  static const _keyA4 = 'tuner_settings_a4';
  static const _keySensitivity = 'tuner_settings_sensitivity';
  static const _keyNoiseGate = 'tuner_settings_noise_gate';
  static const _keyTuningPreset = 'tuner_settings_tuning_preset';
  static const _keyLowLatencyMode = 'tuner_settings_low_latency_mode';
  static const _keyStringSensitivityPrefix =
      'tuner_settings_string_sensitivity_';
  static const _keyStringHoldMsPrefix = 'tuner_settings_string_hold_ms_';
  static const _keyStringStabilityPrefix = 'tuner_settings_string_stability_';

  SharedPreferences? _prefs;

  @override
  Future<TunerSettings> build() async {
    _prefs = await SharedPreferences.getInstance();
    return TunerSettings(
      a4Reference: normalizeA4Reference(_prefs!.getDouble(_keyA4) ?? 440.0),
      sensitivity: TunerSensitivity.values.firstWhere(
        (e) => e.name == _prefs!.getString(_keySensitivity),
        orElse: () => TunerSensitivity.medium,
      ),
      noiseGate: normalizeNoiseGate(_prefs!.getDouble(_keyNoiseGate) ?? 0.005),
      tuningPreset: TuningPreset.values.firstWhere(
        (e) => e.name == _prefs!.getString(_keyTuningPreset),
        orElse: () => TuningPreset.chromatic,
      ),
      lowLatencyMode: _prefs!.getBool(_keyLowLatencyMode) ?? false,
      stringSensitivities: {
        for (var i = 1; i <= 6; i++)
          i: normalizeStringSensitivity(
            _prefs!.getDouble('$_keyStringSensitivityPrefix$i') ??
                (defaultStringSensitivities[i] ?? 1.0),
          ),
      },
      stringHoldMs: {
        for (var i = 1; i <= 6; i++)
          i: normalizeStringHoldMs(
            _prefs!.getInt('$_keyStringHoldMsPrefix$i') ??
                (defaultStringHoldMs[i] ?? 300),
          ),
      },
      stringStabilityWindows: {
        for (var i = 1; i <= 6; i++)
          i: normalizeStringStabilityWindow(
            _prefs!.getInt('$_keyStringStabilityPrefix$i') ??
                (defaultStringStabilityWindows[i] ?? 4),
          ),
      },
    );
  }

  Future<void> setA4Reference(double value) async {
    final normalized = normalizeA4Reference(value);
    final current = state.valueOrNull ?? const TunerSettings.defaults();
    final next = current.copyWith(a4Reference: normalized);
    state = AsyncData(next);
    await _prefs?.setDouble(_keyA4, normalized);
  }

  Future<void> setSensitivity(TunerSensitivity value) async {
    final current = state.valueOrNull ?? const TunerSettings.defaults();
    final next = current.copyWith(sensitivity: value);
    state = AsyncData(next);
    await _prefs?.setString(_keySensitivity, value.name);
  }

  Future<void> setNoiseGate(double value) async {
    final normalized = normalizeNoiseGate(value);
    final current = state.valueOrNull ?? const TunerSettings.defaults();
    final next = current.copyWith(noiseGate: normalized);
    state = AsyncData(next);
    await _prefs?.setDouble(_keyNoiseGate, normalized);
  }

  Future<void> setTuningPreset(TuningPreset value) async {
    final current = state.valueOrNull ?? const TunerSettings.defaults();
    final next = current.copyWith(tuningPreset: value);
    state = AsyncData(next);
    await _prefs?.setString(_keyTuningPreset, value.name);
  }

  Future<void> setLowLatencyMode(bool value) async {
    final current = state.valueOrNull ?? const TunerSettings.defaults();
    final next = current.copyWith(lowLatencyMode: value);
    state = AsyncData(next);
    await _prefs?.setBool(_keyLowLatencyMode, value);
  }

  Future<void> setStringSensitivity(int stringNumber, double value) async {
    if (stringNumber < 1 || stringNumber > 6) return;
    final normalized = normalizeStringSensitivity(value);
    final current = state.valueOrNull ?? const TunerSettings.defaults();
    final nextMap = <int, double>{
      ...current.stringSensitivities,
      stringNumber: normalized,
    };
    final next = current.copyWith(stringSensitivities: nextMap);
    state = AsyncData(next);
    await _prefs?.setDouble(
      '$_keyStringSensitivityPrefix$stringNumber',
      normalized,
    );
  }

  Future<void> setStringHoldMs(int stringNumber, int value) async {
    if (stringNumber < 1 || stringNumber > 6) return;
    final normalized = normalizeStringHoldMs(value);
    final current = state.valueOrNull ?? const TunerSettings.defaults();
    final nextMap = <int, int>{
      ...current.stringHoldMs,
      stringNumber: normalized,
    };
    final next = current.copyWith(stringHoldMs: nextMap);
    state = AsyncData(next);
    await _prefs?.setInt('$_keyStringHoldMsPrefix$stringNumber', normalized);
  }

  Future<void> setStringStabilityWindow(int stringNumber, int value) async {
    if (stringNumber < 1 || stringNumber > 6) return;
    final normalized = normalizeStringStabilityWindow(value);
    final current = state.valueOrNull ?? const TunerSettings.defaults();
    final nextMap = <int, int>{
      ...current.stringStabilityWindows,
      stringNumber: normalized,
    };
    final next = current.copyWith(stringStabilityWindows: nextMap);
    state = AsyncData(next);
    await _prefs?.setInt('$_keyStringStabilityPrefix$stringNumber', normalized);
  }

  Future<void> applyIphone11ProGuitarPreset() async {
    final current = state.valueOrNull ?? const TunerSettings.defaults();
    final next = current.copyWith(
      tuningPreset: TuningPreset.guitarStandard,
      lowLatencyMode: true,
      // Slightly tighter gate for iPhone 11 Pro mic in common indoor noise.
      noiseGate: normalizeNoiseGate(0.0045),
      stringSensitivities: iphone11ProRecommendedStringSensitivities,
      stringHoldMs: iphone11ProRecommendedStringHoldMs,
      stringStabilityWindows: iphone11ProRecommendedStabilityWindows,
    );
    state = AsyncData(next);
    await _prefs?.setString(_keyTuningPreset, next.tuningPreset.name);
    await _prefs?.setBool(_keyLowLatencyMode, next.lowLatencyMode);
    await _prefs?.setDouble(_keyNoiseGate, next.noiseGate);
    for (final entry in next.stringSensitivities.entries) {
      await _prefs?.setDouble(
        '$_keyStringSensitivityPrefix${entry.key}',
        normalizeStringSensitivity(entry.value),
      );
    }
    for (final entry in next.stringHoldMs.entries) {
      await _prefs?.setInt(
        '$_keyStringHoldMsPrefix${entry.key}',
        normalizeStringHoldMs(entry.value),
      );
    }
    for (final entry in next.stringStabilityWindows.entries) {
      await _prefs?.setInt(
        '$_keyStringStabilityPrefix${entry.key}',
        normalizeStringStabilityWindow(entry.value),
      );
    }
  }
}
