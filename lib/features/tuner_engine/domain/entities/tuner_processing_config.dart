import '../../../../core/constants/audio_constants.dart';

class StringSensitivityProfile {
  final int stringNumber;
  final double minFrequency;
  final double maxFrequency;
  final double rmsMultiplier;
  final int smoothingWindowSize;
  final int noSignalHoldMs;
  final int noSignalDropFrames;

  const StringSensitivityProfile({
    required this.stringNumber,
    required this.minFrequency,
    required this.maxFrequency,
    required this.rmsMultiplier,
    required this.smoothingWindowSize,
    required this.noSignalHoldMs,
    required this.noSignalDropFrames,
  });

  bool matchesFrequency(double frequency) {
    return frequency >= minFrequency && frequency <= maxFrequency;
  }

  Map<String, Object> toMap() {
    return {
      'stringNumber': stringNumber,
      'minFrequency': minFrequency,
      'maxFrequency': maxFrequency,
      'rmsMultiplier': rmsMultiplier,
      'smoothingWindowSize': smoothingWindowSize,
      'noSignalHoldMs': noSignalHoldMs,
      'noSignalDropFrames': noSignalDropFrames,
    };
  }

  factory StringSensitivityProfile.fromMap(Map<String, Object?> map) {
    return StringSensitivityProfile(
      stringNumber: (map['stringNumber'] as num).toInt(),
      minFrequency: (map['minFrequency'] as num).toDouble(),
      maxFrequency: (map['maxFrequency'] as num).toDouble(),
      rmsMultiplier: (map['rmsMultiplier'] as num).toDouble(),
      smoothingWindowSize: (map['smoothingWindowSize'] as num).toInt(),
      noSignalHoldMs: (map['noSignalHoldMs'] as num).toInt(),
      noSignalDropFrames: (map['noSignalDropFrames'] as num).toInt(),
    );
  }
}

class TunerProcessingConfig {
  final double minRmsForPitch;
  final double minDetectableFrequency;
  final double maxDetectableFrequency;
  final int smoothingWindowSize;
  final int maxWindowsPerDetector;
  final List<int> detectorWindowSizes;
  final List<StringSensitivityProfile> stringProfiles;

  const TunerProcessingConfig({
    required this.minRmsForPitch,
    required this.minDetectableFrequency,
    required this.maxDetectableFrequency,
    required this.smoothingWindowSize,
    this.maxWindowsPerDetector = 4,
    this.detectorWindowSizes = const [1024, 2048],
    this.stringProfiles = const [],
  });

  const TunerProcessingConfig.defaults()
    : minRmsForPitch = AudioConstants.minRmsForPitch,
      minDetectableFrequency = AudioConstants.minDetectableFrequency,
      maxDetectableFrequency = AudioConstants.maxDetectableFrequency,
      smoothingWindowSize = AudioConstants.smoothingWindowSize,
      maxWindowsPerDetector = 4,
      detectorWindowSizes = const [1024, 2048],
      stringProfiles = const [];

  TunerProcessingConfig copyWith({
    double? minRmsForPitch,
    double? minDetectableFrequency,
    double? maxDetectableFrequency,
    int? smoothingWindowSize,
    int? maxWindowsPerDetector,
    List<int>? detectorWindowSizes,
    List<StringSensitivityProfile>? stringProfiles,
  }) {
    return TunerProcessingConfig(
      minRmsForPitch: minRmsForPitch ?? this.minRmsForPitch,
      minDetectableFrequency:
          minDetectableFrequency ?? this.minDetectableFrequency,
      maxDetectableFrequency:
          maxDetectableFrequency ?? this.maxDetectableFrequency,
      smoothingWindowSize: smoothingWindowSize ?? this.smoothingWindowSize,
      maxWindowsPerDetector:
          maxWindowsPerDetector ?? this.maxWindowsPerDetector,
      detectorWindowSizes: detectorWindowSizes ?? this.detectorWindowSizes,
      stringProfiles: stringProfiles ?? this.stringProfiles,
    );
  }

  StringSensitivityProfile? profileForFrequency(double frequency) {
    for (final profile in stringProfiles) {
      if (profile.matchesFrequency(frequency)) {
        return profile;
      }
    }
    return null;
  }

  Map<String, Object> toMap() {
    return {
      'minRmsForPitch': minRmsForPitch,
      'minDetectableFrequency': minDetectableFrequency,
      'maxDetectableFrequency': maxDetectableFrequency,
      'smoothingWindowSize': smoothingWindowSize,
      'maxWindowsPerDetector': maxWindowsPerDetector,
      'detectorWindowSizes': detectorWindowSizes,
      'stringProfiles': stringProfiles.map((e) => e.toMap()).toList(),
    };
  }

  factory TunerProcessingConfig.fromMap(Map<String, Object?> map) {
    final rawProfiles = map['stringProfiles'];
    return TunerProcessingConfig(
      minRmsForPitch: (map['minRmsForPitch'] as num).toDouble(),
      minDetectableFrequency: (map['minDetectableFrequency'] as num).toDouble(),
      maxDetectableFrequency: (map['maxDetectableFrequency'] as num).toDouble(),
      smoothingWindowSize: (map['smoothingWindowSize'] as num).toInt(),
      maxWindowsPerDetector:
          (map['maxWindowsPerDetector'] as num?)?.toInt() ?? 4,
      detectorWindowSizes:
          (map['detectorWindowSizes'] as List?)
              ?.whereType<num>()
              .map((e) => e.toInt())
              .where((e) => e > 0)
              .toList() ??
          const [1024, 2048],
      stringProfiles: rawProfiles is List
          ? rawProfiles
                .whereType<Map>()
                .map(
                  (e) => StringSensitivityProfile.fromMap(
                    e.cast<String, Object?>(),
                  ),
                )
                .toList()
          : const [],
    );
  }
}
