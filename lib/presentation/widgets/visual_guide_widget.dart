import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../../features/visual_guide/visual_guide_controller.dart';
import '../../domain/entities/visual_guide.dart';
import '../providers/visual_guide_provider.dart';

class VisualGuideWidget extends ConsumerWidget {
  final VisualGuideState visualGuideState;
  final bool showStepByStep;
  final Function(bool)? onStepByStepToggle;
  
  const VisualGuideWidget({
    super.key,
    required this.visualGuideState,
    this.showStepByStep = false,
    this.onStepByStepToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        // 3D 모델 뷰어
        _build3DModelViewer(context, ref),
        
        // 단계별 가이드 오버레이
        if (showStepByStep && visualGuideState.currentGuide != null)
          _buildStepByStepOverlay(context, ref),
        
        // 하이라이트 오버레이
        if (visualGuideState.currentGuide != null)
          _buildHighlightOverlay(context, ref),
        
        // 에러 메시지
        if (visualGuideState.error != null)
          _buildErrorOverlay(context, ref),
      ],
    );
  }
  
  Widget _build3DModelViewer(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey[900]!,
            Colors.grey[800]!,
          ],
        ),
      ),
      child: visualGuideState.currentGuide != null
          ? _buildModelViewer(context, ref)
          : _buildPlaceholder(),
    );
  }
  
  Widget _buildModelViewer(BuildContext context, WidgetRef ref) {
    final guide = visualGuideState.currentGuide!;
    
    return ModelViewer(
      backgroundColor: Colors.transparent,
      src: _getModelSrc(guide.guideType),
      alt: "3D 보컬 가이드 모델",
      ar: true,
      autoRotate: false,
      cameraControls: true,
      disableZoom: false,
      loading: Loading.eager,
      onWebViewCreated: (controller) {
        // 3D 모델 로드 완료 시 초기 설정
        _initializeModel(controller, guide);
      },
    );
  }
  
  Widget _buildPlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 80,
            color: Colors.white30,
          ),
          SizedBox(height: 16),
          Text(
            '발성 분석 후 가이드가 표시됩니다',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildStepByStepOverlay(BuildContext context, WidgetRef ref) {
    final guide = visualGuideState.currentGuide!;
    final currentStep = visualGuideState.currentStep;
    
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 진행률 표시
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '단계 ${currentStep + 1}/${guide.stepByStep.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${((currentStep + 1) / guide.stepByStep.length * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // 진행률 바
            LinearProgressIndicator(
              value: (currentStep + 1) / guide.stepByStep.length,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            
            const SizedBox(height: 16),
            
            // 현재 단계 설명
            Text(
              guide.stepByStep[currentStep],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 컨트롤 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: currentStep > 0 
                      ? () => ref.read(visualGuideProvider.notifier).previousStep()
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('이전'),
                ),
                
                ElevatedButton(
                  onPressed: currentStep < guide.stepByStep.length - 1
                      ? () => ref.read(visualGuideProvider.notifier).nextStep()
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    currentStep < guide.stepByStep.length - 1 ? '다음' : '완료',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHighlightOverlay(BuildContext context, WidgetRef ref) {
    final guide = visualGuideState.currentGuide!;
    
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: HighlightPainter(
            highlights: guide.highlights,
            animationProgress: visualGuideState.isAnimating ? 1.0 : 0.5,
          ),
        ),
      ),
    );
  }
  
  Widget _buildErrorOverlay(BuildContext context, WidgetRef ref) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                visualGuideState.error!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.close,
                color: Colors.white,
              ),
              onPressed: () {
                ref.read(visualGuideProvider.notifier).clearError();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  String _getModelSrc(GuideType guideType) {
    switch (guideType) {
      case GuideType.breathing:
      case GuideType.posture:
        return 'assets/models/human_torso.glb';
      case GuideType.resonance:
      case GuideType.mouthShape:
        return 'assets/models/vocal_tract.glb';
    }
  }
  
  void _initializeModel(dynamic controller, VisualGuide guide) {
    // 모델 초기 설정
    // 실제 구현에서는 WebView 컨트롤러를 통해 3D 모델 설정
  }
}

class HighlightPainter extends CustomPainter {
  final List<BodyHighlight> highlights;
  final double animationProgress;
  
  HighlightPainter({
    required this.highlights,
    required this.animationProgress,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    for (final highlight in highlights) {
      _drawHighlight(canvas, size, highlight);
    }
  }
  
  void _drawHighlight(Canvas canvas, Size size, BodyHighlight highlight) {
    final position = _getHighlightPosition(highlight.bodyPart, size);
    if (position == null) return;
    
    final paint = Paint()
      ..color = Color(highlight.colorHex).withOpacity(
        highlight.opacity * animationProgress,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    // 펄스 효과
    if (highlight.pulse) {
      final pulseRadius = 30 + (20 * animationProgress);
      canvas.drawCircle(position, pulseRadius, paint);
    } else {
      canvas.drawCircle(position, 25, paint);
    }
  }
  
  Offset? _getHighlightPosition(String bodyPart, Size size) {
    // 신체 부위별 하이라이트 위치 계산
    switch (bodyPart) {
      case 'abdomen':
        return Offset(size.width * 0.5, size.height * 0.7);
      case 'chest':
        return Offset(size.width * 0.5, size.height * 0.5);
      case 'mouth':
        return Offset(size.width * 0.5, size.height * 0.3);
      case 'diaphragm':
        return Offset(size.width * 0.5, size.height * 0.65);
      case 'neck':
        return Offset(size.width * 0.5, size.height * 0.35);
      case 'spine':
        return Offset(size.width * 0.5, size.height * 0.6);
      default:
        return null;
    }
  }
  
  @override
  bool shouldRepaint(HighlightPainter oldDelegate) {
    return oldDelegate.highlights != highlights ||
           oldDelegate.animationProgress != animationProgress;
  }
}