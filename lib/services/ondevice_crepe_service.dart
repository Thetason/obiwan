import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../config/pipeline_preset.dart';
import 'package:flutter/services.dart';
import 'single_pitch_tracker.dart';

/// On-device CREPE service (TFLite/CoreML planned)
/// - This is a thin abstraction so we can swap in platform-specific backends
/// - For now, it falls back to local YIN/Autocorr via SinglePitchTracker
class OnDeviceCrepeService {
  static final OnDeviceCrepeService _instance = OnDeviceCrepeService._internal();
  factory OnDeviceCrepeService() => _instance;
  OnDeviceCrepeService._internal();

  final _tracker = SinglePitchTracker();

  bool _initialized = false;
  bool _available = false; // set true when TFLite/CoreML model is wired
  static const MethodChannel _channel = MethodChannel('obiwan.ondevice_crepe');

  bool get isAvailable => _available;

  /// Initialize on-device model (stub)
  Future<void> initialize() async {
    if (_initialized) return;
    // TODO: load TFLite/CoreML model (assets/models/crepe_tiny.tflite or CoreML .mlmodelc)
    // For now mark as unavailable and rely on tracker fallback
    _available = false;
    _initialized = true;
    debugPrint('[OnDeviceCREPE] initialized (available=$_available)');
  }

  /// Analyze a single window (frame-based) and return f0/confidence
  /// If on-device model not available, uses SinglePitchTracker fallback.
  Future<_F0Frame> analyzeWindow(Float32List window, {double sampleRate = 48000.0}) async {
    if (!_initialized) await initialize();

    if (_available) {
      // TODO: run TFLite/CoreML inference for this window
      // Return decoded f0 and confidence
    }

    // Try iOS CoreML via MethodChannel (returns zeros until wired)
    try {
      final byteData = ByteData(window.length * 4);
      for (int i = 0; i < window.length; i++) {
        byteData.setFloat32(i * 4, window[i], Endian.little);
      }
      final res = await _channel.invokeMethod<dynamic>('analyzeWindow', {
        'audio_bytes': byteData.buffer.asUint8List(),
        'sample_rate': sampleRate,
      });
      if (res is Map) {
        final f0 = (res['f0'] as num?)?.toDouble() ?? 0.0;
        final conf = (res['confidence'] as num?)?.toDouble() ?? 0.0;
        if (f0 > 0) {
          return _F0Frame(frequency: f0, confidence: conf);
        }
      }
    } catch (e) {
      debugPrint('[OnDeviceCREPE] iOS channel failed: $e');
    }

    // Fallback: use local precise tracker (YIN/Autocorr fusion)
    final result = await _tracker.trackSinglePitch(window, sampleRate: sampleRate);
    return _F0Frame(frequency: result.frequency, confidence: result.confidence);
  }

  /// Sliding-window time-based analysis using v0.1 presets
  Future<List<_F0Point>> analyzeTimeSeries(Float32List audio, {double sampleRate = 48000.0}) async {
    if (audio.isEmpty) return const [];
    if (!_initialized) await initialize();

    final hop = PipelinePresetV01.hop;
    final win = PipelinePresetV01.window;
    final n = audio.length;
    final pts = <_F0Point>[];

    for (int start = 0; start + win <= n; start += hop) {
      final end = start + win;
      final window = Float32List.fromList(audio.sublist(start, end));
      final f = await analyzeWindow(window, sampleRate: sampleRate);
      final t = start / sampleRate;
      pts.add(_F0Point(t: t, f0: f.frequency, conf: f.confidence));
    }
    return pts;
  }
}

class _F0Frame {
  final double frequency;
  final double confidence;
  const _F0Frame({required this.frequency, required this.confidence});
}

class _F0Point {
  final double t; // seconds
  final double f0;
  final double conf;
  const _F0Point({required this.t, required this.f0, required this.conf});
}
