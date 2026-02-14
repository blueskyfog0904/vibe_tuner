import 'dart:async';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';

class ToneGenerator {
  final _logger = Logger('ToneGenerator');
  SoLoud? _soloud;
  AudioSource? _currentSource;
  SoundHandle? _currentHandle;

  // Base frequency: C4 (Middle C) - 261.63Hz.
  // Ideally, use a high-quality sample of a guitar plucking C4.
  static const double _baseFrequency = 261.63; 
  static const String _samplePath = 'assets/audio/guitar_c4.mp3';

  Future<void> initialize() async {
    try {
      _soloud = SoLoud.instance;
      if (!_soloud!.isInitialized) {
        await _soloud!.init();
        _logger.info("SoLoud initialized");
      }
    } catch (e) {
      _logger.severe("Failed to initialize SoLoud: $e");
    }
  }

  Future<void> playTone(double targetFrequency, {Duration duration = const Duration(seconds: 2)}) async {
    if (_soloud == null || !_soloud!.isInitialized) return;

    try {
      if (_currentHandle != null) {
          try { await _soloud!.stop(_currentHandle!); } catch (_) {}
      }

      // 1. Try Loading Sample from Assets
      try {
        // Note: loadAsset requires the full path including 'assets/' if registered that way.
        _currentSource = await _soloud!.loadAsset(_samplePath);
      } catch (assetError) {
        _logger.warning("Sample file not found ($_samplePath), falling back to Synthesis. Error: $assetError");
        
        // 2. Fallback: Synthesis (Sawtooth Wave)
        _currentSource = await _soloud!.loadWaveform(
          WaveForm.saw,
          true,
          1.0,
          1.0
        );
      }

      // 3. Calculate Speed for Pitch Shift
      // Speed 1.0 = Base Frequency (C4)
      // Speed 2.0 = One Octave Up (C5)
      final double speed = targetFrequency / _baseFrequency;

      // 4. Play
      _currentHandle = await _soloud!.play(_currentSource!);
      _soloud!.setRelativePlaySpeed(_currentHandle!, speed);
      
      // 5. Envelope (Fade In/Out) works for both Sample and Synth
      // Attack
      _soloud!.setVolume(_currentHandle!, 0); 
      _soloud!.fadeVolume(_currentHandle!, 1.0, const Duration(milliseconds: 50));

      // Release
      Future.delayed(duration - const Duration(milliseconds: 500), () async {
        if (_currentHandle != null) {
          try {
            _soloud!.fadeVolume(_currentHandle!, 0, const Duration(milliseconds: 500));
            await Future.delayed(const Duration(milliseconds: 500));
            // Check handle again before stopping
            if (_currentHandle != null) { 
               await _soloud!.stop(_currentHandle!);
            }
          } catch (e) {
            // Handle might be invalid if already stopped
          }
        }
      });

    } catch (e) {
      _logger.severe("Error playing tone: $e");
    }
  }

  Future<void> stop() async {
    if (_soloud != null && _currentHandle != null) {
        try {
            await _soloud!.stop(_currentHandle!);
        } catch (e) {
            // Ignore error if already stopped
        }
    }
  }
  
  void dispose() {
    _soloud?.deinit();
  }
}
