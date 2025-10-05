import 'dart:async';

class AudioServiceStatus {
  final bool supported;
  final bool initialized;
  final bool permissionGranted;
  final String backendName;
  final String? message;
  final String? error;

  const AudioServiceStatus({
    required this.supported,
    required this.initialized,
    required this.permissionGranted,
    required this.backendName,
    this.message,
    this.error,
  });

  const AudioServiceStatus.unsupported({
    String backendName = 'unsupported',
    String? message,
  }) : this(
          supported: false,
          initialized: false,
          permissionGranted: false,
          backendName: backendName,
          message: message,
          error: message,
        );

  AudioServiceStatus copyWith({
    bool? supported,
    bool? initialized,
    bool? permissionGranted,
    String? backendName,
    String? message,
    String? error,
  }) {
    return AudioServiceStatus(
      supported: supported ?? this.supported,
      initialized: initialized ?? this.initialized,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      backendName: backendName ?? this.backendName,
      message: message ?? this.message,
      error: error ?? this.error,
    );
  }
}

class AudioCaptureResult {
  final List<double>? samples;
  final int? sampleRate;
  final Duration? duration;
  final String? filePath;
  final String? format;

  const AudioCaptureResult({
    this.samples,
    this.sampleRate,
    this.duration,
    this.filePath,
    this.format,
  });

  AudioCaptureResult merge(AudioCaptureResult other) {
    return AudioCaptureResult(
      samples: other.samples ?? samples,
      sampleRate: other.sampleRate ?? sampleRate,
      duration: other.duration ?? duration,
      filePath: other.filePath ?? filePath,
      format: other.format ?? format,
    );
  }
}

abstract class AudioBackend {
  Stream<Map<String, double>>? get audioLevelStream;

  Future<AudioServiceStatus> initialize();

  Future<AudioServiceStatus> requestPermissions();

  Future<bool> startRecording();

  Future<bool> stopRecording();

  Future<AudioCaptureResult?> fetchRecordedAudio();

  Future<Map<String, dynamic>> describeSystem();

  Future<void> dispose();
}
