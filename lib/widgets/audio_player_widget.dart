import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import '../services/native_audio_service.dart';
import '../services/dual_engine_service.dart';
import '../models/analysis_result.dart';

class AudioPlayerWidget extends StatefulWidget {
  final List<double> audioData;
  final Duration duration;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final VoidCallback? onStop;
  final Function(List<DualResult>?)? onAnalyze; // 시간별 분석 결과와 함께 호출
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
  
  // AI 분석 관련
  final DualEngineService _dualEngine = DualEngineService();
  bool _isAnalyzing = false;
  bool _isTimeBasedAnalyzing = false;
  DualResult? _analysisResult;
  List<DualResult>? _timeBasedResults;
  String _analysisStatus = '분석 준비 중...';

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
    
    // 위젯 로드 시 백그라운드 AI 분석 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBackgroundAnalysis();
    });
  }

  /// 백그라운드 AI 분석 시작
  void _startBackgroundAnalysis() async {
    if (_isAnalyzing) return;
    
    setState(() {
      _isAnalyzing = true;
      _analysisStatus = 'CREPE + SPICE 엔진 분석 중...';
    });
    
    try {
      // List<double>를 Float32List로 변환
      final audioFloat32 = Float32List.fromList(widget.audioData);
      
      // 엔진 상태 확인
      setState(() {
        _analysisStatus = '엔진 상태 확인 중...';
      });
      
      final status = await _dualEngine.checkStatus();
      print('🤖 [AI] 엔진 상태: ${status.statusText}');
      
      if (!status.anyHealthy) {
        setState(() {
          _analysisStatus = 'AI 서버 오프라인 - 로컬 분석 모드';
          _isAnalyzing = false;
        });
        _performLocalAnalysis(audioFloat32);
        return;
      }
      
      // 듀얼 엔진 분석 실행
      setState(() {
        _analysisStatus = '듀얼 엔진 보컬 분석 중...';
      });
      
      final result = await _dualEngine.analyzeDual(audioFloat32);
      
      if (mounted) {
        setState(() {
          _analysisResult = result;
          _isAnalyzing = false;
          if (result != null) {
            _analysisStatus = '분석 완료! (${result.recommendedEngine})';
          } else {
            _analysisStatus = '분석 실패 - 로컬 모드';
            _performLocalAnalysis(audioFloat32);
          }
        });
      }
      
    } catch (e) {
      print('❌ [AI] 분석 오류: $e');
      if (mounted) {
        setState(() {
          _analysisStatus = '오류 발생 - 로컬 분석으로 전환';
          _isAnalyzing = false;
        });
        _performLocalAnalysis(Float32List.fromList(widget.audioData));
      }
    }
  }
  
  /// 로컬 분석 (AI 서버 없을 때 대안)
  void _performLocalAnalysis(Float32List audioData) {
    // 간단한 로컬 피치 분석
    final sampleRate = 48000.0;
    final windowSize = 2048;
    final frequencies = <double>[];
    
    for (int i = 0; i < audioData.length - windowSize; i += windowSize ~/ 2) {
      final window = audioData.sublist(i, i + windowSize);
      final freq = _estimatePitch(window, sampleRate);
      if (freq > 80 && freq < 2000) { // 일반적인 보컬 범위
        frequencies.add(freq);
      }
    }
    
    if (frequencies.isNotEmpty) {
      final avgFreq = frequencies.reduce((a, b) => a + b) / frequencies.length;
      final confidence = math.min(1.0, frequencies.length / 100.0);
      
      // 로컬 결과 생성
      final localResult = DualResult(
        frequency: avgFreq,
        confidence: confidence,
        timestamp: DateTime.now(),
        crepeResult: null,
        spiceResult: null,
        recommendedEngine: 'Local',
        analysisQuality: confidence * 0.7,
      );
      
      setState(() {
        _analysisResult = localResult;
        _analysisStatus = '로컬 분석 완료 (${avgFreq.toStringAsFixed(1)} Hz)';
      });
    }
  }
  
  /// 간단한 피치 추정 (FFT 없이)
  double _estimatePitch(List<double> window, double sampleRate) {
    // Autocorrelation 기반 간단한 피치 추정
    final length = window.length;
    double maxCorr = 0.0;
    int bestLag = 0;
    
    for (int lag = 20; lag < length ~/ 3; lag++) {
      double corr = 0.0;
      for (int i = 0; i < length - lag; i++) {
        corr += window[i] * window[i + lag];
      }
      if (corr > maxCorr) {
        maxCorr = corr;
        bestLag = lag;
      }
    }
    
    return bestLag > 0 ? sampleRate / bestLag : 0.0;
  }
  
  /// 시간별 피치 분석 (AI 보컬 분석 시작 버튼용)
  Future<void> _performTimeBasedAnalysis() async {
    if (_isTimeBasedAnalyzing) return;
    
    print('🔍 [AudioPlayer] 시간별 분석 시작');
    print('🔍 [AudioPlayer] 오디오 데이터 크기: ${widget.audioData.length} 샘플');
    
    setState(() {
      _isTimeBasedAnalyzing = true;
      _analysisStatus = '시간별 피치 분석 중...';
    });
    
    try {
      // List<double>를 Float32List로 변환
      final audioFloat32 = Float32List.fromList(widget.audioData);
      print('🔍 [AudioPlayer] Float32List 변환 완료: ${audioFloat32.length} 샘플');
      
      // 엔진 상태 확인
      setState(() {
        _analysisStatus = 'CREPE + SPICE 엔진 상태 확인...';
      });
      
      final status = await _dualEngine.checkStatus();
      print('🤖 [AudioPlayer] 엔진 상태: ${status.statusText}');
      
      if (!status.anyHealthy) {
        print('❌ [AudioPlayer] AI 서버 오프라인');
        setState(() {
          _analysisStatus = 'AI 서버 오프라인 - 시간별 분석 불가';
          _isTimeBasedAnalyzing = false;
        });
        return;
      }
      
      // 시간별 피치 분석 실행 (타임아웃 설정)
      setState(() {
        _analysisStatus = '🎯 고정밀 단일 음정 분석 중... (SinglePitchTracker)';
      });
      
      print('🎯 [AudioPlayer] SinglePitchTracker 분석 시작 - 오디오 길이: ${audioFloat32.length} 샘플');
      
      // SinglePitchTracker를 사용한 고정밀 단일 음정 분석
      final timeBasedResults = await _dualEngine.analyzeSinglePitchAccurate(
        audioFloat32,
        windowSize: 24000,  // 0.5초 분량 (더 정확한 분석)
        hopSize: 6000,      // 0.125초 간격
        sampleRate: 48000.0,
      );
      
      print('🎯 [AudioPlayer] SinglePitchTracker 분석 완료! 결과: ${timeBasedResults.length}개');
      
      print('🔍 [AudioPlayer] 분석 결과: ${timeBasedResults.length}개');
      
      if (mounted) {
        setState(() {
          _timeBasedResults = timeBasedResults;
          _isTimeBasedAnalyzing = false;
          if (timeBasedResults.isNotEmpty) {
            _analysisStatus = '🎯 고정밀 단일 음정 분석 완료! (${timeBasedResults.length}개 구간)';
            print('✅ [AudioPlayer] SinglePitchTracker 분석 성공: ${timeBasedResults.length}개 결과');
          } else {
            _analysisStatus = '시간별 분석 실패 - 데이터 부족';
            print('⚠️ [AudioPlayer] 시간별 분석 실패 - 결과 없음');
          }
        });
      }
      
    } catch (e) {
      print('❌ [TimeBasedAnalysis] 분석 오류: $e');
      if (mounted) {
        setState(() {
          _analysisStatus = '시간별 분석 오류: $e';
          _isTimeBasedAnalyzing = false;
        });
      }
    }
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
        color: Colors.white, // 밝은 배경
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 헤더
          _buildHeader(),
          
          const SizedBox(height: 16),
          
          // AI 분석 상태 표시
          _buildAnalysisStatus(),
          
          const SizedBox(height: 16),
          
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
          
          // 완료 버튼 (파란색) - 시간별 분석 시작
          GestureDetector(
            onTap: () async {
              print('🔵 [AudioPlayer] AI 분석 버튼 클릭');
              
              // CREPE 분석을 기다리고 완료된 후 다음 단계로 진행
              if (_timeBasedResults == null && !_isTimeBasedAnalyzing) {
                print('🔵 [AudioPlayer] CREPE 분석 시작 - 완료까지 대기');
                
                // 분석 진행 상태 UI 업데이트
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('CREPE AI 분석 중... 잠시만 기다려주세요'),
                    duration: Duration(seconds: 8),
                  ),
                );
                
                // CREPE 분석을 실제로 기다림
                await _performTimeBasedAnalysis();
                
                // 분석 완료 후 결과 전달
                if (_timeBasedResults != null && _timeBasedResults!.isNotEmpty) {
                  print('✅ [AudioPlayer] CREPE 분석 완료 - 결과 전달: ${_timeBasedResults!.length}개');
                  widget.onAnalyze?.call(_timeBasedResults!);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('CREPE 분석 완료! ${_timeBasedResults!.length}개 구간 분석됨'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: const Color(0xFF34C759),
                    ),
                  );
                } else {
                  print('❌ [AudioPlayer] CREPE 분석 실패 - 기본 결과로 진행');
                  // 기본 분석 결과라도 전달
                  final fallbackResult = _analysisResult != null ? [_analysisResult!] : <DualResult>[];
                  widget.onAnalyze?.call(fallbackResult);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('CREPE 분석 실패 - 기본 분석으로 진행'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
                
              } else if (_timeBasedResults != null && !_isTimeBasedAnalyzing) {
                print('🔵 [AudioPlayer] 기존 CREPE 분석 결과 사용: ${_timeBasedResults!.length}개');
                widget.onAnalyze?.call(_timeBasedResults!);
              } else if (_isTimeBasedAnalyzing) {
                print('🔵 [AudioPlayer] CREPE 분석 진행 중 - 완료까지 대기');
                
                // 이미 진행 중인 분석 완료까지 대기
                while (_isTimeBasedAnalyzing && mounted) {
                  await Future.delayed(const Duration(milliseconds: 500));
                }
                
                if (_timeBasedResults != null && _timeBasedResults!.isNotEmpty) {
                  widget.onAnalyze?.call(_timeBasedResults!);
                } else {
                  final fallbackResult = _analysisResult != null ? [_analysisResult!] : <DualResult>[];
                  widget.onAnalyze?.call(fallbackResult);
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isTimeBasedAnalyzing 
                    ? 'CREPE 분석 중...' 
                    : (_timeBasedResults != null 
                        ? '보컬 트레이닝 시작 ✅' 
                        : 'CREPE AI 분석 시작'),
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
    
    // print('📊 [WaveformPainter] 오디오 데이터 길이: ${audioData.length}, 캔버스 크기: ${size.width}x${size.height}');

    final paint = Paint()
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    const int numBars = 150; // 화면에 표시할 바의 개수
    final double barWidth = size.width / numBars;
    final int samplesPerBar = (audioData.length / numBars).ceil();
    
    // print('📊 [WaveformPainter] 바 개수: $numBars, 바당 샘플: $samplesPerBar');

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

extension on _AudioPlayerWidgetState {
  /// AI 분석 상태 UI
  Widget _buildAnalysisStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isAnalyzing 
            ? const Color(0xFF007AFF).withOpacity(0.1)
            : (_analysisResult != null 
                ? const Color(0xFF34C759).withOpacity(0.1)
                : Colors.orange.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isAnalyzing 
              ? const Color(0xFF007AFF).withOpacity(0.3)
              : (_analysisResult != null 
                  ? const Color(0xFF34C759).withOpacity(0.3)
                  : Colors.orange.withOpacity(0.3)),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 분석 상태 아이콘
          (_isAnalyzing || _isTimeBasedAnalyzing) 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF007AFF),
                  ),
                )
              : Icon(
                  (_analysisResult != null || _timeBasedResults != null) ? Icons.check_circle : Icons.info_outline,
                  color: (_analysisResult != null || _timeBasedResults != null) 
                      ? const Color(0xFF34C759)
                      : Colors.orange,
                  size: 16,
                ),
          
          const SizedBox(width: 12),
          
          // 분석 상태 텍스트
          Expanded(
            child: Text(
              _analysisStatus,
              style: TextStyle(
                fontSize: 14,
                color: (_isAnalyzing || _isTimeBasedAnalyzing) 
                    ? const Color(0xFF007AFF)
                    : ((_analysisResult != null || _timeBasedResults != null) 
                        ? const Color(0xFF34C759)
                        : Colors.orange[700]),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // 분석 결과 미리보기 (완료시에만)
          if (_timeBasedResults != null && !_isTimeBasedAnalyzing) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_timeBasedResults!.length}개 구간',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF34C759),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ] else if (_analysisResult != null && !_isAnalyzing && _timeBasedResults == null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_analysisResult!.frequency.toStringAsFixed(1)} Hz',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF34C759),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}