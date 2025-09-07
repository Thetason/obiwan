import 'package:flutter/material.dart';
import '../services/scoring_service.dart';
import '../services/coach_templates.dart';
import '../models/pitch_point.dart';

class SessionReport extends StatelessWidget {
  final List<PitchPoint> frames;
  const SessionReport({super.key, required this.frames});

  @override
  Widget build(BuildContext context) {
    final scorer = ScoringService();
    final fs = scorer.frameScores(frames);
    // simple note slice: use all frames as one note for MVP
    final ns = scorer.noteScores(frames);
    final tips = CoachTemplates.fromMetrics(
      medianCents: ns.medianCents,
      stability: ns.stability,
      vibratoRateHz: ns.vibratoRateHz,
      vibratoExtentCents: ns.vibratoExtentCents,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Session Summary', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 8, children: [
          _metric('RPA', (fs.rpa * 100).toStringAsFixed(0) + '%'),
          _metric('VR', (fs.vr * 100).toStringAsFixed(0) + '%'),
          _metric('OA', (fs.oa * 100).toStringAsFixed(0) + '%'),
          _metric('Median¢', ns.medianCents.toStringAsFixed(0)),
          _metric('VibratoHz', ns.vibratoRateHz.toStringAsFixed(1)),
          _metric('Vibrato¢', ns.vibratoExtentCents.toStringAsFixed(0)),
        ]),
        const SizedBox(height: 12),
        Text('코칭', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final t in tips)
          Row(children: [
            const Icon(Icons.tips_and_updates, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(t)),
          ]),
      ],
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

