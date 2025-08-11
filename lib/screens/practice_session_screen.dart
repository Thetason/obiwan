import 'package:flutter/material.dart';
import 'wave_start_screen.dart';

class PracticeSessionScreen extends StatelessWidget {
  final dynamic selectedSong;

  const PracticeSessionScreen({
    Key? key,
    required this.selectedSong,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 기존 3단계 워크플로우로 연결
    return const WaveStartScreen();
  }
}