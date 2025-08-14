import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../tokens/colors.dart';
import '../tokens/typography.dart';
import '../tokens/spacing.dart';
import '../components/vj_card.dart';
import '../components/vj_button.dart';
import '../components/vj_pitch_graph.dart';
import '../components/vj_wave_visualizer.dart';
import '../components/vj_progress_ring.dart';
import '../components/vj_stat_card.dart';
import '../../services/native_audio_service.dart';

class VJAnalysisResult extends StatefulWidget {
  final List<PitchPoint> pitchData;
  final List<double> audioData;
  final double accuracy;
  final double duration;

  const VJAnalysisResult({
    Key? key,
    required this.pitchData,
    required this.audioData,
    required this.accuracy,
    required this.duration,
  }) : super(key: key);

  @override
  State<VJAnalysisResult> createState() => _VJAnalysisResultState();
}

class _VJAnalysisResultState extends State<VJAnalysisResult>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _playbackController;
  bool _isPlaying = false;
  double _playbackPosition = 0.0;
  final _audioService = NativeAudioService.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _playbackController = AnimationController(
      duration: Duration(seconds: widget.duration.toInt()),
      vsync: this,
    );
    _playbackController.addListener(() {
      setState(() {
        _playbackPosition = _playbackController.value;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _playbackController.dispose();
    _audioService.stopPlayback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VJColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: VJColors.gray700),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Analysis Results',
          style: VJTypography.titleLarge.copyWith(
            color: VJColors.gray900,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined, color: VJColors.gray700),
            onPressed: _shareResults,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildOverallScore(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildPitchTab(),
                  _buildInsightsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallScore() {
    return Container(
      padding: EdgeInsets.all(VJSpacing.lg),
      decoration: BoxDecoration(
        gradient: VJColors.primaryGradient,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildScoreItem(
            'Accuracy',
            '${(widget.accuracy * 100).toInt()}%',
            Icons.adjust,
          ),
          Container(
            width: 1,
            height: 50,
            color: VJColors.white.withOpacity(0.2),
          ),
          _buildScoreItem(
            'Duration',
            '${widget.duration.toStringAsFixed(1)}s',
            Icons.timer,
          ),
          Container(
            width: 1,
            height: 50,
            color: VJColors.white.withOpacity(0.2),
          ),
          _buildScoreItem(
            'Notes Hit',
            '${_calculateNotesHit()}',
            Icons.music_note,
          ),
        ],
      ),
    );
  }

  Widget _buildScoreItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: VJColors.white.withOpacity(0.8),
          size: 20,
        ),
        SizedBox(height: VJSpacing.xs),
        Text(
          value,
          style: VJTypography.headlineSmall.copyWith(
            color: VJColors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: VJSpacing.xxs),
        Text(
          label,
          style: VJTypography.labelSmall.copyWith(
            color: VJColors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: VJColors.surface,
        border: Border(
          bottom: BorderSide(
            color: VJColors.gray200,
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: VJColors.primary,
        unselectedLabelColor: VJColors.gray500,
        indicatorColor: VJColors.primary,
        indicatorWeight: 3,
        labelStyle: VJTypography.labelLarge,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Pitch'),
          Tab(text: 'Insights'),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(VJSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Waveform
          VJCard(
            type: VJCardType.elevated,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Audio Waveform',
                      style: VJTypography.titleMedium.copyWith(
                        color: VJColors.gray900,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: VJColors.primary,
                      ),
                      onPressed: _togglePlayback,
                    ),
                  ],
                ),
                SizedBox(height: VJSpacing.md),
                VJWaveVisualizer(
                  audioData: widget.audioData,
                  style: WaveStyle.smooth,
                  height: 100,
                  color: VJColors.primary,
                  isPlaying: _isPlaying,
                  playbackPosition: _playbackPosition,
                ),
              ],
            ),
          ),
          
          SizedBox(height: VJSpacing.lg),
          
          // Quick Stats
          Text(
            'Performance Metrics',
            style: VJTypography.titleLarge.copyWith(
              color: VJColors.gray900,
            ),
          ),
          SizedBox(height: VJSpacing.md),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: VJSpacing.md,
            mainAxisSpacing: VJSpacing.md,
            childAspectRatio: 1.5,
            children: [
              VJStatCard(
                title: 'Pitch Stability',
                value: '${_calculateStability()}%',
                icon: Icons.graphic_eq,
                iconColor: VJColors.secondary,
              ),
              VJStatCard(
                title: 'Note Range',
                value: _calculateRange(),
                icon: Icons.straighten,
                iconColor: VJColors.accent,
              ),
              VJStatCard(
                title: 'Vibrato',
                value: _detectVibrato(),
                icon: Icons.waves,
                iconColor: VJColors.primary,
              ),
              VJStatCard(
                title: 'Confidence',
                value: '${_calculateConfidence()}%',
                icon: Icons.psychology,
                iconColor: VJColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPitchTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(VJSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main pitch graph
          VJCard(
            type: VJCardType.elevated,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pitch Tracking',
                  style: VJTypography.titleMedium.copyWith(
                    color: VJColors.gray900,
                  ),
                ),
                SizedBox(height: VJSpacing.md),
                VJPitchGraph(
                  pitchData: widget.pitchData,
                  height: 250,
                  showGuides: true,
                  targetPitch: 440.0, // A4
                  currentTime: _isPlaying ? _playbackPosition * widget.duration : null,
                ),
              ],
            ),
          ),
          
          SizedBox(height: VJSpacing.lg),
          
          // Note distribution
          VJCard(
            type: VJCardType.elevated,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Note Distribution',
                  style: VJTypography.titleMedium.copyWith(
                    color: VJColors.gray900,
                  ),
                ),
                SizedBox(height: VJSpacing.md),
                _buildNoteDistribution(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsTab() {
    final insights = _generateInsights();
    
    return ListView.builder(
      padding: EdgeInsets.all(VJSpacing.screenPadding),
      itemCount: insights.length,
      itemBuilder: (context, index) {
        final insight = insights[index];
        return Padding(
          padding: EdgeInsets.only(bottom: VJSpacing.md),
          child: VJCard(
            type: VJCardType.outlined,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: insight['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(VJSpacing.radiusSm),
                  ),
                  child: Icon(
                    insight['icon'],
                    color: insight['color'],
                    size: 20,
                  ),
                ),
                SizedBox(width: VJSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight['title'],
                        style: VJTypography.titleSmall.copyWith(
                          color: VJColors.gray900,
                        ),
                      ),
                      SizedBox(height: VJSpacing.xxs),
                      Text(
                        insight['description'],
                        style: VJTypography.bodyMedium.copyWith(
                          color: VJColors.gray600,
                        ),
                      ),
                      if (insight['action'] != null) ...[
                        SizedBox(height: VJSpacing.sm),
                        VJButton(
                          text: insight['action'],
                          type: VJButtonType.ghost,
                          size: VJButtonSize.small,
                          onPressed: () {},
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoteDistribution() {
    final noteCount = _countNotes();
    final maxCount = noteCount.values.isEmpty ? 1 : noteCount.values.reduce(math.max);
    
    return Column(
      children: noteCount.entries.map((entry) {
        final percentage = entry.value / maxCount;
        return Padding(
          padding: EdgeInsets.only(bottom: VJSpacing.sm),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  entry.key,
                  style: VJTypography.labelMedium.copyWith(
                    color: VJColors.gray700,
                  ),
                ),
              ),
              SizedBox(width: VJSpacing.sm),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: VJColors.gray100,
                        borderRadius: BorderRadius.circular(VJSpacing.radiusXs),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percentage,
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: VJColors.primaryGradient,
                          borderRadius: BorderRadius.circular(VJSpacing.radiusXs),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: VJSpacing.sm),
              Text(
                '${entry.value}',
                style: VJTypography.labelMedium.copyWith(
                  color: VJColors.gray700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Helper methods
  int _calculateNotesHit() {
    return widget.pitchData.where((p) => p.confidence > 0.7).length;
  }

  int _calculateStability() {
    if (widget.pitchData.isEmpty) return 0;
    final stablePoints = widget.pitchData.where((p) => p.confidence > 0.8).length;
    return (stablePoints / widget.pitchData.length * 100).round();
  }

  String _calculateRange() {
    if (widget.pitchData.isEmpty) return 'N/A';
    final notes = widget.pitchData.map((p) => p.note).where((n) => n != null).toSet();
    return '${notes.length} notes';
  }

  String _detectVibrato() {
    // Simplified vibrato detection
    return 'Minimal';
  }

  int _calculateConfidence() {
    if (widget.pitchData.isEmpty) return 0;
    final avgConfidence = widget.pitchData.map((p) => p.confidence).reduce((a, b) => a + b) / widget.pitchData.length;
    return (avgConfidence * 100).round();
  }

  Map<String, int> _countNotes() {
    final noteCount = <String, int>{};
    for (final point in widget.pitchData) {
      if (point.note != null && point.confidence > 0.5) {
        noteCount[point.note!] = (noteCount[point.note!] ?? 0) + 1;
      }
    }
    return noteCount;
  }

  List<Map<String, dynamic>> _generateInsights() {
    return [
      {
        'title': 'Great Pitch Accuracy!',
        'description': 'Your pitch accuracy is above 90%. Keep up the excellent work!',
        'icon': Icons.emoji_events,
        'color': VJColors.success,
        'action': null,
      },
      {
        'title': 'Breath Support',
        'description': 'Try to maintain more consistent airflow for steadier pitch.',
        'icon': Icons.air,
        'color': VJColors.warning,
        'action': 'Practice Breathing',
      },
      {
        'title': 'Vibrato Development',
        'description': 'Consider adding controlled vibrato to longer notes.',
        'icon': Icons.waves,
        'color': VJColors.info,
        'action': 'Learn Vibrato',
      },
    ];
  }

  void _togglePlayback() async {
    if (_isPlaying) {
      // Stop playback
      await _audioService.stopPlayback();
      _playbackController.stop();
      setState(() {
        _isPlaying = false;
      });
    } else {
      // Start playback
      final success = await _audioService.playAudio();
      if (success) {
        setState(() {
          _isPlaying = true;
        });
        _playbackController.forward(from: 0.0);
        // Stop when complete
        _playbackController.addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            setState(() {
              _isPlaying = false;
              _playbackPosition = 0.0;
            });
            _playbackController.reset();
          }
        });
      }
    }
  }

  void _shareResults() {
    // Implement share functionality
  }
}