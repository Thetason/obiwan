import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'ondevice_crepe_service.dart';
import '../config/pipeline_preset.dart';
import 'vad_service.dart';

class RealtimePitchEvent {
  final double timeSec;
  final double frequency;
  final double confidence;
  final bool voiced;

  const RealtimePitchEvent({
    required this.timeSec,
    required this.frequency,
    required this.confidence,
    required this.voiced,
  });
}

/// Lightweight realtime pitch stream without Timer.periodic.
/// Uses an async loop with hop-sized sleeps to avoid setState-after-dispose issues.
class RealtimePitchStream {
  final OnDeviceCrepeService _onDevice = OnDeviceCrepeService();
  final VADService _vad = VADService();

  final _controller = StreamController<RealtimePitchEvent>.broadcast();
  bool _running = false;
  double _t = 0.0; // seconds

  Stream<RealtimePitchEvent> get stream => _controller.stream;

  Future<void> start(Float32List audio, {double sampleRate = 48000.0}) async {
    if (_running) return;
    _running = true;
    _t = 0.0;
    await _onDevice.initialize();

    final hop = PipelinePresetV01.hop;
    final win = PipelinePresetV01.window;
    final n = audio.length;
    int idx = 0;

    while (_running && idx + win <= n) {
      final end = idx + win;
      final window = Float32List.fromList(audio.sublist(idx, end));

      // VAD gating (simple energy check + VADService)
      final rms = _rms(window);
      var voiced = rms > 0.01; // quick check
      if (voiced) {
        final vadRes = _vad.processFrame(window.toList());
        voiced = vadRes.isVoiced;
      }

      double f0 = 0.0, conf = 0.0;
      if (voiced) {
        final res = await _onDevice.analyzeWindow(window, sampleRate: sampleRate);
        f0 = res.frequency;
        conf = res.confidence;
      }

      _controller.add(RealtimePitchEvent(
        timeSec: _t,
        frequency: f0,
        confidence: conf,
        voiced: voiced && f0 > 0,
      ));

      // advance
      idx += hop;
      _t += hop / sampleRate;
      // sleep approximately hop duration (prevents tight CPU loop when fed prerecorded audio)
      await Future.delayed(Duration(milliseconds: (1000 * hop / sampleRate).round()));
    }
  }

  void stop() {
    _running = false;
  }

  Future<void> dispose() async {
    _running = false;
    await _controller.close();
  }

  double _rms(Float32List x) {
    if (x.isEmpty) return 0.0;
    double s = 0.0;
    for (final v in x) { s += v * v; }
    return math.sqrt(s / x.length);
  }
}

