import 'package:flutter/services.dart';
import '../domain/entities/tuning_result.dart';

class HapticManager {
  DateTime? _lastPerfectVibration;
  static const Duration _perfectCoolDown = Duration(milliseconds: 500);

  /// Triggers haptic feedback based on tuning status.
  Future<void> feedback(TuningStatus status) async {
    switch (status) {
      case TuningStatus.perfect:
        await _onPerfectMatch();
        break;
      case TuningStatus.tooHigh:
      case TuningStatus.tooLow:
        // Optional: Very light feedback or none.
        // For now, we only vibrate on perfect match to avoid noise.
        break;
      case TuningStatus.noSignal:
        break;
    }
  }

  Future<void> _onPerfectMatch() async {
    final now = DateTime.now();
    if (_lastPerfectVibration == null || 
        now.difference(_lastPerfectVibration!) > _perfectCoolDown) {
      
      _lastPerfectVibration = now;
      // "Heavy" or "Medium" impact for clear confirmation
      await HapticFeedback.heavyImpact(); 
    }
  }

  // Optional: different patterns for near-miss if requested later
}
