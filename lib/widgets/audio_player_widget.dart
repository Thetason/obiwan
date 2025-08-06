import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/native_audio_service.dart';

class AudioPlayerWidget extends StatefulWidget {
  final List<double> audioData;
  final Duration duration;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final VoidCallback? onStop;
  final VoidCallback? onAnalyze; // 분석하기 버튼 콜백
  final VoidCallback? onReRecord; // 다시 녹음 콜백

  const AudioPlayerWidget({
    super.key,
    required this.audioData,
    required this.duration,
    this.onPlay,
    this.onPause,
    this.onStop,
    this.onAnalyze,
    this.onReRecord,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget>
    with TickerProviderStateMixin {
  
  bool _isPlaying = false;
  double _currentPosition = 0.0; // 0.0 to 1.0
  late AnimationController _playController;
  late Animation<double> _playAnimation;
  final NativeAudioService _nativeAudioService = NativeAudioService.instance;

  @override
  void initState() {
    super.initState();
    
    _playController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _playAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _playController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _playController.dispose();
    super.dispose();
  }

  void _togglePlayPause() async {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    
    if (_isPlaying) {
      _playController.forward();
      widget.onPlay?.call();
      
      // 실제 네이티브 오디오 재생
      final success = await _nativeAudioService.playAudio();
      if (success) {
        print('🔊 [AudioPlayer] 실제 오디오 재생 시작');
        _startProgressTracking();
      } else {
        print('❌ [AudioPlayer] 오디오 재생 실패');
        setState(() {
          _isPlaying = false;
        });
        _playController.reverse();
      }
    } else {
      _playController.reverse();
      widget.onPause?.call();
      
      // 실제 네이티브 오디오 일시정지
      await _nativeAudioService.pauseAudio();
      print('⏸️ [AudioPlayer] 실제 오디오 일시정지');
    }
  }

  void _startProgressTracking() {
    // 실제 재생 시간에 따른 진행바 업데이트
    if (_isPlaying && mounted) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _isPlaying) {
          setState(() {
            _currentPosition += 0.01; // 실제로는 실제 재생 위치를 가져와야 함
            if (_currentPosition >= 1.0) {
              _currentPosition = 1.0;
              _isPlaying = false;
              _playController.reverse();
              _nativeAudioService.stopAudio();
            }
          });
          _startProgressTracking();
        }
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5EA), // iOS 회색 배경
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 헤더
          _buildHeader(),
          
          const SizedBox(height: 24),
          
          // 웨이브폼 시각화
          _buildWaveform(),
          
          const SizedBox(height: 24),
          
          // 재생 시간 표시
          _buildTimeLabels(),
          
          const SizedBox(height: 32),
          
          // 컨트롤 버튼들
          _buildControls(),
          
          const SizedBox(height: 24),
          
          // 하단 액션 버튼들
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          children: [
            // iOS 스타일 완료 버튼
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Text(
                '완료',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF007AFF),
                ),
              ),
            ),
            const Spacer(),
            // 공유 버튼
            GestureDetector(
              onTap: () {},
              child: Icon(
                Icons.ios_share,
                color: Color(0xFF007AFF),
                size: 24,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // 제목
        Text(
          '음성 메모',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        // 날짜 시간
        Text(
          '${DateTime.now().year}년 ${DateTime.now().month}월 ${DateTime.now().day}일 오${DateTime.now().hour >= 12 ? '후' : '전'} ${DateTime.now().hour > 12 ? DateTime.now().hour - 12 : DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[600],
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildWaveform() {
    return Container(
      height: 120,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTapDown: (TapDownDetails details) async {
          // 웨이브폼 터치로 위치 이동
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final localPosition = renderBox.globalToLocal(details.globalPosition);
          final containerWidth = renderBox.size.width - 32; // 마진 제외
          final relativeX = localPosition.dx - 16; // 마진 오프셋
          
          if (relativeX >= 0 && relativeX <= containerWidth) {
            final newPosition = (relativeX / containerWidth).clamp(0.0, 1.0);
            setState(() {
              _currentPosition = newPosition;
            });
            
            // 실제 오디오 위치 이동
            await _nativeAudioService.seekAudio(newPosition);
            print('🎯 [AudioPlayer] 웨이브폼 터치로 위치 이동: $newPosition');
          }
        },
        onPanUpdate: (DragUpdateDetails details) async {
          // 드래그로 위치 이동
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final localPosition = renderBox.globalToLocal(details.globalPosition);
          final containerWidth = renderBox.size.width - 32;
          final relativeX = localPosition.dx - 16;
          
          if (relativeX >= 0 && relativeX <= containerWidth) {
            final newPosition = (relativeX / containerWidth).clamp(0.0, 1.0);
            setState(() {
              _currentPosition = newPosition;
            });
            
            // 실제 오디오 위치 이동
            await _nativeAudioService.seekAudio(newPosition);
          }
        },
        child: CustomPaint(
          painter: WaveformPainter(
            audioData: widget.audioData,
            currentPosition: _currentPosition,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeLabels() {
    final currentTime = Duration(
      milliseconds: (widget.duration.inMilliseconds * _currentPosition).round(),
    );
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _formatDuration(currentTime),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            _formatDuration(widget.duration),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 15초 뒤로 (iOS 스타일)
        GestureDetector(
          onTap: () async {
            final newPosition = math.max(0.0, _currentPosition - 0.15);
            setState(() {
              _currentPosition = newPosition;
            });
            
            // 실제 오디오 위치 이동
            await _nativeAudioService.seekAudio(newPosition);
            print('⏪ [AudioPlayer] 15초 뒤로 이동: $newPosition');
          },
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.replay,
                  color: Colors.grey[800],
                  size: 20,
                ),
                Positioned(
                  bottom: 8,
                  child: Text(
                    '15',
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(width: 24),
        
        // 재생/일시정지 버튼
        GestureDetector(
          onTap: _togglePlayPause,
          child: AnimatedBuilder(
            animation: _playAnimation,
            builder: (context, child) {
              return Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      key: ValueKey(_isPlaying),
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        const SizedBox(width: 32),
        
        // 15초 앞으로 (iOS 스타일)
        GestureDetector(
          onTap: () async {
            final newPosition = math.min(1.0, _currentPosition + 0.15);
            setState(() {
              _currentPosition = newPosition;
            });
            
            // 실제 오디오 위치 이동
            await _nativeAudioService.seekAudio(newPosition);
            print('⏩ [AudioPlayer] 15초 앞으로 이동: $newPosition');
          },
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.fast_forward,
                  color: Colors.grey[800],
                  size: 20,
                ),
                Positioned(
                  bottom: 8,
                  child: Text(
                    '15',
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.grey[700],
          size: 24,
        ),
      ),
    );
  }
  
  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 대치 버튼 (빨간색)
          GestureDetector(
            onTap: () {
              // 대치 기능 (다시 녹음)
              widget.onReRecord?.call();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '대치',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          // 다듬기 버튼
          GestureDetector(
            onTap: () {
              // 편집 기능
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '다듬기',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          // 완료 버튼 (파란색)
          GestureDetector(
            onTap: () {
              // 완료 - AI 분석 시작
              widget.onAnalyze?.call();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '완료',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> audioData;
  final double currentPosition;

  WaveformPainter({
    required this.audioData,
    required this.currentPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (audioData.isEmpty) {
      print('📊 [WaveformPainter] 오디오 데이터가 비어있음');
      return;
    }
    
    print('📊 [WaveformPainter] 오디오 데이터 길이: ${audioData.length}, 캔버스 크기: ${size.width}x${size.height}');

    final paint = Paint()
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    const int numBars = 150; // 화면에 표시할 바의 개수
    final double barWidth = size.width / numBars;
    final int samplesPerBar = (audioData.length / numBars).ceil();
    
    print('📊 [WaveformPainter] 바 개수: $numBars, 바당 샘플: $samplesPerBar');

    // 오디오 데이터를 다운샘플링하여 웨이브폼 생성
    for (int i = 0; i < numBars; i++) {
      final x = i * barWidth + barWidth / 2;
      
      // 해당 구간의 RMS 값 계산
      double rms = 0.0;
      int startIdx = i * samplesPerBar;
      int endIdx = math.min(startIdx + samplesPerBar, audioData.length);
      
      if (startIdx < audioData.length) {
        double sum = 0.0;
        for (int j = startIdx; j < endIdx; j++) {
          sum += audioData[j] * audioData[j];
        }
        rms = math.sqrt(sum / (endIdx - startIdx));
        
        // RMS 값을 증폭하여 더 잘 보이게 함
        rms = (rms * 10.0).clamp(0.0, 1.0);
      }
      
      final barHeight = rms * (size.height * 0.9); // 높이 증가
      
      // 재생 위치에 따른 색상 변경
      final isPlayed = (i / numBars) <= currentPosition;
      paint.color = isPlayed ? Color(0xFF007AFF) : Colors.grey[400]!;

      // 바 그리기 (최소 높이 보장)
      final minHeight = 2.0;
      final actualHeight = math.max(barHeight, minHeight);
      
      canvas.drawLine(
        Offset(x, centerY - actualHeight / 2),
        Offset(x, centerY + actualHeight / 2),
        paint,
      );
    }

    // 현재 위치 인디케이터 (iOS 스타일)
    final indicatorX = size.width * currentPosition;
    final indicatorPaint = Paint()
      ..color = Color(0xFF007AFF)
      ..strokeWidth = 3;

    canvas.drawLine(
      Offset(indicatorX, 0),
      Offset(indicatorX, size.height),
      indicatorPaint,
    );
    
    // 인디케이터 상단에 작은 원 그리기
    canvas.drawCircle(
      Offset(indicatorX, 0),
      4,
      Paint()..color = Color(0xFF007AFF),
    );
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return currentPosition != oldDelegate.currentPosition ||
           audioData != oldDelegate.audioData;
  }
}