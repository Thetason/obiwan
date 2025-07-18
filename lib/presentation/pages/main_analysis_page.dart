import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/audio_visualization_widget.dart';
import '../widgets/visual_guide_widget.dart';
import '../widgets/coaching_advice_widget.dart';
import '../widgets/control_panel_widget.dart';
import '../providers/audio_analysis_provider.dart';
import '../providers/visual_guide_provider.dart';
import '../../domain/entities/vocal_analysis.dart';

class MainAnalysisPage extends ConsumerStatefulWidget {
  const MainAnalysisPage({super.key});

  @override
  ConsumerState<MainAnalysisPage> createState() => _MainAnalysisPageState();
}

class _MainAnalysisPageState extends ConsumerState<MainAnalysisPage> {
  bool _isRecording = false;
  bool _showStepByStep = false;

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioAnalysisProvider);
    final visualGuideState = ref.watch(visualGuideProvider);
    
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text(
          'AI 보컬 코치',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              // 설정 화면으로 이동
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 상단: 실시간 파형 + 음정 곡선 (25% 높이)
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D2D),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: AudioVisualizationWidget(
                audioData: audioState.audioData,
                pitchData: audioState.pitchData,
                isRecording: _isRecording,
              ),
            ),
          ),
          
          // 중앙: 3D 아바타/해부학 모델 (50% 높이)
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D2D),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // 3D 모델 영역
                  VisualGuideWidget(
                    visualGuideState: visualGuideState,
                    showStepByStep: _showStepByStep,
                  ),
                  
                  // 로딩 오버레이
                  if (visualGuideState.isLoading || audioState.isAnalyzing)
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                  
                  // 상단 우측 컨트롤 버튼들
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _showStepByStep ? Icons.fullscreen_exit : Icons.fullscreen,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _showStepByStep = !_showStepByStep;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            ref.read(visualGuideProvider.notifier).reset();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 하단: 조언 텍스트 + 액션 버튼 (25% 높이)
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D2D),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CoachingAdviceWidget(
                analysis: audioState.analysis,
                isRecording: _isRecording,
                onAdviceAction: (action) {
                  _handleAdviceAction(action);
                },
              ),
            ),
          ),
        ],
      ),
      
      // 하단 컨트롤 패널
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ControlPanelWidget(
            isRecording: _isRecording,
            onRecordToggle: _toggleRecording,
            onStepByStepToggle: () {
              setState(() {
                _showStepByStep = !_showStepByStep;
              });
            },
            showStepByStep: _showStepByStep,
          ),
        ),
      ),
    );
  }

  void _toggleRecording() async {
    setState(() {
      _isRecording = !_isRecording;
    });
    
    if (_isRecording) {
      await ref.read(audioAnalysisProvider.notifier).startRecording();
    } else {
      await ref.read(audioAnalysisProvider.notifier).stopRecording();
    }
  }

  void _handleAdviceAction(String action) {
    switch (action) {
      case 'breathing_guide':
        ref.read(visualGuideProvider.notifier).startBreathingGuide(
          ref.read(audioAnalysisProvider).analysis?.breathingType ?? 
          BreathingType.mixed
        );
        break;
      case 'posture_guide':
        ref.read(visualGuideProvider.notifier).startPostureGuide();
        break;
      case 'mouth_shape_guide':
        final analysis = ref.read(audioAnalysisProvider).analysis;
        if (analysis != null) {
          ref.read(visualGuideProvider.notifier).startMouthShapeGuide(
            analysis.mouthOpening,
            analysis.tonguePosition,
          );
        }
        break;
      case 'resonance_guide':
        ref.read(visualGuideProvider.notifier).startResonanceGuide(
          ref.read(audioAnalysisProvider).analysis?.resonancePosition ?? 
          ResonancePosition.throat
        );
        break;
      case 'step_by_step':
        setState(() {
          _showStepByStep = true;
        });
        break;
    }
  }
  
  @override
  void dispose() {
    // 리소스 정리
    if (_isRecording) {
      ref.read(audioAnalysisProvider.notifier).stopRecording();
    }
    super.dispose();
  }
}