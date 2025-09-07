class PipelinePresetV01 {
  // Processing sample rate (downsampled)
  static const int srProc = 16000; // 16 kHz

  // Hop/window in samples at 16 kHz
  // v0.1: hop 20ms (320), window 100ms (1600)
  static const int hop = 320;
  static const int window = 1600;

  // Confidence thresholds (base)
  static const double tauCrepe = 0.50;
  static const double tauLocal = 0.60;
}

