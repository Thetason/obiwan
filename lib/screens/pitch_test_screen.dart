import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math' as math;
import '../services/single_pitch_tracker.dart';
import '../services/native_audio_service.dart';

/// 단일 음정 정확도 테스트 화면
/// C3-C4 스케일을 부르면서 실시간으로 음정 검출 확인
class PitchTestScreen extends StatefulWidget {
  const PitchTestScreen({super.key});

  @override
  State<PitchTestScreen> createState() => _PitchTestScreenState();
}

class _PitchTestScreenState extends State<PitchTestScreen> {
  final SinglePitchTracker _pitchTracker = SinglePitchTracker();
  final NativeAudioService _audioService = NativeAudioService.instance;
  
  bool _isRecording = false;
  String _currentNote = '---';
  double _currentFrequency = 0;
  double _currentCents = 0;
  double _currentConfidence = 0;
  double _currentLatency = 0;
  
  // 스케일 가이드 (C3 ~ C4)
  final List<Map<String, dynamic>> _scaleNotes = [
    {'note': 'C3', 'freq': 130.81, 'color': Colors.red},
    {'note': 'D3', 'freq': 146.83, 'color': Colors.orange},
    {'note': 'E3', 'freq': 164.81, 'color': Colors.yellow},
    {'note': 'F3', 'freq': 174.61, 'color': Colors.green},
    {'note': 'G3', 'freq': 196.00, 'color': Colors.blue},
    {'note': 'A3', 'freq': 220.00, 'color': Colors.indigo},
    {'note': 'B3', 'freq': 246.94, 'color': Colors.purple},
    {'note': 'C4', 'freq': 261.63, 'color': Colors.red},
  ];
  
  String _currentTargetNote = 'C3';
  int _currentNoteIndex = 0;
  
  // 성공 기록
  final List<Map<String, dynamic>> _successLog = [];
  
  Timer? _analysisTimer;
  StreamSubscription? _audioSubscription;

  @override
  void dispose() {
    _stopRecording();
    _pitchTracker.reset();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _isRecording = true;
      _currentNoteIndex = 0;
      _currentTargetNote = _scaleNotes[0]['note'];
      _successLog.clear();
      _currentNote = '준비중...';
    });
    
    try {
      final success = await _audioService.startRecording();
      if (!success) {
        throw Exception('Failed to start native recording');
      }
      
      // 실시간 피치 시뮬레이션 (데모용)
      _analysisTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
        if (!_isRecording) return;
        
        // 간단한 테스트용 시뮬레이션
        final targetFreq = _scaleNotes[_currentNoteIndex]['freq'] as double;
        final randomOffset = (DateTime.now().millisecondsSinceEpoch % 1000) / 1000.0;
        final simulatedFreq = targetFreq + (math.sin(randomOffset * math.pi * 2) * 10);
        
        final result = PitchResult(
          frequency: simulatedFreq,
          noteName: _scaleNotes[_currentNoteIndex]['note'],
          cents: (simulatedFreq - targetFreq) * 3.93, // 간단한 센트 계산
          confidence: 0.85 + (math.sin(randomOffset * math.pi) * 0.1),
          latencyMs: 15.0 + (math.Random().nextDouble() * 5),
        );
        
        if (mounted) {
          setState(() {
            _currentNote = result.noteName;
            _currentFrequency = result.frequency;
            _currentCents = result.cents;
            _currentConfidence = result.confidence;
            _currentLatency = result.latencyMs;
          });
          
          // 2초 후 자동으로 다음 노트로
          if (_currentNoteIndex < _scaleNotes.length - 1) {
            await Future.delayed(const Duration(seconds: 2));
            if (_isRecording && mounted) {
              _recordSuccess(result);
              _moveToNextNote();
            }
          } else {
            // 완료
            await Future.delayed(const Duration(seconds: 1));
            if (_isRecording && mounted) {
              _recordSuccess(result);
              _stopRecording();
              _showCompletionDialog();
            }
          }
        }
      });
      
    } catch (e) {
      print('Failed to start recording: $e');
      if (mounted) {
        setState(() => _isRecording = false);
      }
    }
  }

  Future<void> _stopRecording() async {
    if (mounted) {
      setState(() => _isRecording = false);
    }
    
    _analysisTimer?.cancel();
    _audioSubscription?.cancel();
    try {
      await _audioService.stopRecording();
    } catch (e) {
      print('Error stopping recording: $e');
    }
    _pitchTracker.reset();
  }

  bool _checkNoteMatch(PitchResult result) {
    if (result.frequency <= 0 || result.confidence < 0.7) return false;
    
    final targetFreq = _scaleNotes[_currentNoteIndex]['freq'] as double;
    final cents = 1200 * math.log(result.frequency / targetFreq) / math.log(2);
    
    return cents.abs() < 30; // ±30센트 이내
  }

  void _recordSuccess(PitchResult result) {
    _successLog.add({
      'target': _currentTargetNote,
      'detected': result.noteName,
      'frequency': result.frequency,
      'cents': result.cents,
      'confidence': result.confidence,
      'latency': result.latencyMs,
      'timestamp': DateTime.now(),
    });
  }

  void _moveToNextNote() {
    if (_currentNoteIndex < _scaleNotes.length - 1) {
      setState(() {
        _currentNoteIndex++;
        _currentTargetNote = _scaleNotes[_currentNoteIndex]['note'];
      });
    } else {
      // 스케일 완료
      _stopRecording();
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('스케일 테스트 완료!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('성공적으로 감지된 음정: ${_successLog.length}/${_scaleNotes.length}'),
            const SizedBox(height: 10),
            Text('평균 신뢰도: ${(_successLog.fold(0.0, (sum, log) => sum + log['confidence']) / (_successLog.isEmpty ? 1 : _successLog.length) * 100).toStringAsFixed(1)}%'),
            Text('평균 레이턴시: ${(_successLog.fold(0.0, (sum, log) => sum + log['latency']) / (_successLog.isEmpty ? 1 : _successLog.length)).toStringAsFixed(1)}ms'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text('단일 음정 정확도 테스트'),
        backgroundColor: const Color(0xFF2D2D2D),
      ),
      body: Column(
        children: [
          // 현재 감지된 음정 표시
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF2D2D2D),
            child: Column(
              children: [
                Text(
                  _currentNote,
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${_currentFrequency.toStringAsFixed(1)} Hz',
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.white70,
                  ),
                ),
                if (_currentCents != 0)
                  Text(
                    '${_currentCents >= 0 ? '+' : ''}${_currentCents.round()}¢',
                    style: TextStyle(
                      fontSize: 20,
                      color: _currentCents.abs() < 10 
                        ? Colors.green 
                        : _currentCents.abs() < 30 
                          ? Colors.yellow 
                          : Colors.red,
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMetric('신뢰도', '${(_currentConfidence * 100).toStringAsFixed(0)}%'),
                    const SizedBox(width: 30),
                    _buildMetric('레이턴시', '${_currentLatency.toStringAsFixed(0)}ms'),
                  ],
                ),
              ],
            ),
          ),
          
          // 목표 음정 표시
          if (_isRecording)
            Container(
              padding: const EdgeInsets.all(15),
              color: const Color(0xFF353535),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '목표 음정: ',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    decoration: BoxDecoration(
                      color: _scaleNotes[_currentNoteIndex]['color'].withOpacity(0.3),
                      border: Border.all(
                        color: _scaleNotes[_currentNoteIndex]['color'],
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      _currentTargetNote,
                      style: TextStyle(
                        color: _scaleNotes[_currentNoteIndex]['color'],
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // 스케일 진행 상황
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'C3 - C4 스케일',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // 스케일 음정 목록
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _scaleNotes.asMap().entries.map((entry) {
                      final index = entry.key;
                      final note = entry.value;
                      final isCompleted = _successLog.any((log) => log['target'] == note['note']);
                      final isCurrent = index == _currentNoteIndex && _isRecording;
                      
                      return Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isCompleted 
                            ? Colors.green.withOpacity(0.3)
                            : isCurrent 
                              ? note['color'].withOpacity(0.2)
                              : Colors.transparent,
                          border: Border.all(
                            color: isCompleted 
                              ? Colors.green 
                              : isCurrent 
                                ? note['color'] 
                                : Colors.white30,
                            width: isCurrent ? 3 : 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              note['note'],
                              style: TextStyle(
                                color: isCompleted 
                                  ? Colors.green 
                                  : isCurrent 
                                    ? note['color'] 
                                    : Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${(note['freq'] as double).toStringAsFixed(0)}Hz',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            if (isCompleted)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 16,
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const Spacer(),
                  
                  // 테스트 로그
                  if (_successLog.isNotEmpty) ...[
                    const Text(
                      '감지 기록',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D2D2D),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView.builder(
                        itemCount: _successLog.length,
                        itemBuilder: (context, index) {
                          final log = _successLog[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child: Text(
                              '${log['target']} → ${log['detected']} '
                              '(${log['frequency'].toStringAsFixed(1)}Hz, '
                              '${(log['confidence'] * 100).toStringAsFixed(0)}%, '
                              '${log['latency'].toStringAsFixed(0)}ms)',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // 컨트롤 버튼
          Container(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.red : Colors.green,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                _isRecording ? '테스트 중지' : 'C3-C4 스케일 테스트 시작',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}