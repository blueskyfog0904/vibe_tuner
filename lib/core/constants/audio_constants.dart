class AudioConstants {
  static const int sampleRate = 44100;
  static const int bufferSize = 2048;
  static const int smoothingWindowSize = 5;

  // Ignore very low-energy frames to reduce false pitch detection in noise.
  static const double minRmsForPitch = 0.005;

  // Keep latest valid pitch briefly to avoid flickering no-signal on sustain decay.
  static const int noSignalHoldMs = 400;
  static const int noSignalDropFrames = 4;

  // Practical tuning range for common string instruments.
  static const double minDetectableFrequency = 50.0;
  static const double maxDetectableFrequency = 1500.0;
}
