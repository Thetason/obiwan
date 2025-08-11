import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:typed_data';

/// 프로페셔널 배음 분석기
/// 기본 주파수와 배음들을 시각적으로 분석하고 표시
class ProfessionalHarmonicsAnalyzer extends StatefulWidget {
  final List<double> audioData;
  final double sampleRate;
  final double fundamentalFrequency;
  final int maxHarmonics;
  final bool showFormants;
  final HarmonicsDisplayMode displayMode;
  final Color primaryColor;
  final Color harmonicColor;
  
  const ProfessionalHarmonicsAnalyzer({
    super.key,
    required this.audioData,
    this.sampleRate = 44100.0,
    this.fundamentalFrequency = 0.0,
    this.maxHarmonics = 8,
    this.showFormants = true,
    this.displayMode = HarmonicsDisplayMode.circular,
    this.primaryColor = const Color(0xFF00ff88),
    this.harmonicColor = const Color(0xFFffaa00),
  });

  @override
  State<ProfessionalHarmonicsAnalyzer> createState() => 
      _ProfessionalHarmonicsAnalyzerState();
}

class _ProfessionalHarmonicsAnalyzerState 
    extends State<ProfessionalHarmonicsAnalyzer>
    with TickerProviderStateMixin {
  
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _analysisController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _analysisAnimation;
  
  List<HarmonicData> _harmonics = [];
  List<FormantData> _formants = [];
  double _detectedFundamental = 0.0;
  List<double> _spectrum = [];
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _analyzeHarmonics();
  }
  
  @override
  void didUpdateWidget(ProfessionalHarmonicsAnalyzer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioData != widget.audioData || 
        oldWidget.fundamentalFrequency != widget.fundamentalFrequency) {
      _analyzeHarmonics();
    }
  }
  
  void _initializeAnimations() {
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 8000),
      vsync: this,
    )..repeat();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _analysisController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_rotationController);
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _analysisAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _analysisController,
      curve: Curves.elasticOut,
    ));
  }
  
  void _analyzeHarmonics() async {
    if (!mounted || widget.audioData.isEmpty) return;
    
    try {
      _analysisController.reset();
      _analysisController.forward();
    
    // FFT 수행
    _spectrum = _performFFT(widget.audioData);
    
    // 기본 주파수 찾기
    _detectedFundamental = widget.fundamentalFrequency > 0
        ? widget.fundamentalFrequency
        : _findFundamentalFrequency(_spectrum);
    
    // 배음 분석
    _harmonics = _analyzeHarmonicSeries(_spectrum, _detectedFundamental);
    
    // 포먼트 분석
    if (widget.showFormants) {
      _formants = _analyzeFormants(_spectrum);
    }
    
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error in _analyzeHarmonics: $e');
      if (mounted) {
        setState(() {
          _harmonics = [];
          _formants = [];
          _detectedFundamental = 0.0;
          _spectrum = [];
        });
      }
    }
  }
  
  List<double> _performFFT(List<double> audioData) {
    if (audioData.isEmpty) return [];
    
    // 크기 제한으로 성능 향상 (원래 8192에서 2048로 줄임)
    final int N = math.min(audioData.length, 2048);
    final List<double> magnitudes = List.filled(N ~/ 4, 0.0); // 더욱 축소
    
    try {
      // 윈도우 함수 적용 (Hanning window)
      final windowed = List<double>.generate(N, (i) {
        if (i < audioData.length) {
          final windowValue = 0.5 - 0.5 * math.cos(2 * math.pi * i / (N - 1));
          return audioData[i] * windowValue;
        }
        return 0.0;
      });
      
      // 간단한 DFT - 크기 축소로 성능 향상
      for (int k = 0; k < magnitudes.length && k < N ~/ 4; k++) {
        double real = 0, imag = 0;
        // 샘플링 간격을 늘려서 계산량 감소
        for (int n = 0; n < N; n += 2) { // 2칸씩 건너뛰며 계산
          final angle = -2 * math.pi * k * n / N;
          real += windowed[n] * math.cos(angle);
          imag += windowed[n] * math.sin(angle);
        }
        magnitudes[k] = math.sqrt(real * real + imag * imag);
      }
    } catch (e) {
      debugPrint('FFT calculation error: $e');
      return List.filled(N ~/ 4, 0.0);
    }
    
    return magnitudes;
  }
  
  double _findFundamentalFrequency(List<double> spectrum) {
    if (spectrum.isEmpty) return 0.0;
    
    // HPS (Harmonic Product Spectrum) 방법
    final hps = List<double>.from(spectrum);
    
    // 2차, 3차, 4차 배음 곱하기
    for (int harmonic = 2; harmonic <= 4; harmonic++) {
      for (int i = 0; i < hps.length ~/ harmonic; i++) {
        hps[i] *= spectrum[i * harmonic];
      }
    }
    
    // 최대값 찾기 (80Hz ~ 800Hz 범위)
    final minBin = (80 * spectrum.length * 2 / widget.sampleRate).round();
    final maxBin = (800 * spectrum.length * 2 / widget.sampleRate).round();
    
    double maxValue = 0;
    int maxIndex = minBin;
    
    for (int i = minBin; i < math.min(maxBin, hps.length); i++) {
      if (hps[i] > maxValue) {
        maxValue = hps[i];
        maxIndex = i;
      }
    }
    
    return maxIndex * widget.sampleRate / (2 * spectrum.length);
  }
  
  List<HarmonicData> _analyzeHarmonicSeries(List<double> spectrum, double fundamental) {
    if (fundamental <= 0 || spectrum.isEmpty) return [];
    
    final harmonics = <HarmonicData>[];
    
    for (int n = 1; n <= widget.maxHarmonics; n++) {
      final harmonicFreq = fundamental * n;
      final bin = (harmonicFreq * spectrum.length * 2 / widget.sampleRate).round();
      
      if (bin < spectrum.length) {
        // 주변 빈들의 평균으로 더 정확한 크기 계산
        double magnitude = 0;
        final range = 3;  // ±3 빈 범위
        int count = 0;
        
        for (int i = math.max(0, bin - range); 
             i <= math.min(spectrum.length - 1, bin + range); 
             i++) {
          magnitude += spectrum[i];
          count++;
        }
        magnitude /= count;
        
        // dB로 변환
        final magnitudeDB = magnitude > 0 ? 20 * math.log(magnitude) / math.log(10) : -100.0;
        
        harmonics.add(HarmonicData(
          harmonicNumber: n,
          frequency: harmonicFreq,
          magnitude: magnitude,
          magnitudeDB: magnitudeDB,
          phase: 0,  // 위상은 복잡한 계산이므로 생략
        ));
      }
    }
    
    // 크기로 정규화
    if (harmonics.isNotEmpty) {
      final maxMagnitude = harmonics.map((h) => h.magnitude).reduce(math.max);
      for (final harmonic in harmonics) {
        harmonic.normalizedMagnitude = harmonic.magnitude / maxMagnitude;
      }
    }
    
    return harmonics;
  }
  
  List<FormantData> _analyzeFormants(List<double> spectrum) {
    // 간단한 피크 찾기로 포먼트 추정
    final formants = <FormantData>[];
    final peaks = _findSpectralPeaks(spectrum);
    
    // 일반적인 모음 포먼트 범위에서 찾기
    final formantRanges = [
      [200, 1000],   // F1
      [800, 3000],   // F2
      [1500, 4000],  // F3
    ];
    
    for (int i = 0; i < formantRanges.length && i < 3; i++) {
      final range = formantRanges[i];
      final minFreq = range[0].toDouble();
      final maxFreq = range[1].toDouble();
      
      for (final peak in peaks) {
        final freq = peak['frequency'] as double;
        if (freq >= minFreq && freq <= maxFreq) {
          formants.add(FormantData(
            formantNumber: i + 1,
            frequency: freq,
            bandwidth: 100,  // 간단히 고정값 사용
            magnitude: peak['magnitude'] as double,
          ));
          break;
        }
      }
    }
    
    return formants;
  }
  
  List<Map<String, double>> _findSpectralPeaks(List<double> spectrum) {
    final peaks = <Map<String, double>>[];
    
    for (int i = 2; i < spectrum.length - 2; i++) {
      // 지역 최대값 찾기
      if (spectrum[i] > spectrum[i-1] && 
          spectrum[i] > spectrum[i+1] && 
          spectrum[i] > spectrum[i-2] && 
          spectrum[i] > spectrum[i+2]) {
        
        final frequency = i * widget.sampleRate / (2 * spectrum.length);
        if (frequency > 80 && frequency < 4000) {  // 관심 있는 주파수 범위
          peaks.add({
            'frequency': frequency,
            'magnitude': spectrum[i],
          });
        }
      }
    }
    
    // 크기 순으로 정렬
    peaks.sort((a, b) => (b['magnitude']!).compareTo(a['magnitude']!));
    
    return peaks.take(10).toList();  // 상위 10개 피크만 반환
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0a0a0a),
            Color(0xFF1a1a2e),
            Color(0xFF16213e),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: widget.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // 메인 배음 시각화
            AnimatedBuilder(
              animation: Listenable.merge([
                _rotationAnimation,
                _pulseAnimation,
                _analysisAnimation,
              ]),
              builder: (context, child) {
                return CustomPaint(
                  painter: HarmonicsVisualizerPainter(
                    harmonics: _harmonics,
                    formants: _formants,
                    fundamental: _detectedFundamental,
                    displayMode: widget.displayMode,
                    rotationAngle: _rotationAnimation.value,
                    pulseScale: _pulseAnimation.value,
                    analysisProgress: _analysisAnimation.value,
                    primaryColor: widget.primaryColor,
                    harmonicColor: widget.harmonicColor,
                    showFormants: widget.showFormants,
                  ),
                  child: Container(),
                );
              },
            ),
            
            // 정보 오버레이
            _buildInfoOverlay(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoOverlay() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Column(
        children: [
          // 기본 주파수 표시
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.primaryColor.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FUNDAMENTAL',
                  style: TextStyle(
                    color: widget.primaryColor.withOpacity(0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  '${_detectedFundamental.toStringAsFixed(1)} Hz',
                  style: TextStyle(
                    color: widget.primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 배음 강도 표시
          if (_harmonics.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _harmonics.take(4).map((harmonic) {
                  return Column(
                    children: [
                      Text(
                        'H${harmonic.harmonicNumber}',
                        style: TextStyle(
                          color: widget.harmonicColor,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        width: 20,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 20,
                            height: 40 * harmonic.normalizedMagnitude * _analysisAnimation.value,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  widget.harmonicColor,
                                  widget.harmonicColor.withOpacity(0.3),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _analysisController.dispose();
    super.dispose();
  }
}

/// 배음 시각화 페인터
class HarmonicsVisualizerPainter extends CustomPainter {
  final List<HarmonicData> harmonics;
  final List<FormantData> formants;
  final double fundamental;
  final HarmonicsDisplayMode displayMode;
  final double rotationAngle;
  final double pulseScale;
  final double analysisProgress;
  final Color primaryColor;
  final Color harmonicColor;
  final bool showFormants;
  
  HarmonicsVisualizerPainter({
    required this.harmonics,
    required this.formants,
    required this.fundamental,
    required this.displayMode,
    required this.rotationAngle,
    required this.pulseScale,
    required this.analysisProgress,
    required this.primaryColor,
    required this.harmonicColor,
    required this.showFormants,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    switch (displayMode) {
      case HarmonicsDisplayMode.circular:
        _drawCircularHarmonics(canvas, size, center);
        break;
      case HarmonicsDisplayMode.linear:
        _drawLinearHarmonics(canvas, size);
        break;
      case HarmonicsDisplayMode.radial:
        _drawRadialHarmonics(canvas, size, center);
        break;
    }
    
    if (showFormants) {
      _drawFormants(canvas, size, center);
    }
  }
  
  void _drawCircularHarmonics(Canvas canvas, Size size, Offset center) {
    if (harmonics.isEmpty) return;
    
    final radius = math.min(size.width, size.height) * 0.3;
    
    // 기본 주파수 원
    final fundamentalPaint = Paint()
      ..color = primaryColor.withOpacity(0.8)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    
    canvas.drawCircle(center, radius * 0.3 * pulseScale, fundamentalPaint);
    
    // 배음들을 원형으로 배치
    for (int i = 0; i < harmonics.length; i++) {
      final harmonic = harmonics[i];
      final angle = (i / harmonics.length * 2 * math.pi) + rotationAngle;
      final harmonicRadius = radius * (0.5 + harmonic.normalizedMagnitude * 0.4);
      
      final position = Offset(
        center.dx + math.cos(angle) * harmonicRadius,
        center.dy + math.sin(angle) * harmonicRadius,
      );
      
      // 배음 포인트
      final harmonicPaint = Paint()
        ..color = harmonicColor.withOpacity(harmonic.normalizedMagnitude * analysisProgress)
        ..style = PaintingStyle.fill;
      
      final pointSize = 3 + harmonic.normalizedMagnitude * 8;
      canvas.drawCircle(position, pointSize, harmonicPaint);
      
      // 기본 주파수와 연결선
      final connectionPaint = Paint()
        ..color = harmonicColor.withOpacity(0.3 * harmonic.normalizedMagnitude * analysisProgress)
        ..strokeWidth = 1;
      
      canvas.drawLine(center, position, connectionPaint);
      
      // 배음 번호 표시
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${harmonic.harmonicNumber}',
          style: TextStyle(
            color: harmonicColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, position - Offset(textPainter.width / 2, textPainter.height / 2));
    }
  }
  
  void _drawLinearHarmonics(Canvas canvas, Size size) {
    if (harmonics.isEmpty) return;
    
    final barWidth = size.width / harmonics.length;
    
    for (int i = 0; i < harmonics.length; i++) {
      final harmonic = harmonics[i];
      final x = i * barWidth;
      final barHeight = size.height * harmonic.normalizedMagnitude * analysisProgress;
      
      final rect = Rect.fromLTWH(
        x + barWidth * 0.1,
        size.height - barHeight,
        barWidth * 0.8,
        barHeight,
      );
      
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            harmonicColor,
            harmonicColor.withOpacity(0.3),
          ],
        ).createShader(rect);
      
      canvas.drawRect(rect, paint);
      
      // 주파수 라벨
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${harmonic.frequency.toStringAsFixed(0)}Hz',
          style: TextStyle(
            color: harmonicColor,
            fontSize: 8,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + barWidth / 2 - textPainter.width / 2, size.height - 15));
    }
  }
  
  void _drawRadialHarmonics(Canvas canvas, Size size, Offset center) {
    if (harmonics.isEmpty) return;
    
    final maxRadius = math.min(size.width, size.height) * 0.4;
    
    for (final harmonic in harmonics) {
      final angle = (harmonic.harmonicNumber - 1) * 2 * math.pi / 8 + rotationAngle;  // 8개 배음 기준
      final radius = maxRadius * harmonic.normalizedMagnitude * analysisProgress;
      
      final endPoint = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      
      // 방사형 라인
      final paint = Paint()
        ..color = harmonicColor.withOpacity(harmonic.normalizedMagnitude)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(center, endPoint, paint);
      
      // 끝점에 원
      final pointPaint = Paint()
        ..color = harmonicColor
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(endPoint, 4, pointPaint);
    }
  }
  
  void _drawFormants(Canvas canvas, Size size, Offset center) {
    if (formants.isEmpty) return;
    
    final formantPaint = Paint()
      ..color = primaryColor.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    for (int i = 0; i < formants.length; i++) {
      final formant = formants[i];
      final radius = 30 + i * 20;  // F1, F2, F3 순서로 반지름 증가
      
      canvas.drawCircle(center, radius.toDouble(), formantPaint);
      
      // 포먼트 라벨
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'F${formant.formantNumber}',
          style: TextStyle(
            color: primaryColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(center.dx + radius + 5, center.dy - textPainter.height / 2));
    }
  }
  
  @override
  bool shouldRepaint(HarmonicsVisualizerPainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle ||
           oldDelegate.pulseScale != pulseScale ||
           oldDelegate.analysisProgress != analysisProgress ||
           oldDelegate.harmonics.length != harmonics.length;
  }
}

/// 배음 데이터 클래스
class HarmonicData {
  final int harmonicNumber;
  final double frequency;
  final double magnitude;
  final double magnitudeDB;
  final double phase;
  double normalizedMagnitude = 0.0;
  
  HarmonicData({
    required this.harmonicNumber,
    required this.frequency,
    required this.magnitude,
    required this.magnitudeDB,
    required this.phase,
  });
}

/// 포먼트 데이터 클래스
class FormantData {
  final int formantNumber;
  final double frequency;
  final double bandwidth;
  final double magnitude;
  
  const FormantData({
    required this.formantNumber,
    required this.frequency,
    required this.bandwidth,
    required this.magnitude,
  });
}

/// 배음 표시 모드
enum HarmonicsDisplayMode {
  circular,  // 원형 배치
  linear,    // 선형 막대 그래프
  radial,    // 방사형 배치
}