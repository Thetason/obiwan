import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../models/pitch_point.dart';

/// 홀로그래픽 3D 피치 공간 시각화
/// 깊이감과 입체적 효과로 피치 변화를 3D로 표현
class Holographic3DPitchVisualizer extends StatefulWidget {
  final List<PitchPoint> pitchData;
  final double width;
  final double height;
  final bool enableParticleEffects;
  final Color primaryColor;
  final Color accentColor;
  final double rotationSpeed;
  
  const Holographic3DPitchVisualizer({
    super.key,
    required this.pitchData,
    this.width = 400,
    this.height = 300,
    this.enableParticleEffects = true,
    this.primaryColor = const Color(0xFF00ffff),
    this.accentColor = const Color(0xFFff00ff),
    this.rotationSpeed = 1.0,
  });

  @override
  State<Holographic3DPitchVisualizer> createState() => 
      _Holographic3DPitchVisualizerState();
}

class _Holographic3DPitchVisualizerState 
    extends State<Holographic3DPitchVisualizer>
    with TickerProviderStateMixin {
  
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _particleAnimation;
  
  List<Particle3D> _particles = [];
  double _cameraAngleX = 0;
  double _cameraAngleY = 0;
  double _zoom = 1.0;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeParticles();
  }
  
  void _initializeAnimations() {
    _rotationController = AnimationController(
      duration: Duration(milliseconds: (8000 / widget.rotationSpeed).round()),
      vsync: this,
    )..repeat();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();
    
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
    
    _particleAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_particleController);
  }
  
  void _initializeParticles() {
    if (!widget.enableParticleEffects) return;
    
    final random = math.Random();
    _particles = List.generate(50, (index) {
      return Particle3D(
        x: (random.nextDouble() - 0.5) * 400,
        y: (random.nextDouble() - 0.5) * 300,
        z: (random.nextDouble() - 0.5) * 200,
        velocityX: (random.nextDouble() - 0.5) * 2,
        velocityY: (random.nextDouble() - 0.5) * 2,
        velocityZ: (random.nextDouble() - 0.5) * 2,
        size: random.nextDouble() * 3 + 1,
        life: random.nextDouble(),
      );
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
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
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GestureDetector(
          onPanUpdate: _handlePanUpdate,
          onScaleUpdate: _handleScaleUpdate,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _rotationAnimation,
              _pulseAnimation,
              _particleAnimation,
            ]),
            builder: (context, child) {
              return Stack(
                children: [
                  // 배경 그리드
                  _buildBackground3DGrid(),
                  
                  // 메인 3D 피치 경로
                  CustomPaint(
                    painter: Holographic3DPitchPainter(
                      pitchData: widget.pitchData,
                      rotationX: _cameraAngleX,
                      rotationY: _cameraAngleY + _rotationAnimation.value,
                      zoom: _zoom * _pulseAnimation.value,
                      primaryColor: widget.primaryColor,
                      accentColor: widget.accentColor,
                    ),
                    child: Container(),
                  ),
                  
                  // 파티클 효과
                  if (widget.enableParticleEffects)
                    CustomPaint(
                      painter: Particle3DPainter(
                        particles: _particles,
                        rotationX: _cameraAngleX,
                        rotationY: _cameraAngleY + _rotationAnimation.value,
                        zoom: _zoom,
                        animationValue: _particleAnimation.value,
                        primaryColor: widget.primaryColor,
                      ),
                      child: Container(),
                    ),
                  
                  // 홀로그래픽 스캔라인 효과
                  _buildHolographicScanlines(),
                  
                  // 피치 정보 오버레이
                  _buildPitchInfoOverlay(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
  
  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _cameraAngleX += details.delta.dy * 0.01;
      _cameraAngleY += details.delta.dx * 0.01;
      
      // 각도 제한
      _cameraAngleX = _cameraAngleX.clamp(-math.pi / 2, math.pi / 2);
    });
  }
  
  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _zoom = (_zoom * details.scale).clamp(0.5, 3.0);
    });
  }
  
  Widget _buildBackground3DGrid() {
    return CustomPaint(
      painter: Background3DGridPainter(
        rotationX: _cameraAngleX,
        rotationY: _cameraAngleY + _rotationAnimation.value,
        zoom: _zoom,
        gridColor: widget.primaryColor.withOpacity(0.2),
      ),
      child: Container(),
    );
  }
  
  Widget _buildHolographicScanlines() {
    return AnimatedBuilder(
      animation: _particleAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                widget.primaryColor.withOpacity(0.1 * math.sin(_particleAnimation.value * 2 * math.pi)),
                Colors.transparent,
              ],
              stops: [0.0, _particleAnimation.value, 1.0],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildPitchInfoOverlay() {
    if (widget.pitchData.isEmpty) return Container();
    
    final currentPitch = widget.pitchData.last;
    return Positioned(
      top: 20,
      left: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.primaryColor.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.primaryColor.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FREQUENCY',
              style: TextStyle(
                color: widget.primaryColor.withOpacity(0.8),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              '${currentPitch.frequency.toStringAsFixed(1)} Hz',
              style: TextStyle(
                color: widget.primaryColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'NOTE',
              style: TextStyle(
                color: widget.accentColor.withOpacity(0.8),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              currentPitch.note,
              style: TextStyle(
                color: widget.accentColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }
}

/// 3D 피치 경로 페인터
class Holographic3DPitchPainter extends CustomPainter {
  final List<PitchPoint> pitchData;
  final double rotationX;
  final double rotationY;
  final double zoom;
  final Color primaryColor;
  final Color accentColor;
  
  Holographic3DPitchPainter({
    required this.pitchData,
    required this.rotationX,
    required this.rotationY,
    required this.zoom,
    required this.primaryColor,
    required this.accentColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (pitchData.isEmpty) return;
    
    try {
      // LOD (Level of Detail) 최적화 - 데이터 포인트 수에 따라 품질 조절
      final lodLevel = _calculateLOD(pitchData.length);
      final sampledData = _samplePitchData(pitchData, lodLevel);
    
    // 프리컴퓨팅된 변환 매트릭스 사용
    final transform = _precomputeTransform();
    
    // 3D 좌표계에서 2D로 투영 (배치 처리)
    final projectedPoints = _batchProject3DTo2D(sampledData, size, transform);
    
    // 가시성 컬링 - 화면 밖 포인트 제거
    final visiblePoints = _frustumCull(projectedPoints, size);
    
      // 렌더링 (깊이 정렬)
      _renderWithDepthSorting(canvas, visiblePoints, size);
    } catch (e) {
      debugPrint('3D rendering error: $e');
      // 에러 발생시 간단한 fallback 렌더링
      final paint = Paint()
        ..color = primaryColor
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(size.width * 0.1, size.height * 0.5),
        Offset(size.width * 0.9, size.height * 0.5),
        paint,
      );
    }
  }
  
  /// LOD 레벨 계산 - 데이터 양에 따라 품질 조절
  int _calculateLOD(int dataCount) {
    if (dataCount > 1000) return 4; // 1/4 샘플링
    if (dataCount > 500) return 2;  // 1/2 샘플링
    return 1; // 풀 품질
  }
  
  /// 데이터 샘플링 (LOD 적용)
  List<PitchPoint> _samplePitchData(List<PitchPoint> data, int lodLevel) {
    if (lodLevel == 1) return data;
    
    final sampledData = <PitchPoint>[];
    for (int i = 0; i < data.length; i += lodLevel) {
      sampledData.add(data[i]);
    }
    return sampledData;
  }
  
  /// 변환 매트릭스 사전 계산
  Matrix3D _precomputeTransform() {
    final cosX = _getCachedCos(rotationX);
    final sinX = _getCachedSin(rotationX);
    final cosY = _getCachedCos(rotationY);
    final sinY = _getCachedSin(rotationY);
    
    return Matrix3D(
      cosY, 0, -sinY,
      sinX * sinY, cosX, sinX * cosY,
      cosX * sinY, -sinX, cosX * cosY
    );
  }
  
  /// 배치 3D -> 2D 투영
  List<ProjectedPoint> _batchProject3DTo2D(List<PitchPoint> data, Size size, Matrix3D transform) {
    final projectedPoints = <ProjectedPoint>[];
    final centerX = size.width * 0.5;
    final centerY = size.height * 0.5;
    const perspective = 300.0;
    
    for (int i = 0; i < data.length; i++) {
      final point = data[i];
      final x3d = (i - data.length * 0.5) * 2;
      final y3d = (point.frequency - 300) * 0.5;
      final z3d = point.confidence * 100 - 50;
      
      // 매트릭스 변환 적용
      final transformed = transform.transform(x3d, y3d, z3d);
      final x1 = transformed.x;
      final y1 = transformed.y;
      final z2 = transformed.z;
      
      // 원근 투영
      final zOffset = perspective + z2;
      if (zOffset.abs() > 1e-6) {
        final invFactor = zoom / zOffset;
        
        projectedPoints.add(ProjectedPoint(
          x: centerX + x1 * invFactor,
          y: centerY - y1 * invFactor,
          z: z2,
          originalIndex: i,
          confidence: point.confidence,
        ));
      }
    }
    
    return projectedPoints;
  }
  
  /// 가시성 컬링 (프러스텀 컬링)
  List<ProjectedPoint> _frustumCull(List<ProjectedPoint> points, Size size) {
    const margin = 50.0; // 여유 마진
    return points.where((point) {
      return point.x >= -margin && point.x <= size.width + margin &&
             point.y >= -margin && point.y <= size.height + margin &&
             point.z > -1000; // 카메라 뒤편 제거
    }).toList();
  }
  
  /// 깊이 정렬 렌더링
  void _renderWithDepthSorting(Canvas canvas, List<ProjectedPoint> points, Size size) {
    // Z 버퍼 정렬 (뒤쪽부터 그리기)
    points.sort((a, b) => b.z.compareTo(a.z));
    
    // 배치 렌더링을 위한 그룹핑
    final highConfidencePoints = <ProjectedPoint>[];
    final lowConfidencePoints = <ProjectedPoint>[];
    
    for (final point in points) {
      if (point.confidence > 0.7) {
        highConfidencePoints.add(point);
      } else {
        lowConfidencePoints.add(point);
      }
    }
    
    // 메시 및 경로 그리기
    _drawOptimizedMesh(canvas, points);
    _drawOptimizedPath(canvas, points);
    
    // 포인트 그리기 (신뢰도별 배치 처리)
    _drawBatchedPoints(canvas, lowConfidencePoints, 0.5);
    _drawBatchedPoints(canvas, highConfidencePoints, 1.0);
    
    // 깊이 레이어 (캐시된 렌더링)
    _drawCachedDepthLayers(canvas, size);
  }
  
  /// 최적화된 메시 그리기
  void _drawOptimizedMesh(Canvas canvas, List<ProjectedPoint> points) {
    if (points.length < 2) return;
    
    final meshPaint = Paint()
      ..color = primaryColor.withOpacity(0.1)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    
    // 인접한 포인트들만 연결 (전체 연결 방지)
    for (int i = 0; i < points.length - 1; i += 2) { // 2개씩 건너뛰며 최적화
      canvas.drawLine(
        Offset(points[i].x, points[i].y),
        Offset(points[i + 1].x, points[i + 1].y),
        meshPaint,
      );
    }
  }
  
  /// 최적화된 경로 그리기
  void _drawOptimizedPath(Canvas canvas, List<ProjectedPoint> points) {
    if (points.length < 2) return;
    
    final path = Path();
    bool hasMoveTo = false;
    
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      
      if (!hasMoveTo) {
        path.moveTo(point.x, point.y);
        hasMoveTo = true;
      } else {
        path.lineTo(point.x, point.y);
      }
    }
    
    // 단일 드로우콜로 전체 경로 그리기
    final pathPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawPath(path, pathPaint);
  }
  
  /// 배치 포인트 그리기
  void _drawBatchedPoints(Canvas canvas, List<ProjectedPoint> points, double alphaMultiplier) {
    if (points.isEmpty) return;
    
    final pointPaint = Paint()
      ..color = accentColor.withOpacity(0.8 * alphaMultiplier)
      ..style = PaintingStyle.fill;
    
    // 모든 포인트를 한 번에 그리기
    for (final point in points) {
      canvas.drawCircle(
        Offset(point.x, point.y),
        4 * point.confidence * alphaMultiplier,
        pointPaint,
      );
    }
  }
  
  /// 캐시된 깊이 레이어 그리기
  void _drawCachedDepthLayers(Canvas canvas, Size size) {
    // 정적 레이어는 캐시하여 재사용
    _cachedDepthLayers ??= _generateDepthLayers(size);
    
    for (final layer in _cachedDepthLayers!) {
      canvas.drawRect(layer.rect, layer.paint);
    }
  }
  
  static List<DepthLayer>? _cachedDepthLayers;
  
  List<DepthLayer> _generateDepthLayers(Size size) {
    final layers = <DepthLayer>[];
    
    for (int i = 0; i < 3; i++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = primaryColor.withOpacity(0.1 - i * 0.03);
      
      final rect = Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.5),
        width: size.width * (0.8 - i * 0.1),
        height: size.height * (0.8 - i * 0.1),
      );
      
      layers.add(DepthLayer(rect: rect, paint: paint));
    }
    
    return layers;
  }
  
  /// 최적화된 3D 변환 - 삼각함수 캐싱 및 매트릭스 연산
  Offset _project3DTo2D(double x, double y, double z, Size size) {
    // 삼각함수 값 캐싱 (프레임마다 재계산 방지)
    final cosX = _getCachedCos(rotationX);
    final sinX = _getCachedSin(rotationX);
    final cosY = _getCachedCos(rotationY);
    final sinY = _getCachedSin(rotationY);
    
    // 3x3 회전 행렬 곱셈 최적화
    final x1 = x * cosY - z * sinY;
    final z1 = x * sinY + z * cosY;
    final y1 = y * cosX - z1 * sinX;
    final z2 = y * sinX + z1 * cosX;
    
    // 최적화된 원근 투영 (나눗셈 최소화)
    final perspective = 300.0;
    final zOffset = perspective + z2;
    
    // 0 나눗셈 방지
    if (zOffset.abs() < 1e-6) {
      return Offset(size.width * 0.5, size.height * 0.5);
    }
    
    final invFactor = zoom / zOffset;
    
    return Offset(
      size.width * 0.5 + x1 * invFactor,
      size.height * 0.5 - y1 * invFactor,
    );
  }
  
  // 삼각함수 캐시 (각도별)
  static final Map<String, double> _trigCache = {};
  
  double _getCachedCos(double angle) {
    final key = 'cos_${(angle * 1000).toInt()}'; // 정밀도를 위해 1000배
    return _trigCache[key] ??= math.cos(angle);
  }
  
  double _getCachedSin(double angle) {
    final key = 'sin_${(angle * 1000).toInt()}';
    return _trigCache[key] ??= math.sin(angle);
  }
  
  void _drawMesh(Canvas canvas, List<Offset> points) {
    if (points.length < 2) return;
    
    final meshPaint = Paint()
      ..color = primaryColor.withOpacity(0.1)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    
    // 세로 메시 라인
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], meshPaint);
    }
    
    // 가로 메시 라인 (가상의 그리드)
    final gridPaint = Paint()
      ..color = primaryColor.withOpacity(0.05)
      ..strokeWidth = 0.3
      ..style = PaintingStyle.stroke;
    
    for (int i = 0; i < points.length; i += 5) {
      if (i < points.length) {
        final topPoint = Offset(points[i].dx, points[i].dy - 50);
        final bottomPoint = Offset(points[i].dx, points[i].dy + 50);
        canvas.drawLine(topPoint, bottomPoint, gridPaint);
      }
    }
  }
  
  void _drawPitchPath(Canvas canvas, List<Offset> points) {
    if (points.length < 2) return;
    
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    
    // 메인 패스 그리기
    final pathPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawPath(path, pathPaint);
    
    // 글로우 효과
    final glowPaint = Paint()
      ..color = primaryColor.withOpacity(0.5)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    
    canvas.drawPath(path, glowPaint);
  }
  
  void _drawPitchPoints(Canvas canvas, List<Offset> points) {
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final confidence = pitchData[i].confidence;
      
      if (confidence > 0.7) {
        // 고신뢰도 포인트
        final pointPaint = Paint()
          ..color = accentColor
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(point, 4 * confidence, pointPaint);
        
        // 외부 링
        final ringPaint = Paint()
          ..color = primaryColor.withOpacity(0.8)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        
        canvas.drawCircle(point, 6 * confidence, ringPaint);
      }
    }
  }
  
  void _drawDepthLayers(Canvas canvas, Size size) {
    // 3개의 깊이 레이어 그리기
    final layerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    for (int layer = 0; layer < 3; layer++) {
      layerPaint.color = primaryColor.withOpacity(0.1 - layer * 0.03);
      
      final rect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * (0.8 - layer * 0.1),
        height: size.height * (0.8 - layer * 0.1),
      );
      
      canvas.drawRect(rect, layerPaint);
    }
  }
  
  @override
  bool shouldRepaint(Holographic3DPitchPainter oldDelegate) {
    return oldDelegate.rotationX != rotationX ||
           oldDelegate.rotationY != rotationY ||
           oldDelegate.zoom != zoom ||
           oldDelegate.pitchData.length != pitchData.length;
  }
}

/// 3D 배경 그리드 페인터
class Background3DGridPainter extends CustomPainter {
  final double rotationX;
  final double rotationY;
  final double zoom;
  final Color gridColor;
  
  Background3DGridPainter({
    required this.rotationX,
    required this.rotationY,
    required this.zoom,
    required this.gridColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    
    final center = Offset(size.width / 2, size.height / 2);
    final gridSize = 20.0;
    
    // XZ 평면 그리드
    for (int i = -10; i <= 10; i++) {
      final x1 = _project3DTo2D(i * gridSize, 0, -200, size);
      final x2 = _project3DTo2D(i * gridSize, 0, 200, size);
      canvas.drawLine(x1, x2, paint);
      
      final z1 = _project3DTo2D(-200, 0, i * gridSize, size);
      final z2 = _project3DTo2D(200, 0, i * gridSize, size);
      canvas.drawLine(z1, z2, paint);
    }
  }
  
  Offset _project3DTo2D(double x, double y, double z, Size size) {
    final cosX = math.cos(rotationX);
    final sinX = math.sin(rotationX);
    final cosY = math.cos(rotationY);
    final sinY = math.sin(rotationY);
    
    final x1 = x * cosY - z * sinY;
    final z1 = x * sinY + z * cosY;
    final y1 = y * cosX - z1 * sinX;
    final z2 = y * sinX + z1 * cosX;
    
    final perspective = 300.0;
    final factor = perspective / (perspective + z2);
    
    return Offset(
      size.width / 2 + x1 * zoom * factor,
      size.height / 2 - y1 * zoom * factor,
    );
  }
  
  @override
  bool shouldRepaint(Background3DGridPainter oldDelegate) {
    return oldDelegate.rotationX != rotationX ||
           oldDelegate.rotationY != rotationY ||
           oldDelegate.zoom != zoom;
  }
}

/// 3D 파티클 페인터
class Particle3DPainter extends CustomPainter {
  final List<Particle3D> particles;
  final double rotationX;
  final double rotationY;
  final double zoom;
  final double animationValue;
  final Color primaryColor;
  
  Particle3DPainter({
    required this.particles,
    required this.rotationX,
    required this.rotationY,
    required this.zoom,
    required this.animationValue,
    required this.primaryColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    for (final particle in particles) {
      // 파티클 위치 업데이트
      particle.update(animationValue);
      
      // 3D to 2D 투영
      final projected = _project3DTo2D(
        particle.x, 
        particle.y, 
        particle.z, 
        size
      );
      
      // 파티클 그리기
      paint.color = primaryColor.withOpacity(particle.life * 0.8);
      canvas.drawCircle(projected, particle.size, paint);
      
      // 트레일 효과
      if (particle.previousPositions.isNotEmpty) {
        final trailPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        
        for (int i = 0; i < particle.previousPositions.length - 1; i++) {
          final alpha = (i / particle.previousPositions.length) * particle.life * 0.3;
          trailPaint.color = primaryColor.withOpacity(alpha);
          
          final start = _project3DTo2D(
            particle.previousPositions[i].x,
            particle.previousPositions[i].y,
            particle.previousPositions[i].z,
            size,
          );
          
          final end = _project3DTo2D(
            particle.previousPositions[i + 1].x,
            particle.previousPositions[i + 1].y,
            particle.previousPositions[i + 1].z,
            size,
          );
          
          canvas.drawLine(start, end, trailPaint);
        }
      }
    }
  }
  
  Offset _project3DTo2D(double x, double y, double z, Size size) {
    final cosX = math.cos(rotationX);
    final sinX = math.sin(rotationX);
    final cosY = math.cos(rotationY);
    final sinY = math.sin(rotationY);
    
    final x1 = x * cosY - z * sinY;
    final z1 = x * sinY + z * cosY;
    final y1 = y * cosX - z1 * sinX;
    final z2 = y * sinX + z1 * cosX;
    
    final perspective = 300.0;
    final factor = perspective / (perspective + z2);
    
    return Offset(
      size.width / 2 + x1 * zoom * factor,
      size.height / 2 - y1 * zoom * factor,
    );
  }
  
  @override
  bool shouldRepaint(Particle3DPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

/// 3D 파티클 클래스
class Particle3D {
  double x, y, z;
  double velocityX, velocityY, velocityZ;
  double size;
  double life;
  List<Vector3> previousPositions = [];
  
  Particle3D({
    required this.x,
    required this.y,
    required this.z,
    required this.velocityX,
    required this.velocityY,
    required this.velocityZ,
    required this.size,
    required this.life,
  });
  
  void update(double deltaTime) {
    // 이전 위치 저장
    if (previousPositions.length > 10) {
      previousPositions.removeAt(0);
    }
    previousPositions.add(Vector3(x, y, z));
    
    // 위치 업데이트
    x += velocityX * deltaTime;
    y += velocityY * deltaTime;
    z += velocityZ * deltaTime;
    
    // 생명 감소
    life -= 0.01;
    if (life <= 0) {
      // 파티클 재시작
      final random = math.Random();
      x = (random.nextDouble() - 0.5) * 400;
      y = (random.nextDouble() - 0.5) * 300;
      z = (random.nextDouble() - 0.5) * 200;
      life = 1.0;
      previousPositions.clear();
    }
  }
}

/// 3D 벡터 클래스
class Vector3 {
  final double x, y, z;
  
  const Vector3(this.x, this.y, this.z);
}

/// 3D 변환 매트릭스 클래스
class Matrix3D {
  final double m00, m01, m02;
  final double m10, m11, m12;
  final double m20, m21, m22;
  
  const Matrix3D(
    this.m00, this.m01, this.m02,
    this.m10, this.m11, this.m12,
    this.m20, this.m21, this.m22,
  );
  
  /// 3D 포인트 변환
  Vector3 transform(double x, double y, double z) {
    return Vector3(
      m00 * x + m01 * y + m02 * z,
      m10 * x + m11 * y + m12 * z,
      m20 * x + m21 * y + m22 * z,
    );
  }
}

/// 투영된 포인트 클래스
class ProjectedPoint {
  final double x, y, z;
  final int originalIndex;
  final double confidence;
  
  const ProjectedPoint({
    required this.x,
    required this.y,
    required this.z,
    required this.originalIndex,
    required this.confidence,
  });
}

/// 깊이 레이어 클래스
class DepthLayer {
  final Rect rect;
  final Paint paint;
  
  const DepthLayer({
    required this.rect,
    required this.paint,
  });
}