  Widget _buildAnalysisStep() {
    // Nike-style accuracy calculation
    final accuracy = _currentFrequency > 0 && _currentFrequency < 500 
        ? ((_currentFrequency - 440).abs() < 50 ? 0.9 
        : (_currentFrequency - 440).abs() < 100 ? 0.7 
        : 0.5)
        : 0.0;
    
    return Container(
      key: const ValueKey('analysis'),
      decoration: BoxDecoration(
        gradient: PitchColors.nikeBackground(),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nike-style compact metrics header
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      PitchColors.cardDark.withOpacity(0.8),
                      PitchColors.cardAccent.withOpacity(0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: PitchColors.electricBlue.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNikeMetric(
                      'FREQUENCY',
                      '${_currentFrequency.toStringAsFixed(1)}',
                      'Hz',
                      PitchColors.electricBlue,
                    ),
                    _buildNikeMetric(
                      'ACCURACY',
                      '${(accuracy * 100).toStringAsFixed(0)}',
                      '%',
                      PitchColors.fromAccuracy(accuracy),
                    ),
                    _buildNikeMetric(
                      'PROGRESS',
                      '${_currentPitchIndex}',
                      '/${_pitchData.length}',
                      Colors.white70,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // HERO ELEMENT: Nike-style pitch graph (70% of screen)
              Expanded(
                flex: 7,
                child: _pitchData.isNotEmpty 
                  ? RealtimePitchGraph(
                      pitchData: _pitchData,
                      isPlaying: _isPlaying,
                      currentTime: _currentPlaybackTime,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: PitchColors.nikeBackground(),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: PitchColors.electricBlue.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    PitchColors.electricBlue,
                                    PitchColors.neonGreen,
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.analytics_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'ANALYZING PITCH',
                              style: TextStyle(
                                color: PitchColors.electricBlue,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'SF Pro Display',
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_pitchData.length} DATA POINTS',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ),
              
              const SizedBox(height: 16),
              
              // BOTTOM: Compact Nike-style pitch bar (20% height)
              Expanded(
                flex: 2,
                child: PitchBarVisualizer(
                  currentPitch: _currentFrequency,
                  targetPitch: 440.0,
                  confidence: _currentConfidence,
                  isActive: _isPlaying,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }