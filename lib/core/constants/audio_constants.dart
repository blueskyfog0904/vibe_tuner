class AudioConstants {
  static const int sampleRate = 44100;
  static const int bufferSize = 4096; // 넉넉하게 잡음 (2048 or 4096)
  static const int smoothingWindowSize = 5;

  // Ignore very low-energy frames to reduce false pitch detection in noise.
  static const double minRmsForPitch = 0.01;

  // Practical tuning range for common string instruments.
  static const double minDetectableFrequency = 50.0;
  static const double maxDetectableFrequency = 1500.0;
}
