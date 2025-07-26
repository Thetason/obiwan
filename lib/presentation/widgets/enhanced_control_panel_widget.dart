import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/enhanced_app_theme.dart';

/// 향상된 컨트롤 패널 위젯
/// 녹음 컨트롤과 설정을 아름답게 표현
class EnhancedControlPanelWidget extends ConsumerStatefulWidget {
  final bool isRecording;
  final Function(bool) onRecordingToggle;
  final Function(Map<String, dynamic>) onSettingsChanged;

  const EnhancedControlPanelWidget({
    super.key,
    required this.isRecording,
    required this.onRecordingToggle,
    required this.onSettingsChanged,
  });

  @override
  ConsumerState<EnhancedControlPanelWidget> createState() => _EnhancedControlPanelWidgetState();
}

class _EnhancedControlPanelWidgetState extends ConsumerState<EnhancedControlPanelWidget>
    with TickerProviderStateMixin, CustomWidgetStyles {
  late AnimationController _recordButtonController;
  late AnimationController _settingsController;
  late AnimationController _waveController;
  
  late Animation<double> _recordButtonScale;
  late Animation<double> _recordButtonRotation;
  late Animation<double> _settingsSlide;
  late Animation<double> _waveAnimation;
  
  bool _showAdvancedSettings = false;
  double _sensitivity = 0.8;
  double _noiseThreshold = 0.1;
  bool _realTimeProcessing = true;
  String _selectedMode = 'standard';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // 녹음 버튼 애니메이션
    _recordButtonController = AnimationController(
      duration: EnhancedAppTheme.defaultDuration,
      vsync: this,
    );
    
    _recordButtonScale = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _recordButtonController, curve: Curves.elasticOut),
    );
    
    _recordButtonRotation = Tween<double>(begin: 0.0, end: 0.05).animate(
      CurvedAnimation(parent: _recordButtonController, curve: Curves.easeInOut),
    );
    
    // 설정 패널 애니메이션
    _settingsController = AnimationController(
      duration: EnhancedAppTheme.slowDuration,
      vsync: this,
    );
    
    _settingsSlide = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _settingsController, curve: Curves.easeOutCubic),
    );
    
    // 파형 애니메이션
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
    
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_waveController);
  }

  @override
  void didUpdateWidget(EnhancedControlPanelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _recordButtonController.forward();
      } else {
        _recordButtonController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _recordButtonController.dispose();
    _settingsController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            EnhancedAppTheme.secondaryDark,
            EnhancedAppTheme.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: EnhancedAppTheme.accentBlue.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // 배경 웨이브 효과
            if (widget.isRecording) _buildBackgroundWaves(),
            
            // 메인 콘텐츠
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  Expanded(child: _buildMainControls()),
                  _buildQuickSettings(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundWaves() {
    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: BackgroundWavePainter(
            animationValue: _waveAnimation.value,
            isRecording: widget.isRecording,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.tune,
          color: EnhancedAppTheme.neonBlue,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          '컨트롤 패널',
          style: EnhancedAppTheme.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: EnhancedAppTheme.highlight,
          ),
        ),
        const Spacer(),
        _buildAdvancedSettingsToggle(),
      ],
    );
  }

  Widget _buildAdvancedSettingsToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showAdvancedSettings = !_showAdvancedSettings;
        });
        
        if (_showAdvancedSettings) {
          _settingsController.forward();
        } else {
          _settingsController.reverse();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _showAdvancedSettings 
              ? EnhancedAppTheme.neonBlue.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: EnhancedAppTheme.accentLight.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showAdvancedSettings ? Icons.expand_less : Icons.expand_more,
              color: EnhancedAppTheme.accentLight,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              '고급',
              style: EnhancedAppTheme.caption.copyWith(
                color: EnhancedAppTheme.accentLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainControls() {
    return Column(
      children: [
        // 메인 녹음 버튼
        Expanded(child: _buildRecordButton()),
        
        const SizedBox(height: 20),
        
        // 고급 설정 패널
        AnimatedBuilder(
          animation: _settingsSlide,
          builder: (context, child) {
            return SizeTransition(
              sizeFactor: _settingsSlide,
              child: _buildAdvancedSettings(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecordButton() {
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_recordButtonScale, _recordButtonRotation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _recordButtonScale.value,
            child: Transform.rotate(
              angle: _recordButtonRotation.value,
              child: GestureDetector(
                onTap: () {
                  widget.onRecordingToggle(!widget.isRecording);
                  
                  // 햅틱 피드백
                  // HapticFeedback.mediumImpact();
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: widget.isRecording 
                        ? EnhancedAppTheme.errorGradient
                        : EnhancedAppTheme.successGradient,
                    shape: widget.isRecording ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: widget.isRecording ? BorderRadius.circular(20) : null,
                    boxShadow: [
                      BoxShadow(
                        color: (widget.isRecording 
                            ? EnhancedAppTheme.neonRed 
                            : EnhancedAppTheme.neonGreen).withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: (widget.isRecording 
                            ? EnhancedAppTheme.neonRed 
                            : EnhancedAppTheme.neonGreen).withOpacity(0.6),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdvancedSettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.3),
            Colors.black.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildSliderSetting(
            label: '감도',
            value: _sensitivity,
            icon: Icons.hearing,
            onChanged: (value) {
              setState(() {
                _sensitivity = value;
              });
              _notifySettingsChanged();
            },
          ),
          const SizedBox(height: 16),
          _buildSliderSetting(
            label: '노이즈 임계값',
            value: _noiseThreshold,
            icon: Icons.noise_control_off,
            onChanged: (value) {
              setState(() {
                _noiseThreshold = value;
              });
              _notifySettingsChanged();
            },
          ),
          const SizedBox(height: 16),
          _buildSwitchSetting(
            label: '실시간 처리',
            value: _realTimeProcessing,
            icon: Icons.speed,
            onChanged: (value) {
              setState(() {
                _realTimeProcessing = value;
              });
              _notifySettingsChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSetting({
    required String label,
    required double value,
    required IconData icon,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: EnhancedAppTheme.neonBlue,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: EnhancedAppTheme.bodyMedium.copyWith(
                color: EnhancedAppTheme.accentLight,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '${(value * 100).toInt()}%',
              style: EnhancedAppTheme.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: EnhancedAppTheme.neonBlue,
            inactiveTrackColor: EnhancedAppTheme.accentBlue.withOpacity(0.3),
            thumbColor: EnhancedAppTheme.neonBlue,
            overlayColor: EnhancedAppTheme.neonBlue.withOpacity(0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value,
            onChanged: onChanged,
            min: 0.0,
            max: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchSetting({
    required String label,
    required bool value,
    required IconData icon,
    required Function(bool) onChanged,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: EnhancedAppTheme.neonGreen,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: EnhancedAppTheme.bodyMedium.copyWith(
            color: EnhancedAppTheme.accentLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: EnhancedAppTheme.neonGreen,
          activeTrackColor: EnhancedAppTheme.neonGreen.withOpacity(0.3),
          inactiveThumbColor: EnhancedAppTheme.accentLight,
          inactiveTrackColor: EnhancedAppTheme.accentLight.withOpacity(0.3),
        ),
      ],
    );
  }

  Widget _buildQuickSettings() {
    return Row(
      children: [
        _buildQuickButton(
          icon: Icons.refresh,
          label: '리셋',
          onTap: _resetSettings,
        ),
        const SizedBox(width: 12),
        _buildQuickButton(
          icon: Icons.save,
          label: '저장',
          onTap: _saveSettings,
        ),
        const SizedBox(width: 12),
        _buildQuickButton(
          icon: Icons.help_outline,
          label: '도움말',
          onTap: _showHelp,
        ),
      ],
    );
  }

  Widget _buildQuickButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: buildHoverCard(
        padding: const EdgeInsets.symmetric(vertical: 12),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: EnhancedAppTheme.accentLight,
              size: 18,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: EnhancedAppTheme.caption.copyWith(
                color: EnhancedAppTheme.accentLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _notifySettingsChanged() {
    widget.onSettingsChanged({
      'sensitivity': _sensitivity,
      'noiseThreshold': _noiseThreshold,
      'realTimeProcessing': _realTimeProcessing,
      'selectedMode': _selectedMode,
    });
  }

  void _resetSettings() {
    setState(() {
      _sensitivity = 0.8;
      _noiseThreshold = 0.1;
      _realTimeProcessing = true;
      _selectedMode = 'standard';
    });
    _notifySettingsChanged();
  }

  void _saveSettings() {
    // 설정 저장 로직
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('설정이 저장되었습니다'),
        backgroundColor: EnhancedAppTheme.neonGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => _buildHelpDialog(),
    );
  }

  Widget _buildHelpDialog() {
    return AlertDialog(
      backgroundColor: EnhancedAppTheme.secondaryDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(
            Icons.help_outline,
            color: EnhancedAppTheme.neonBlue,
          ),
          const SizedBox(width: 8),
          Text(
            '컨트롤 패널 도움말',
            style: EnhancedAppTheme.headingMedium.copyWith(
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHelpItem('감도', '마이크 입력 감도를 조절합니다'),
          _buildHelpItem('노이즈 임계값', '배경 소음을 필터링하는 수준을 설정합니다'),
          _buildHelpItem('실시간 처리', '즉시 분석할지 후처리할지 선택합니다'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '닫기',
            style: TextStyle(color: EnhancedAppTheme.neonBlue),
          ),
        ),
      ],
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: EnhancedAppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: EnhancedAppTheme.highlight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: EnhancedAppTheme.bodyMedium.copyWith(
              color: EnhancedAppTheme.accentLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// 배경 웨이브 페인터
class BackgroundWavePainter extends CustomPainter {
  final double animationValue;
  final bool isRecording;

  BackgroundWavePainter({
    required this.animationValue,
    required this.isRecording,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isRecording) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    const waveCount = 3;
    
    for (int i = 0; i < waveCount; i++) {
      final path = Path();
      final amplitude = 20 + i * 10;
      final frequency = 0.02 + i * 0.01;
      final phase = animationValue * 2 * math.pi + i * math.pi / 3;
      
      paint.color = EnhancedAppTheme.neonGreen.withOpacity(0.1 - i * 0.03);
      
      path.moveTo(0, size.height / 2);
      
      for (double x = 0; x <= size.width; x += 2) {
        final y = size.height / 2 + 
                 amplitude * math.sin(x * frequency + phase);
        path.lineTo(x, y);
      }
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}