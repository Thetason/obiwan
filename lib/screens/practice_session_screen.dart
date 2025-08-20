import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import '../widgets/recording_flow_modal.dart';

class PracticeSessionScreen extends StatelessWidget {
  final dynamic selectedSong;

  const PracticeSessionScreen({
    Key? key,
    required this.selectedSong,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 기존 3단계 워크플로우로 연결
    // RecordingFlowModal을 전체 화면으로 표시
    return Scaffold(
      body: Stack(
        children: [
          // 배경 그라데이션
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0E21),
                  Color(0xFF1A1F3C),
                ],
              ),
            ),
          ),
          // RecordingFlowModal을 전체 화면으로 표시
          RecordingFlowModal(
            onClose: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}