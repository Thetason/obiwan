import 'package:flutter/material.dart';

class ControlPanelWidget extends StatelessWidget {
  final bool isRecording;
  final Function(bool) onRecordingToggle;
  final Function(Map<String, dynamic>)? onSettingsChanged;
  
  const ControlPanelWidget({
    super.key,
    required this.isRecording,
    required this.onRecordingToggle,
    this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main Recording Button
          GestureDetector(
            onTap: () => onRecordingToggle(!isRecording),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: isRecording 
                  ? const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isRecording ? Colors.red : Colors.indigo).withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 3,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Status Text
          Text(
            isRecording ? '녹음 중...' : '녹음 시작',
            style: TextStyle(
              color: isRecording ? Colors.red : Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}