import 'dart:math' as math;
import '../models/pitch_point.dart';

class FrameScores {
  final double rpa; // Raw Pitch Accuracy
  final double vr;  // Voicing Recall
  final double oa;  // Overall Accuracy
  const FrameScores({required this.rpa, required this.vr, required this.oa});
}

class NoteScores {
  final double meanCents;
  final double medianCents;
  final double stability; // lower is better (variance)
  final double vibratoRateHz;
  final double vibratoExtentCents;
  const NoteScores({
    required this.meanCents,
    required this.medianCents,
    required this.stability,
    required this.vibratoRateHz,
    required this.vibratoExtentCents,
  });
}

class ScoringService {
  /// Compute frame-level scores with a reference (optional). If no reference, uses heuristic voicing.
  FrameScores frameScores(List<PitchPoint> frames, {List<PitchPoint>? reference}) {
    if (frames.isEmpty) return const FrameScores(rpa: 0, vr: 0, oa: 0);
    int voiced = 0, correctlyVoiced = 0, correctPitch = 0;

    for (int i = 0; i < frames.length; i++) {
      final f = frames[i];
      final isVoiced = f.frequency > 0 && f.confidence > 0.5;
      if (reference != null && i < reference.length) {
        final r = reference[i];
        final rVoiced = r.frequency > 0;
        if (rVoiced) voiced++;
        if (isVoiced && rVoiced) {
          correctlyVoiced++;
          if (_centsError(f.frequency, r.frequency).abs() <= 50) {
            correctPitch++;
          }
        }
      } else {
        // heuristic
        if (isVoiced) {
          voiced++;
          correctlyVoiced++;
          correctPitch++;
        }
      }
    }
    final n = frames.length.toDouble();
    final vr = voiced == 0 ? 0.0 : correctlyVoiced / voiced;
    final rpa = n == 0 ? 0.0 : correctPitch / n;
    final oa = n == 0 ? 0.0 : correctlyVoiced / n;
    return FrameScores(rpa: rpa, vr: vr, oa: oa);
  }

  /// Compute note-level metrics from a slice of pitch points belonging to a single note.
  NoteScores noteScores(List<PitchPoint> noteFrames) {
    if (noteFrames.isEmpty) {
      return const NoteScores(meanCents: 0, medianCents: 0, stability: 0, vibratoRateHz: 0, vibratoExtentCents: 0);
    }

    // mean/median cents vs mean frequency as reference
    final meanFreq = noteFrames.map((e) => e.frequency).reduce((a, b) => a + b) / noteFrames.length;
    final cents = noteFrames.map((e) => _centsError(e.frequency, meanFreq)).toList();
    cents.sort();
    final meanC = cents.reduce((a, b) => a + b) / cents.length;
    final medianC = cents[cents.length ~/ 2];
    // stability (variance of cents)
    double var = 0.0;
    for (final c in cents) { var += (c - meanC) * (c - meanC); }
    final stability = var / cents.length;

    // vibrato rate/extent (very lightweight)
    final extent = cents.map((e) => e.abs()).reduce(math.max);
    final rate = _estimateVibratoRate(noteFrames);

    return NoteScores(
      meanCents: meanC,
      medianCents: medianC,
      stability: stability,
      vibratoRateHz: rate,
      vibratoExtentCents: extent,
    );
  }

  double _centsError(double f, double ref) {
    if (f <= 0 || ref <= 0) return 1200.0; // large error
    return 1200.0 * (math.log(f / ref) / math.ln2);
  }

  double _estimateVibratoRate(List<PitchPoint> frames) {
    if (frames.length < 6) return 0.0;
    // naive: count zero-crossings of detrended cents
    final meanFreq = frames.map((e) => e.frequency).reduce((a, b) => a + b) / frames.length;
    final cents = frames.map((e) => _centsError(e.frequency, meanFreq)).toList();
    // detrend by mean
    final meanC = cents.reduce((a, b) => a + b) / cents.length;
    final x = cents.map((e) => e - meanC).toList();
    int crossings = 0;
    for (int i = 1; i < x.length; i++) {
      if ((x[i - 1] >= 0) != (x[i] >= 0)) crossings++;
    }
    // approximate period: 2 zero-crossings per cycle
    final framesPerSec = 10.0; // for 100ms window hop 20ms -> 50 fps; here set 10 as safe default
    final cycles = crossings / 2.0;
    final seconds = frames.length / framesPerSec;
    return seconds > 0 ? cycles / seconds : 0.0;
  }
}

