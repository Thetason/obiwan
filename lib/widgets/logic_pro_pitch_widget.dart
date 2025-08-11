import 'package:flutter/material.dart';
import 'dart:math' as math;

class LogicProPitchData {
  final double frequency;
  final double confidence;
  final double startTime;
  final double duration;
  final DateTime timestamp;
  
  const LogicProPitchData({
    required this.frequency,
    required this.confidence,
    required this.startTime,
    required this.duration,
    required this.timestamp,
  });
}

class LogicProPitchWidget extends StatefulWidget {
  final List<LogicProPitchData> pitchData;
  final double totalDuration;
  final double height;
  
  const LogicProPitchWidget({
    super.key,
    required this.pitchData,
    required this.totalDuration,
    this.height = 300,
  });

  @override
  State<LogicProPitchWidget> createState() => _LogicProPitchWidgetState();
}

class _LogicProPitchWidgetState extends State<LogicProPitchWidget> 
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 주파수를 음표로 변환
  String _frequencyToNote(double frequency) {
    if (frequency <= 0) return '';
    
    const double a4 = 440.0;
    double semitones = 12 * (math.log(frequency / a4) / math.log(2));
    int noteIndex = (69 + semitones.round()) % 12;
    int octave = ((69 + semitones.round()) / 12).floor();
    
    const List<String> noteNames = ['A', 'A#', 'B', 'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#'];
    return '${noteNames[noteIndex]}$octave';
  }
  
  // 주파수를 Y 좌표로 변환 (C1~C6 범위)
  double _frequencyToY(double frequency) {
    // C1 = 32.70Hz, C6 = 1046.50Hz
    const double minFreq = 30.0;   // C1보다 약간 낮게
    const double maxFreq = 1100.0; // C6보다 약간 높게
    
    if (frequency <= minFreq) return widget.height - 20;
    if (frequency >= maxFreq) return 20;
    
    // 로그 스케일로 변환 (음표는 로그적으로 분포)
    double logFreq = math.log(frequency);
    double logMin = math.log(minFreq);
    double logMax = math.log(maxFreq);
    
    double normalizedFreq = (logFreq - logMin) / (logMax - logMin);
    return widget.height - (normalizedFreq * (widget.height - 40)) - 20;
  }
  
  // 신뢰도에 따른 블록 색상
  Color _getBlockColor(double confidence) {
    if (confidence >= 0.8) return const Color(0xFF34C759); // 초록 - 매우 정확
    if (confidence >= 0.6) return const Color(0xFF007AFF); // 파랑 - 정확
    if (confidence >= 0.4) return const Color(0xFFFF9500); // 주황 - 보통
    if (confidence >= 0.2) return const Color(0xFFFF3B30); // 빨강 - 부정확
    return const Color(0xFF8E8E93); // 회색 - 매우 부정확
  }
  
  // 블록 높이 (신뢰도에 따라)
  double _getBlockHeight(double confidence) {
    return 8 + (confidence * 12); // 8~20px
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E), // Logic Pro 다크 배경
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF38383A),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // 배경 격자 (음표 가이드라인)
          _buildNoteGridLines(),
          
          // 시간 격자
          _buildTimeGridLines(),
          
          // 피치 블록들
          _buildPitchBlocks(),
        ],
      ),
    );
  }
  
  Widget _buildNoteGridLines() {
    // C1부터 C6까지 주요 음표들
    final Map<String, double> noteFrequencies = {};
    const List<String> noteNames = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
    
    // 각 옥타브별 주요 음표들 추가
    for (int octave = 1; octave <= 6; octave++) {
      for (String note in noteNames) {
        double frequency = _getNoteFrequency(note, octave);
        noteFrequencies['$note$octave'] = frequency;
      }
    }
    
    return Stack(
      children: noteFrequencies.entries.map((entry) {
        final note = entry.key;
        final frequency = entry.value;
        final y = _frequencyToY(frequency);
        
        // C음표는 더 진하게 표시
        final isC = note.startsWith('C');
        
        return Positioned(
          left: 0,
          right: 0,
          top: y - 0.5,
          child: Container(
            height: 1,
            color: isC 
                ? const Color(0xFF48484A) 
                : const Color(0xFF2C2C2E),
            child: isC ? Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: const Color(0xFF48484A),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  note,
                  style: const TextStyle(
                    fontSize: 8,
                    color: Color(0xFF8E8E93),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ) : null,
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildTimeGridLines() {
    if (widget.totalDuration <= 0) return const SizedBox();
    
    // 1초마다 세로선 그리기
    List<Widget> lines = [];
    for (double time = 0; time <= widget.totalDuration; time += 1.0) {
      final x = (time / widget.totalDuration) * MediaQuery.of(context).size.width;
      
      lines.add(
        Positioned(
          left: x,
          top: 0,
          bottom: 0,
          child: Container(
            width: 1,
            color: const Color(0xFF2C2C2E),
          ),
        ),
      );
    }
    
    return Stack(children: lines);
  }
  
  Widget _buildPitchBlocks() {
    if (widget.pitchData.isEmpty || widget.totalDuration <= 0) {
      return const SizedBox();
    }
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Stack(
          children: widget.pitchData.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            
            // 블록 위치 계산
            final x = (data.startTime / widget.totalDuration) * 
                     (MediaQuery.of(context).size.width - 100);
            final width = math.max(4, (data.duration / widget.totalDuration) * 
                          (MediaQuery.of(context).size.width - 100));
            final y = _frequencyToY(data.frequency);
            final height = _getBlockHeight(data.confidence);
            final color = _getBlockColor(data.confidence);
            
            // 애니메이션 지연
            final animationDelay = (index / widget.pitchData.length).clamp(0.0, 1.0);
            final blockAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: _animationController,
              curve: Interval(animationDelay, 1.0, curve: Curves.easeOutCubic),
            ));
            
            return Positioned(
              left: x + 50, // 음표 레이블 공간
              top: y - height / 2,
              child: Transform.scale(
                scale: blockAnimation.value,
                child: Container(
                  width: width * blockAnimation.value,
                  height: height,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: width > 30 ? Center(
                    child: Text(
                      _frequencyToNote(data.frequency),
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ) : null,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
  
  // 음표 주파수 계산
  double _getNoteFrequency(String note, int octave) {
    const Map<String, int> noteToSemitone = {
      'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5,
      'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11,
    };
    
    int semitone = noteToSemitone[note] ?? 0;
    int midiNote = (octave + 1) * 12 + semitone;
    
    // A4 = 440Hz, MIDI note 69
    return 440.0 * math.pow(2, (midiNote - 69) / 12.0);
  }
}