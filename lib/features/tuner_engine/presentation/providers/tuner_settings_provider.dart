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
  final settings = ref.watch(tunerSettingsProvider).valueOrNull ??
      const TunerSettings.defaults();
  return TunerProcessingConfig(
    minRmsForPitch: settings.noiseGate,
    minDetectableFrequency: AudioConstants.minDetectableFrequency,
    maxDetectableFrequency: AudioConstants.maxDetectableFrequency,
    smoothingWindowSize: _smoothingWindowFromSensitivity(settings.sensitivity),
  );
});

int _smoothingWindowFromSensitivity(TunerSensitivity sensitivity) {
  return switch (sensitivity) {
    TunerSensitivity.high => 3,
    TunerSensitivity.medium => 5,
    TunerSensitivity.low => 8,
  };
}

const supportedA4References = <double>[432.0, 440.0];
const minNoiseGate = 0.001;
const maxNoiseGate = 0.05;

double normalizeA4Reference(double value) {
  return (value - 432.0).abs() <= (value - 440.0).abs() ? 432.0 : 440.0;
}

double normalizeNoiseGate(double value) => value.clamp(minNoiseGate, maxNoiseGate);

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

class TunerSettingsNotifier extends AsyncNotifier<TunerSettings> {
  static const _keyA4 = 'tuner_settings_a4';
  static const _keySensitivity = 'tuner_settings_sensitivity';
  static const _keyNoiseGate = 'tuner_settings_noise_gate';
  static const _keyTuningPreset = 'tuner_settings_tuning_preset';

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
      noiseGate: normalizeNoiseGate(_prefs!.getDouble(_keyNoiseGate) ?? 0.01),
      tuningPreset: TuningPreset.values.firstWhere(
        (e) => e.name == _prefs!.getString(_keyTuningPreset),
        orElse: () => TuningPreset.chromatic,
      ),
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
}
