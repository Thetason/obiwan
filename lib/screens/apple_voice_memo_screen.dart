import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../widgets/glassmorphism_card.dart';
import '../widgets/premium_button.dart';
import 'fixed_vocal_training_screen.dart';

class AppleVoiceMemoScreen extends StatefulWidget {
  final Float32List? audioData;
  final Duration recordingDuration;
  
  const AppleVoiceMemoScreen({
    super.key,
    this.audioData,
    required this.recordingDuration,
  });

  @override
  State<AppleVoiceMemoScreen> createState() => _AppleVoiceMemoScreenState();
}

class _AppleVoiceMemoScreenState extends State<AppleVoiceMemoScreen>
    with TickerProviderStateMixin {
  
  bool _isPlaying = false;
  double _playbackPosition = 0.0;
  
  // 애니메이션 컨트롤러들
  late AnimationController _playButtonController;
  late AnimationController _waveformController;
  late Animation<double> _playButtonAnimation;
  
  // 색상 테마
  final Color _primaryColor = const Color(0xFF6366F1);
  final Color _secondaryColor = const Color(0xFF8B5CF6);
  final Color _accentColor = const Color(0xFF10B981);
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }
  
  void _initializeAnimations() {
    _playButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _waveformController = AnimationController(
      duration: widget.recordingDuration,
      vsync: this,
    );
    
    _playButtonAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _playButtonController, curve: Curves.easeInOut),
    );
    
    // 플레이백 포지션 애니메이션
    _waveformController.addListener(() {
      setState(() {
        _playbackPosition = _waveformController.value;
      });
    });
    
    _waveformController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isPlaying = false;
        });
        _playButtonController.reverse();
      }
    });
  }
  
  void _togglePlayback() {
    if (_isPlaying) {
      _pausePlayback();
    } else {
      _startPlayback();
    }
  }
  
  void _startPlayback() {
    setState(() {
      _isPlaying = true;
    });
    _playButtonController.forward();
    _waveformController.forward();
  }
  
  void _pausePlayback() {
    setState(() {
      _isPlaying = false;
    });
    _playButtonController.reverse();
    _waveformController.stop();
  }
  
  void _seekTo(double position) {
    _waveformController.value = position;
    setState(() {
      _playbackPosition = position;
    });
  }
  
  @override
  void dispose() {
    _playButtonController.dispose();
    _waveformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0F0F23),
              const Color(0xFF1A1B23),
              _primaryColor.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 40),
                _buildWaveformCard(),
                const Spacer(),
                _buildActionButtons(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '녹음 완료',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '${widget.recordingDuration.inMinutes}:${(widget.recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildWaveformCard() {
    return GlassmorphismCard(
      child: Column(
        children: [
          // 재생 컨트롤
          Row(
            children: [
              // 재생/일시정지 버튼 (애플 스타일)
              AnimatedBuilder(
                animation: _playButtonAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _playButtonAnimation.value,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [_primaryColor, _secondaryColor],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(32),
                          onTap: _togglePlayback,
                          child: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(width: 20),
              
              // 시간 표시 및 파형
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 파형 시각화
                    Container(
                      height: 80,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: AppleWaveformPainter(
                          audioData: widget.audioData,
                          playbackPosition: _playbackPosition,
                          primaryColor: _primaryColor,
                          backgroundColor: Colors.white.withOpacity(0.2),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // 진행 바
                    GestureDetector(
                      onPanUpdate: (details) {
                        final width = context.size?.width ?? 300;
                        final position = (details.localPosition.dx / (width - 128)).clamp(0.0, 1.0);
                        _seekTo(position);
                      },
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: Colors.white.withOpacity(0.2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _playbackPosition,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: LinearGradient(
                                colors: [_primaryColor, _secondaryColor],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // 시간 표시
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTime(_playbackPosition * widget.recordingDuration.inSeconds),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        Text(
                          _formatTime(widget.recordingDuration.inSeconds.toDouble()),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons() {
    return Column(
      children: [
        // AI 분석 시작 버튼
        PremiumButton(
          text: 'AI 분석 시작',
          icon: Icons.auto_awesome,
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const FixedVocalTrainingScreen(),
              ),
            );
          },
          primaryColor: _accentColor,
          secondaryColor: const Color(0xFF059669),
          width: double.infinity,
          height: 60,
        ),
        
        const SizedBox(height: 16),
        
        Row(
          children: [
            // 다시 녹음
            Expanded(
              child: PremiumButton(
                text: '다시 녹음',
                icon: Icons.refresh,
                onPressed: () => Navigator.pop(context),
                primaryColor: Colors.white.withOpacity(0.1),
                secondaryColor: Colors.white.withOpacity(0.05),
                height: 50,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // 저장하기
            Expanded(
              child: PremiumButton(
                text: '저장하기',
                icon: Icons.save,
                onPressed: () {
                  // TODO: 저장 기능 구현
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('저장 기능은 곧 추가될 예정입니다')),
                  );
                },
                primaryColor: _secondaryColor.withOpacity(0.7),
                secondaryColor: _primaryColor.withOpacity(0.7),
                height: 50,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  String _formatTime(double seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = (seconds % 60).floor();
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

class AppleWaveformPainter extends CustomPainter {
  final Float32List? audioData;
  final double playbackPosition;
  final Color primaryColor;
  final Color backgroundColor;
  
  AppleWaveformPainter({
    required this.audioData,
    required this.playbackPosition,
    required this.primaryColor,
    required this.backgroundColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (audioData == null || audioData!.isEmpty) {
      // 더미 웨이브폼 그리기
      _drawDummyWaveform(canvas, size);
      return;
    }
    
    final paint = Paint()..strokeWidth = 2;
    final playedPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2;
    final unplayedPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 2;
    
    final barWidth = size.width / 100;
    final playbackX = size.width * playbackPosition;
    
    for (int i = 0; i < 100; i++) {
      final x = i * barWidth;
      final dataIndex = (i * audioData!.length / 100).floor();
      final amplitude = audioData![dataIndex].abs();
      final barHeight = amplitude * size.height * 0.8;
      
      final startY = (size.height - barHeight) / 2;
      final endY = startY + barHeight;
      
      // 재생된 부분과 재생되지 않은 부분 구분
      paint.color = x <= playbackX ? primaryColor : backgroundColor;
      
      canvas.drawLine(
        Offset(x + barWidth / 2, startY),
        Offset(x + barWidth / 2, endY),
        paint,
      );
    }
  }
  
  void _drawDummyWaveform(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 2;
    final barWidth = size.width / 100;
    final playbackX = size.width * playbackPosition;
    
    for (int i = 0; i < 100; i++) {
      final x = i * barWidth;
      // 더미 오디오 패턴 생성
      final amplitude = (0.3 + 0.4 * (i % 10) / 10);
      final barHeight = amplitude * size.height * 0.8;
      
      final startY = (size.height - barHeight) / 2;
      final endY = startY + barHeight;
      
      paint.color = x <= playbackX ? primaryColor : backgroundColor;
      
      canvas.drawLine(
        Offset(x + barWidth / 2, startY),
        Offset(x + barWidth / 2, endY),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}