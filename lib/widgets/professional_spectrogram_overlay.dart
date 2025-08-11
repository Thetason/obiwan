import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../core/resource_manager.dart';

/// 프로페셔널 스펙트로그램 오버레이 - Logic Pro/Ableton Live 수준
/// 실시간 주파수 스펙트럼을 피치 그래프 위에 오버레이로 표시
class ProfessionalSpectrogramOverlay extends StatefulWidget {
  final List<double> audioData;
  final double sampleRate;
  final double timeRange;
  final double frequencyRange;
  final bool showHarmonics;
  final double opacity;
  final SpectrogramColorScheme colorScheme;
  
  const ProfessionalSpectrogramOverlay({
    super.key,
    required this.audioData,
    this.sampleRate = 44100.0,
    this.timeRange = 10.0,
    this.frequencyRange = 1000.0,
    this.showHarmonics = true,
    this.opacity = 0.8,
    this.colorScheme = SpectrogramColorScheme.medical,
  });

  @override
  State<ProfessionalSpectrogramOverlay> createState() => 
      _ProfessionalSpectrogramOverlayState();
}

class _ProfessionalSpectrogramOverlayState 
    extends State<ProfessionalSpectrogramOverlay>
    with TickerProviderStateMixin, ResourceManagerMixin {
  
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _pulseAnimation;
  
  List<List<double>> _spectrogramData = [];
  List<double> _currentSpectrum = [];
  int _currentColumn = 0;
  final int _fftSize = 2048;
  final int _spectrogramWidth = 400;
  final int _spectrogramHeight = 256;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeSpectrogram();
    _processAudioData();
  }
  
  void _initializeAnimations() {
    _animationController = registerAnimationController(
      duration: const Duration(milliseconds: 2000),
      debugName: 'SpectrogramAnimation',
    );
    
    _pulseController = registerAnimationController(
      duration: const Duration(milliseconds: 1500),
      debugName: 'SpectrogramPulse',
    )..repeat(reverse: true);
    
    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: widget.opacity,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
  }
  
  void _initializeSpectrogram() {
    _spectrogramData = List.generate(
      _spectrogramWidth,
      (_) => List.filled(_spectrogramHeight, 0.0),
    );
  }
  
  void _processAudioData() async {
    if (!mounted || widget.audioData.isEmpty) return;
    
    try {
      final int hopSize = _fftSize ~/ 4;
      final int totalChunks = math.min(
        (widget.audioData.length - _fftSize) ~/ hopSize,
        50 // 최대 처리 청크 제한으로 성능 향상
      );
    
    // 배치 처리로 성능 향상
    const int batchSize = 4;
    for (int batchStart = 0; batchStart < totalChunks; batchStart += batchSize) {
      final List<Future<List<double>>> batchFutures = [];
      
      // 배치 내 각 청크를 병렬 처리
      for (int j = 0; j < batchSize && (batchStart + j) < totalChunks; j++) {
        final int i = (batchStart + j) * hopSize;
        if (i + _fftSize <= widget.audioData.length) {
          final chunk = widget.audioData.sublist(i, i + _fftSize);
          batchFutures.add(_performOptimizedFFT(chunk));
        }
      }
      
      // 배치 결과 처리
      final batchResults = await Future.wait(batchFutures);
      for (final spectrum in batchResults) {
        if (spectrum.isNotEmpty) {
          _updateSpectrogram(spectrum);
        }
      }
      
        // 주기적으로만 UI 업데이트 (30 FPS로 제한)
        if (mounted && batchStart % 4 == 0) { // 업데이트 빈도 줄임
          setState(() {});
          await Future.delayed(const Duration(milliseconds: 33)); // ~30 FPS
        }
      }
    } catch (e) {
      debugPrint('Audio processing error: $e');
      if (mounted) {
        setState(() {
          _spectrogramData = List.generate(
            _spectrogramWidth,
            (_) => List.filled(_spectrogramHeight, 0.0),
          );
        });
      }
    }
  }
  
  /// 성능 최적화된 FFT - 임계값 기반 처리
  Future<List<double>> _performOptimizedFFT(List<double> audioChunk) async {
    final int N = audioChunk.length;
    final List<double> magnitudes = List.filled(N ~/ 2, 0.0);
    
    // 먼저 에너지 레벨 체크 - 무음 구간은 건너뛰기
    double energy = 0;
    for (final sample in audioChunk) {
      energy += sample * sample;
    }
    energy /= audioChunk.length;
    
    // 에너지 임계값 이하면 계산 생략
    if (energy < 1e-6) {
      return magnitudes; // 모두 0인 배열 반환
    }
    
    // Radix-2 FFT 최적화 (power of 2인 경우만)
    if (_isPowerOfTwo(N)) {
      return _radix2FFT(audioChunk);
    }
    
    // 일반 DFT (최적화된 버전)
    return _optimizedDFT(audioChunk, magnitudes, N);
  }
  
  /// Radix-2 FFT (빠른 경우)
  List<double> _radix2FFT(List<double> audioChunk) {
    final int N = audioChunk.length;
    final List<double> real = List.from(audioChunk);
    final List<double> imag = List.filled(N, 0.0);
    
    // Bit-reversal
    _bitReversal(real, imag, N);
    
    // Cooley-Tukey FFT
    for (int len = 2; len <= N; len <<= 1) {
      final int halfLen = len >> 1;
      final double angle = -2 * math.pi / len;
      
      for (int i = 0; i < N; i += len) {
        for (int j = 0; j < halfLen; j++) {
          final int u = i + j;
          final int v = i + j + halfLen;
          
          final double cos_val = math.cos(angle * j);
          final double sin_val = math.sin(angle * j);
          
          final double t_real = cos_val * real[v] - sin_val * imag[v];
          final double t_imag = cos_val * imag[v] + sin_val * real[v];
          
          real[v] = real[u] - t_real;
          imag[v] = imag[u] - t_imag;
          real[u] = real[u] + t_real;
          imag[u] = imag[u] + t_imag;
        }
      }
    }
    
    // 크기 스펙트럼 계산
    final List<double> magnitudes = List.filled(N ~/ 2, 0.0);
    for (int i = 0; i < N ~/ 2; i++) {
      magnitudes[i] = math.sqrt(real[i] * real[i] + imag[i] * imag[i]);
      // 로그 스케일링
      magnitudes[i] = math.log(magnitudes[i] + 1.0) / math.log(10000.0);
      magnitudes[i] = magnitudes[i].clamp(0.0, 1.0);
    }
    
    return magnitudes;
  }
  
  /// 최적화된 DFT (일반 경우)
  List<double> _optimizedDFT(List<double> audioChunk, List<double> magnitudes, int N) {
    // 주파수 도메인에서 중요한 부분만 계산 (1/4만)
    final int relevantBins = N ~/ 8; // 고주파 부분은 생략
    
    for (int k = 0; k < relevantBins; k++) {
      double real = 0, imag = 0;
      
      // 벡터화된 내적 계산 (4개씩 처리)
      for (int n = 0; n < N - 4; n += 4) {
        final double angle_base = -2 * math.pi * k / N;
        
        final double angle0 = angle_base * n;
        final double angle1 = angle_base * (n + 1);
        final double angle2 = angle_base * (n + 2);
        final double angle3 = angle_base * (n + 3);
        
        real += audioChunk[n] * math.cos(angle0) +
                audioChunk[n + 1] * math.cos(angle1) +
                audioChunk[n + 2] * math.cos(angle2) +
                audioChunk[n + 3] * math.cos(angle3);
                
        imag += audioChunk[n] * math.sin(angle0) +
                audioChunk[n + 1] * math.sin(angle1) +
                audioChunk[n + 2] * math.sin(angle2) +
                audioChunk[n + 3] * math.sin(angle3);
      }
      
      magnitudes[k] = math.sqrt(real * real + imag * imag);
    }
    
    // 로그 스케일링 및 정규화 (벡터화)
    for (int i = 0; i < relevantBins; i++) {
      magnitudes[i] = math.log(magnitudes[i] + 1.0) / math.log(10000.0);
      magnitudes[i] = magnitudes[i].clamp(0.0, 1.0);
    }
    
    return magnitudes;
  }
  
  /// Bit-reversal (FFT 전처리)
  void _bitReversal(List<double> real, List<double> imag, int N) {
    int j = 0;
    for (int i = 1; i < N - 1; i++) {
      int bit = N >> 1;
      while (j >= bit) {
        j -= bit;
        bit >>= 1;
      }
      j += bit;
      
      if (i < j) {
        // Swap
        double temp = real[i];
        real[i] = real[j];
        real[j] = temp;
        
        temp = imag[i];
        imag[i] = imag[j];
        imag[j] = temp;
      }
    }
  }
  
  /// Power of 2 체크
  bool _isPowerOfTwo(int n) {
    return n > 0 && (n & (n - 1)) == 0;
  }
  
  void _updateSpectrogram(List<double> spectrum) {
    if (_currentColumn >= _spectrogramWidth) {
      // 왼쪽으로 시프트
      for (int col = 1; col < _spectrogramWidth; col++) {
        _spectrogramData[col - 1] = List.from(_spectrogramData[col]);
      }
      _currentColumn = _spectrogramWidth - 1;
    }
    
    // 새로운 스펙트럼 데이터 추가
    for (int row = 0; row < _spectrogramHeight; row++) {
      final int spectrumIndex = 
          (row * spectrum.length / _spectrogramHeight).floor();
      if (spectrumIndex < spectrum.length) {
        _spectrogramData[_currentColumn][row] = spectrum[spectrumIndex];
      }
    }
    
    _currentSpectrum = spectrum;
    _currentColumn++;
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_fadeInAnimation, _pulseAnimation]),
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _getSchemeColor(0.8).withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // 메인 스펙트로그램
                Opacity(
                  opacity: _fadeInAnimation.value,
                  child: CustomPaint(
                    painter: SpectrogramPainter(
                      spectrogramData: _spectrogramData,
                      currentSpectrum: _currentSpectrum,
                      colorScheme: widget.colorScheme,
                      showHarmonics: widget.showHarmonics,
                      pulseScale: _pulseAnimation.value,
                    ),
                    child: Container(),
                  ),
                ),
                
                // 주파수 격자선
                _buildFrequencyGrid(),
                
                // 시간 격자선
                _buildTimeGrid(),
                
                // 하모닉스 표시 (옵션)
                if (widget.showHarmonics) _buildHarmonicsOverlay(),
                
                // 현재 위치 인디케이터
                _buildCurrentPositionIndicator(),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildFrequencyGrid() {
    return CustomPaint(
      painter: FrequencyGridPainter(
        frequencyRange: widget.frequencyRange,
        colorScheme: widget.colorScheme,
      ),
      child: Container(),
    );
  }
  
  Widget _buildTimeGrid() {
    return CustomPaint(
      painter: TimeGridPainter(
        timeRange: widget.timeRange,
        colorScheme: widget.colorScheme,
      ),
      child: Container(),
    );
  }
  
  Widget _buildHarmonicsOverlay() {
    return CustomPaint(
      painter: HarmonicsOverlayPainter(
        currentSpectrum: _currentSpectrum,
        sampleRate: widget.sampleRate,
        colorScheme: widget.colorScheme,
      ),
      child: Container(),
    );
  }
  
  Widget _buildCurrentPositionIndicator() {
    return Positioned(
      right: 20,
      top: 0,
      bottom: 0,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _getSchemeColor(1.0),
                    _getSchemeColor(0.8),
                    _getSchemeColor(1.0),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _getSchemeColor(0.6),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Color _getSchemeColor(double intensity) {
    switch (widget.colorScheme) {
      case SpectrogramColorScheme.medical:
        return Color.lerp(
          const Color(0xFF1a4d5f),
          const Color(0xFF00ffff),
          intensity,
        )!;
      case SpectrogramColorScheme.fire:
        return Color.lerp(
          const Color(0xFF000000),
          const Color(0xFFff0000),
          intensity,
        )!;
      case SpectrogramColorScheme.rainbow:
        final hue = (intensity * 240).clamp(0.0, 240.0);
        return HSVColor.fromAHSV(1.0, hue, 1.0, intensity).toColor();
      case SpectrogramColorScheme.monochrome:
        return Color.lerp(
          const Color(0xFF000000),
          const Color(0xFFffffff),
          intensity,
        )!;
    }
  }
  
  @override
  void dispose() {
    // ResourceManagerMixin이 모든 AnimationController를 자동으로 정리함
    super.dispose();
  }
}

/// 최적화된 스펙트로그램 페인터 - 임계값 기반 렌더링
class SpectrogramPainter extends CustomPainter {
  final List<List<double>> spectrogramData;
  final List<double> currentSpectrum;
  final SpectrogramColorScheme colorScheme;
  final bool showHarmonics;
  final double pulseScale;
  
  // 성능 최적화를 위한 캐시
  static final Map<String, Paint> _paintCache = {};
  static const double _minIntensityThreshold = 0.05; // 렌더링 임계값
  static const double _glowThreshold = 0.8; // 글로우 효과 임계값
  
  SpectrogramPainter({
    required this.spectrogramData,
    required this.currentSpectrum,
    required this.colorScheme,
    required this.showHarmonics,
    required this.pulseScale,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (spectrogramData.isEmpty) return;
    
    final pixelWidth = size.width / spectrogramData.length;
    final pixelHeight = size.height / spectrogramData[0].length;
    
    // 렌더링 최적화: 시야각 컬링
    final visibleColumns = _getVisibleColumns(size);
    final visibleRows = _getVisibleRows(size);
    
    // 배치 렌더링: 같은 색상끼리 묶어서 처리
    final Map<String, List<Rect>> colorBatches = {};
    
    // 스펙트로그램 렌더링 (임계값 기반)
    for (int col = visibleColumns.start; col < visibleColumns.end && col < spectrogramData.length; col++) {
      for (int row = visibleRows.start; row < visibleRows.end && row < spectrogramData[col].length; row++) {
        final intensity = spectrogramData[col][row];
        
        // 임계값 이하는 렌더링 생략
        if (intensity <= _minIntensityThreshold) continue;
        
        final rect = Rect.fromLTWH(
          col * pixelWidth,
          size.height - (row + 1) * pixelHeight,
          pixelWidth,
          pixelHeight,
        );
        
        // 색상 키로 배치 그룹핑
        final colorKey = _getColorKey(intensity, colorScheme);
        colorBatches[colorKey] ??= [];
        colorBatches[colorKey]!.add(rect);
      }
    }
    
    // 배치별 렌더링 (드로우콜 최소화)
    colorBatches.forEach((colorKey, rects) {
      final paint = _getCachedPaint(colorKey, colorScheme);
      for (final rect in rects) {
        canvas.drawRect(rect, paint);
      }
    });
    
    // 고강도 영역 글로우 효과 (별도 패스)
    _renderGlowEffects(canvas, size, pixelWidth, pixelHeight, visibleColumns, visibleRows);
    
    // 현재 스펙트럼 실시간 표시
    if (currentSpectrum.isNotEmpty) {
      _drawRealtimeSpectrum(canvas, size);
    }
  }
  
  /// 시야각 컬링 - 보이는 열만 계산
  ({int start, int end}) _getVisibleColumns(Size size) {
    // 현재는 모든 열을 렌더링하지만, 향후 스크롤 가능한 뷰에서 최적화 가능
    return (start: 0, end: spectrogramData.length);
  }
  
  /// 시야각 컬링 - 보이는 행만 계산  
  ({int start, int end}) _getVisibleRows(Size size) {
    return (start: 0, end: spectrogramData.isNotEmpty ? spectrogramData[0].length : 0);
  }
  
  /// 글로우 효과 별도 렌더링
  void _renderGlowEffects(Canvas canvas, Size size, double pixelWidth, double pixelHeight, 
                         ({int start, int end}) visibleColumns, ({int start, int end}) visibleRows) {
    final glowPaint = Paint()..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0 * pulseScale);
    
    for (int col = visibleColumns.start; col < visibleColumns.end && col < spectrogramData.length; col++) {
      for (int row = visibleRows.start; row < visibleRows.end && row < spectrogramData[col].length; row++) {
        final intensity = spectrogramData[col][row];
        
        if (intensity > _glowThreshold) {
          glowPaint.color = _getColorForIntensity(intensity, colorScheme);
          
          final rect = Rect.fromLTWH(
            col * pixelWidth,
            size.height - (row + 1) * pixelHeight,
            pixelWidth,
            pixelHeight,
          );
          
          canvas.drawRect(rect, glowPaint);
        }
      }
    }
  }
  
  /// 색상 키 생성 (배치 그룹핑용)
  String _getColorKey(double intensity, SpectrogramColorScheme scheme) {
    // 강도를 16단계로 양자화하여 배치 그룹핑
    final quantizedIntensity = (intensity * 16).round();
    return '${scheme.name}_$quantizedIntensity';
  }
  
  /// 캐시된 Paint 객체 가져오기
  Paint _getCachedPaint(String colorKey, SpectrogramColorScheme scheme) {
    if (_paintCache.containsKey(colorKey)) {
      return _paintCache[colorKey]!;
    }
    
    // 키에서 강도 추출
    final parts = colorKey.split('_');
    final quantizedIntensity = int.parse(parts[1]);
    final intensity = quantizedIntensity / 16.0;
    
    final paint = Paint()
      ..color = _getColorForIntensity(intensity, scheme)
      ..style = PaintingStyle.fill;
    
    _paintCache[colorKey] = paint;
    return paint;
  }
  
  void _drawRealtimeSpectrum(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    final path = Path();
    for (int i = 0; i < currentSpectrum.length; i++) {
      final x = size.width - 50;  // 오른쪽에서 50픽셀 떨어진 곳
      final y = size.height - (i / currentSpectrum.length * size.height);
      final intensity = currentSpectrum[i];
      
      if (intensity > 0.1) {
        paint.color = _getColorForIntensity(intensity, colorScheme);
        final width = intensity * 40;  // 최대 40픽셀 폭
        
        canvas.drawLine(
          Offset(x, y),
          Offset(x + width, y),
          paint,
        );
      }
    }
  }
  
  Color _getColorForIntensity(double intensity, SpectrogramColorScheme scheme) {
    switch (scheme) {
      case SpectrogramColorScheme.medical:
        if (intensity < 0.3) return const Color(0xFF0a2a35);
        if (intensity < 0.6) return const Color(0xFF1a5f73);
        if (intensity < 0.8) return const Color(0xFF2d8ba3);
        return const Color(0xFF00ffff);
        
      case SpectrogramColorScheme.fire:
        if (intensity < 0.25) return const Color(0xFF1a0000);
        if (intensity < 0.5) return const Color(0xFF660000);
        if (intensity < 0.75) return const Color(0xFFcc3300);
        return const Color(0xFFffff00);
        
      case SpectrogramColorScheme.rainbow:
        final hue = (intensity * 240).clamp(0.0, 240.0);
        return HSVColor.fromAHSV(1.0, hue, 1.0, intensity).toColor();
        
      case SpectrogramColorScheme.monochrome:
        final gray = (intensity * 255).round();
        return Color.fromRGBO(gray, gray, gray, 1.0);
    }
  }
  
  @override
  bool shouldRepaint(SpectrogramPainter oldDelegate) {
    return oldDelegate.spectrogramData != spectrogramData ||
           oldDelegate.currentSpectrum != currentSpectrum ||
           oldDelegate.pulseScale != pulseScale;
  }
}

/// 주파수 격자선 페인터
class FrequencyGridPainter extends CustomPainter {
  final double frequencyRange;
  final SpectrogramColorScheme colorScheme;
  
  FrequencyGridPainter({
    required this.frequencyRange,
    required this.colorScheme,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _getGridColor().withOpacity(0.3)
      ..strokeWidth = 0.5;
    
    // 주파수 격자선 (로그 스케일)
    final frequencies = [100, 200, 440, 800, 1600];  // 중요한 주파수들
    
    for (final freq in frequencies) {
      if (freq <= frequencyRange) {
        final y = size.height - (math.log(freq) / math.log(frequencyRange) * size.height);
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          paint,
        );
      }
    }
  }
  
  Color _getGridColor() {
    switch (colorScheme) {
      case SpectrogramColorScheme.medical:
        return const Color(0xFF00ffff);
      case SpectrogramColorScheme.fire:
        return const Color(0xFFff6600);
      case SpectrogramColorScheme.rainbow:
        return const Color(0xFFffffff);
      case SpectrogramColorScheme.monochrome:
        return const Color(0xFF888888);
    }
  }
  
  @override
  bool shouldRepaint(FrequencyGridPainter oldDelegate) => false;
}

/// 시간 격자선 페인터  
class TimeGridPainter extends CustomPainter {
  final double timeRange;
  final SpectrogramColorScheme colorScheme;
  
  TimeGridPainter({
    required this.timeRange,
    required this.colorScheme,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _getGridColor().withOpacity(0.2)
      ..strokeWidth = 0.5;
    
    // 1초 간격으로 세로선
    final timeInterval = 1.0;
    final pixelsPerSecond = size.width / timeRange;
    
    for (double time = 0; time <= timeRange; time += timeInterval) {
      final x = time * pixelsPerSecond;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }
  
  Color _getGridColor() {
    switch (colorScheme) {
      case SpectrogramColorScheme.medical:
        return const Color(0xFF00ffff);
      case SpectrogramColorScheme.fire:
        return const Color(0xFFff6600);
      case SpectrogramColorScheme.rainbow:
        return const Color(0xFFffffff);
      case SpectrogramColorScheme.monochrome:
        return const Color(0xFF888888);
    }
  }
  
  @override
  bool shouldRepaint(TimeGridPainter oldDelegate) => false;
}

/// 하모닉스 오버레이 페인터
class HarmonicsOverlayPainter extends CustomPainter {
  final List<double> currentSpectrum;
  final double sampleRate;
  final SpectrogramColorScheme colorScheme;
  
  HarmonicsOverlayPainter({
    required this.currentSpectrum,
    required this.sampleRate,
    required this.colorScheme,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (currentSpectrum.isEmpty) return;
    
    // 기본 주파수 찾기
    final fundamentalFreq = _findFundamentalFrequency();
    if (fundamentalFreq > 0) {
      final paint = Paint()
        ..color = _getHarmonicColor().withOpacity(0.6)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      
      // 하모닉스 그리기 (2차, 3차, 4차 배음)
      for (int harmonic = 2; harmonic <= 4; harmonic++) {
        final harmonicFreq = fundamentalFreq * harmonic;
        if (harmonicFreq < sampleRate / 2) {
          final y = size.height - (math.log(harmonicFreq) / math.log(sampleRate / 2) * size.height);
          
          // 하모닉 라인 그리기
          canvas.drawLine(
            Offset(0, y),
            Offset(size.width, y),
            paint,
          );
          
          // 하모닉 번호 표시
          final textPainter = TextPainter(
            text: TextSpan(
              text: '${harmonic}H',
              style: TextStyle(
                color: _getHarmonicColor(),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(canvas, Offset(5, y - 15));
        }
      }
    }
  }
  
  double _findFundamentalFrequency() {
    // 간단한 기본 주파수 감지 (피크 찾기)
    double maxMagnitude = 0;
    int maxIndex = 0;
    
    for (int i = 1; i < currentSpectrum.length; i++) {
      if (currentSpectrum[i] > maxMagnitude) {
        maxMagnitude = currentSpectrum[i];
        maxIndex = i;
      }
    }
    
    if (maxMagnitude > 0.1) {
      return (maxIndex * sampleRate) / (2 * currentSpectrum.length);
    }
    
    return 0;
  }
  
  Color _getHarmonicColor() {
    switch (colorScheme) {
      case SpectrogramColorScheme.medical:
        return const Color(0xFFffff00);
      case SpectrogramColorScheme.fire:
        return const Color(0xFFffffff);
      case SpectrogramColorScheme.rainbow:
        return const Color(0xFFff00ff);
      case SpectrogramColorScheme.monochrome:
        return const Color(0xFFcccccc);
    }
  }
  
  @override
  bool shouldRepaint(HarmonicsOverlayPainter oldDelegate) {
    return oldDelegate.currentSpectrum != currentSpectrum;
  }
}

/// 스펙트로그램 색상 스킴
enum SpectrogramColorScheme {
  medical,    // 의료 장비 스타일 (시안-블루)
  fire,       // 파이어 스펙트럼 (검정-빨강-노랑)
  rainbow,    // 무지개 스펙트럼
  monochrome, // 흑백
}