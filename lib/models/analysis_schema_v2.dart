class AnalysisSchemaV2Meta {
  final int srIn;
  final int srProc;
  final int hop;
  final int window;
  final String engine;

  AnalysisSchemaV2Meta({
    required this.srIn,
    required this.srProc,
    required this.hop,
    required this.window,
    required this.engine,
  });

  static AnalysisSchemaV2Meta? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      return AnalysisSchemaV2Meta(
        srIn: (json['sr_in'] as num).toInt(),
        srProc: (json['sr_proc'] as num).toInt(),
        hop: (json['hop'] as num).toInt(),
        window: (json['window'] as num).toInt(),
        engine: (json['engine'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

class AnalysisSchemaV2Pitch {
  final double f0;
  final List<double> frequencies;
  final List<double> confidenceRaw;
  final List<double> confidenceAdaptive;
  final String note;
  final int octave;
  final int cents;

  AnalysisSchemaV2Pitch({
    required this.f0,
    required this.frequencies,
    required this.confidenceRaw,
    required this.confidenceAdaptive,
    required this.note,
    required this.octave,
    required this.cents,
  });

  static AnalysisSchemaV2Pitch? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      final freqs = (json['frequencies'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const <double>[];
      final confRaw = (json['confidence_raw'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const <double>[];
      final confAdapt = (json['confidence_adaptive'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const <double>[];
      return AnalysisSchemaV2Pitch(
        f0: (json['f0'] as num?)?.toDouble() ?? 0.0,
        frequencies: freqs,
        confidenceRaw: confRaw,
        confidenceAdaptive: confAdapt,
        note: (json['note'] ?? '').toString(),
        octave: (json['octave'] as num?)?.toInt() ?? 0,
        cents: (json['cents'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

class AnalysisSchemaV2Voicing {
  final double vad;
  final double? hnr;
  AnalysisSchemaV2Voicing({required this.vad, this.hnr});

  static AnalysisSchemaV2Voicing? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      return AnalysisSchemaV2Voicing(
        vad: (json['vad'] as num?)?.toDouble() ?? 0.0,
        hnr: (json['hnr'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}

class AnalysisSchemaV2 {
  final String version;
  final AnalysisSchemaV2Meta? meta;
  final AnalysisSchemaV2Pitch? pitch;
  final AnalysisSchemaV2Voicing? voicing;
  final bool success;

  AnalysisSchemaV2({
    required this.version,
    required this.meta,
    required this.pitch,
    required this.voicing,
    required this.success,
  });

  static AnalysisSchemaV2? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      return AnalysisSchemaV2(
        version: (json['version'] ?? '').toString(),
        meta: AnalysisSchemaV2Meta.fromJson(json['meta'] as Map<String, dynamic>?),
        pitch: AnalysisSchemaV2Pitch.fromJson(json['pitch'] as Map<String, dynamic>?),
        voicing: AnalysisSchemaV2Voicing.fromJson(json['voicing'] as Map<String, dynamic>?),
        success: (json['success'] == true),
      );
    } catch (_) {
      return null;
    }
  }

  bool get isValid => success && pitch != null && (pitch!.f0 > 0);
}

