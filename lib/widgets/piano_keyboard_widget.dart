import 'package:flutter/material.dart';
import 'dart:math' as math;

class PianoKeyboardWidget extends StatelessWidget {
  final double? currentFrequency;
  final Duration animationDuration;
  
  const PianoKeyboardWidget({
    super.key,
    this.currentFrequency,
    this.animationDuration = const Duration(milliseconds: 200),
  });

  // 주파수를 음표로 변환
  String _frequencyToNote(double frequency) {
    if (frequency <= 0) return '';
    
    // A4 = 440Hz를 기준으로 계산
    const double a4 = 440.0;
    double semitones = 12 * (math.log(frequency / a4) / math.log(2));
    int noteIndex = (69 + semitones.round()) % 12; // A=0, A#=1, B=2, C=3...
    int octave = ((69 + semitones.round()) / 12).floor();
    
    const List<String> noteNames = ['A', 'A#', 'B', 'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#'];
    return '${noteNames[noteIndex]}$octave';
  }
  
  // 음표가 검은 건반인지 확인
  bool _isBlackKey(String note) {
    return note.contains('#');
  }
  
  // 피아노 건반 색상 결정
  Color _getKeyColor(String note, bool isActive) {
    if (isActive) {
      return _isBlackKey(note) ? const Color(0xFF00BFA6) : const Color(0xFF5B8DEE);
    }
    return _isBlackKey(note) ? const Color(0xFF2E2E2E) : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    // C1부터 C6까지의 전체 피아노 범위 (72개 반음)
    final List<String> notes = [];
    const List<String> noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    
    // C1부터 C6까지 생성
    for (int octave = 1; octave <= 6; octave++) {
      for (String noteName in noteNames) {
        notes.add('$noteName$octave');
        if (noteName == 'B' && octave == 6) break; // C6에서 중단
      }
    }
    
    final String? currentNote = currentFrequency != null 
        ? _frequencyToNote(currentFrequency!) 
        : null;

    return Container(
      width: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDEE2E6), width: 1),
      ),
      child: Column(
        children: [
          // 제목
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Text(
              '🎹',
              style: TextStyle(fontSize: 16),
            ),
          ),
          
          // 피아노 건반들
          Expanded(
            child: ListView.builder(
              reverse: true, // 높은 음이 위에 오도록
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                final isActive = currentNote == note;
                final isBlack = _isBlackKey(note);
                
                return AnimatedContainer(
                  duration: animationDuration,
                  height: isBlack ? 24 : 32,
                  margin: EdgeInsets.symmetric(
                    vertical: 1,
                    horizontal: isBlack ? 8 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: _getKeyColor(note, isActive),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isActive 
                          ? const Color(0xFF00BFA6) 
                          : const Color(0xFFDEE2E6),
                      width: isActive ? 2 : 1,
                    ),
                    boxShadow: isActive ? [
                      BoxShadow(
                        color: const Color(0xFF00BFA6).withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ] : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      note.replaceAll('#', '♯'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                        color: isBlack
                            ? (isActive ? Colors.white : const Color(0xFFCED4DA))
                            : (isActive ? Colors.white : const Color(0xFF495057)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // 현재 주파수 표시
          if (currentFrequency != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Text(
                    currentNote ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00BFA6),
                    ),
                  ),
                  Text(
                    '${currentFrequency!.toStringAsFixed(1)}Hz',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF6C757D),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}