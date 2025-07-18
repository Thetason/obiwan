import 'package:flutter/material.dart';

class ControlPanelWidget extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onRecordToggle;
  final VoidCallback onStepByStepToggle;
  final bool showStepByStep;
  
  const ControlPanelWidget({
    super.key,
    required this.isRecording,
    required this.onRecordToggle,
    required this.onStepByStepToggle,
    required this.showStepByStep,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 단계별 가이드 토글
          _buildControlButton(
            icon: showStepByStep ? Icons.fullscreen_exit : Icons.school,
            label: '단계별',
            onPressed: onStepByStepToggle,
            isActive: showStepByStep,
            color: Colors.indigo,
          ),
          
          // 녹음 버튼 (중앙, 크게)
          _buildRecordButton(),
          
          // 설정 버튼
          _buildControlButton(
            icon: Icons.settings,
            label: '설정',
            onPressed: () {
              // 설정 메뉴 열기
            },
            isActive: false,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: onRecordToggle,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRecording ? Colors.red : Colors.blue,
          boxShadow: [
            BoxShadow(
              color: (isRecording ? Colors.red : Colors.blue).withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          isRecording ? Icons.stop : Icons.mic,
          size: 36,
          color: Colors.white,
        ),
      ),
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isActive,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.grey[700],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: Colors.white,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}