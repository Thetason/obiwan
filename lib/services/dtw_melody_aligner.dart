import 'dart:math' as math;

/// DTW (Dynamic Time Warping) 멜로디 정렬 시스템
/// 사용자가 부른 멜로디와 원곡을 시간적으로 정렬하여 정확한 비교 분석
/// 
/// 참고: DEVELOPMENT_PRINCIPLES.md - NO DUMMY DATA 원칙 준수
class DTWMelodyAligner {
  // DTW 매트릭스 최대 크기 (메모리 효율성)
  static const int maxSequenceLength = 5000;
  
  /// DTW 정렬 결과
  class AlignmentResult {
    final List<AlignmentPoint> alignmentPath;
    final double totalDistance;
    final double normalizedDistance;
    final List<NoteMatching> noteMatchings;
    final double alignmentQuality;
    final String feedback;
    
    AlignmentResult({
      required this.alignmentPath,
      required this.totalDistance,
      required this.normalizedDistance,
      required this.noteMatchings,
      required this.alignmentQuality,
      required this.feedback,
    });
    
    /// 정렬 품질 평가 (0-100%)
    double get qualityPercentage => alignmentQuality * 100;
    
    /// 타이밍 정확도 평가
    String get timingAccuracy {
      if (alignmentQuality > 0.9) return '매우 정확';
      if (alignmentQuality > 0.7) return '정확';
      if (alignmentQuality > 0.5) return '보통';
      if (alignmentQuality > 0.3) return '부정확';
      return '매우 부정확';
    }
  }
  
  /// 정렬 포인트 (원곡 시간 -> 사용자 시간 매핑)
  class AlignmentPoint {
    final int referenceIndex;
    final int userIndex;
    final double referenceTime;
    final double userTime;
    final double distance;
    
    AlignmentPoint({
      required this.referenceIndex,
      required this.userIndex,
      required this.referenceTime,
      required this.userTime,
      required this.distance,
    });
    
    /// 타이밍 차이 (초)
    double get timeDifference => (userTime - referenceTime).abs();
  }
  
  /// 음표 매칭 결과
  class NoteMatching {
    final double referenceNote;  // 원곡 음정 (Hz)
    final double userNote;       // 사용자 음정 (Hz)
    final double referenceTime;  // 원곡 시간
    final double userTime;       // 사용자 시간
    final double pitchError;     // 음정 오차 (cents)
    final double timingError;    // 타이밍 오차 (초)
    final bool isCorrect;        // 정확도 판정
    
    NoteMatching({
      required this.referenceNote,
      required this.userNote,
      required this.referenceTime,
      required this.userTime,
      required this.pitchError,
      required this.timingError,
      required this.isCorrect,
    });
    
    /// 음정 정확도 평가
    String get pitchAccuracy {
      final absPitchError = pitchError.abs();
      if (absPitchError < 10) return '완벽';
      if (absPitchError < 25) return '우수';
      if (absPitchError < 50) return '양호';
      if (absPitchError < 100) return '부족';
      return '매우 부족';
    }
  }
  
  /// 메인 DTW 정렬 함수
  /// [referencePitch]: 원곡 피치 시퀀스 (CREPE/SPICE 분석 결과)
  /// [userPitch]: 사용자 피치 시퀀스
  /// [sampleRate]: 샘플레이트 (기본 100Hz = 10ms 간격)
  AlignmentResult alignMelody(
    List<double> referencePitch,
    List<double> userPitch, {
    double sampleRate = 100.0,
    double windowConstraint = 0.1,  // Sakoe-Chiba 밴드 제약
  }) {
    if (referencePitch.isEmpty || userPitch.isEmpty) {
      return AlignmentResult(
        alignmentPath: [],
        totalDistance: double.infinity,
        normalizedDistance: double.infinity,
        noteMatchings: [],
        alignmentQuality: 0.0,
        feedback: '입력 데이터가 비어있습니다',
      );
    }
    
    // 시퀀스 길이 제한 (메모리 효율성)
    final refLength = math.min(referencePitch.length, maxSequenceLength);
    final userLength = math.min(userPitch.length, maxSequenceLength);
    
    // DTW 거리 매트릭스 초기화
    final distMatrix = List.generate(
      refLength,
      (_) => List.filled(userLength, double.infinity),
    );
    
    // 누적 거리 매트릭스
    final costMatrix = List.generate(
      refLength,
      (_) => List.filled(userLength, double.infinity),
    );
    
    // 거리 계산 함수 (음정 차이 in cents)
    double pitchDistance(double freq1, double freq2) {
      if (freq1 <= 0 || freq2 <= 0) return 1000.0; // 침묵 구간 패널티
      return 1200 * (math.log(freq2 / freq1) / math.log(2)).abs();
    }
    
    // 거리 매트릭스 계산
    for (int i = 0; i < refLength; i++) {
      for (int j = 0; j < userLength; j++) {
        // Sakoe-Chiba 밴드 제약 (경로 제한)
        final timeDiff = (i / refLength - j / userLength).abs();
        if (timeDiff > windowConstraint) continue;
        
        distMatrix[i][j] = pitchDistance(
          referencePitch[i],
          userPitch[j],
        );
      }
    }
    
    // 동적 프로그래밍으로 최적 경로 계산
    costMatrix[0][0] = distMatrix[0][0];
    
    // 첫 행 초기화
    for (int j = 1; j < userLength; j++) {
      if (distMatrix[0][j] != double.infinity) {
        costMatrix[0][j] = costMatrix[0][j - 1] + distMatrix[0][j];
      }
    }
    
    // 첫 열 초기화
    for (int i = 1; i < refLength; i++) {
      if (distMatrix[i][0] != double.infinity) {
        costMatrix[i][0] = costMatrix[i - 1][0] + distMatrix[i][0];
      }
    }
    
    // 나머지 셀 계산
    for (int i = 1; i < refLength; i++) {
      for (int j = 1; j < userLength; j++) {
        if (distMatrix[i][j] == double.infinity) continue;
        
        final cost = distMatrix[i][j];
        final minPrev = math.min(
          math.min(costMatrix[i - 1][j], costMatrix[i][j - 1]),
          costMatrix[i - 1][j - 1],
        );
        
        if (minPrev != double.infinity) {
          costMatrix[i][j] = cost + minPrev;
        }
      }
    }
    
    // 최적 경로 역추적
    final alignmentPath = <AlignmentPoint>[];
    int i = refLength - 1;
    int j = userLength - 1;
    
    while (i > 0 || j > 0) {
      alignmentPath.add(AlignmentPoint(
        referenceIndex: i,
        userIndex: j,
        referenceTime: i / sampleRate,
        userTime: j / sampleRate,
        distance: distMatrix[i][j],
      ));
      
      if (i == 0) {
        j--;
      } else if (j == 0) {
        i--;
      } else {
        // 최소 비용 경로 선택
        final costs = [
          costMatrix[i - 1][j - 1],  // 대각선
          costMatrix[i - 1][j],      // 위
          costMatrix[i][j - 1],      // 왼쪽
        ];
        
        final minIndex = costs.indexOf(costs.reduce(math.min));
        switch (minIndex) {
          case 0:
            i--;
            j--;
            break;
          case 1:
            i--;
            break;
          case 2:
            j--;
            break;
        }
      }
    }
    
    // 경로 반전 (시작부터 끝까지)
    alignmentPath.add(AlignmentPoint(
      referenceIndex: 0,
      userIndex: 0,
      referenceTime: 0,
      userTime: 0,
      distance: distMatrix[0][0],
    ));
    
    final finalPath = alignmentPath.reversed.toList();
    
    // 음표 매칭 분석
    final noteMatchings = <NoteMatching>[];
    for (final point in finalPath) {
      if (point.referenceIndex < refLength && point.userIndex < userLength) {
        final refNote = referencePitch[point.referenceIndex];
        final userNote = userPitch[point.userIndex];
        
        if (refNote > 0 && userNote > 0) {
          final pitchError = 1200 * (math.log(userNote / refNote) / math.log(2));
          final timingError = point.timeDifference;
          
          noteMatchings.add(NoteMatching(
            referenceNote: refNote,
            userNote: userNote,
            referenceTime: point.referenceTime,
            userTime: point.userTime,
            pitchError: pitchError,
            timingError: timingError,
            isCorrect: pitchError.abs() < 50 && timingError < 0.2,
          ));
        }
      }
    }
    
    // 전체 거리 및 정규화
    final totalDistance = costMatrix[refLength - 1][userLength - 1];
    final pathLength = refLength + userLength;
    final normalizedDistance = totalDistance / pathLength;
    
    // 정렬 품질 평가 (0-1)
    final alignmentQuality = _calculateAlignmentQuality(
      normalizedDistance,
      noteMatchings,
    );
    
    // 피드백 생성
    final feedback = _generateFeedback(alignmentQuality, noteMatchings);
    
    return AlignmentResult(
      alignmentPath: finalPath,
      totalDistance: totalDistance,
      normalizedDistance: normalizedDistance,
      noteMatchings: noteMatchings,
      alignmentQuality: alignmentQuality,
      feedback: feedback,
    );
  }
  
  /// 정렬 품질 계산
  double _calculateAlignmentQuality(
    double normalizedDistance,
    List<NoteMatching> noteMatchings,
  ) {
    if (noteMatchings.isEmpty) return 0.0;
    
    // 정확한 매칭 비율
    final correctMatches = noteMatchings.where((m) => m.isCorrect).length;
    final matchAccuracy = correctMatches / noteMatchings.length;
    
    // 평균 음정 오차
    final avgPitchError = noteMatchings
        .map((m) => m.pitchError.abs())
        .reduce((a, b) => a + b) / noteMatchings.length;
    
    // 평균 타이밍 오차
    final avgTimingError = noteMatchings
        .map((m) => m.timingError)
        .reduce((a, b) => a + b) / noteMatchings.length;
    
    // 품질 점수 계산 (가중 평균)
    final pitchScore = math.max(0, 1 - avgPitchError / 100);
    final timingScore = math.max(0, 1 - avgTimingError / 0.5);
    final distanceScore = math.max(0, 1 - normalizedDistance / 200);
    
    return (matchAccuracy * 0.4 + 
            pitchScore * 0.3 + 
            timingScore * 0.2 + 
            distanceScore * 0.1).clamp(0.0, 1.0);
  }
  
  /// 사용자 피드백 생성
  String _generateFeedback(
    double quality,
    List<NoteMatching> noteMatchings,
  ) {
    if (noteMatchings.isEmpty) {
      return '분석할 수 있는 음정이 없습니다';
    }
    
    final correctCount = noteMatchings.where((m) => m.isCorrect).length;
    final totalCount = noteMatchings.length;
    final accuracy = (correctCount / totalCount * 100).toStringAsFixed(1);
    
    // 음정 오차 분석
    final pitchErrors = noteMatchings.map((m) => m.pitchError.abs()).toList();
    final avgPitchError = pitchErrors.reduce((a, b) => a + b) / pitchErrors.length;
    
    // 타이밍 오차 분석
    final timingErrors = noteMatchings.map((m) => m.timingError).toList();
    final avgTimingError = timingErrors.reduce((a, b) => a + b) / timingErrors.length;
    
    String feedback = '전체 정확도: $accuracy%\n';
    
    if (quality > 0.9) {
      feedback += '🌟 탁월한 연주입니다! 음정과 타이밍이 거의 완벽합니다.';
    } else if (quality > 0.7) {
      feedback += '👍 좋은 연주입니다! ';
      if (avgPitchError > 30) {
        feedback += '음정을 조금 더 정확히 내면 더 좋을 것 같습니다.';
      } else if (avgTimingError > 0.2) {
        feedback += '박자를 좀 더 정확히 맞추면 완벽할 것 같습니다.';
      }
    } else if (quality > 0.5) {
      feedback += '💪 괜찮은 시도입니다! ';
      if (avgPitchError > 50) {
        feedback += '음정 연습이 더 필요합니다. ';
      }
      if (avgTimingError > 0.3) {
        feedback += '템포를 일정하게 유지하는 연습이 필요합니다.';
      }
    } else {
      feedback += '🎯 더 연습이 필요합니다. ';
      feedback += '천천히 원곡을 들으며 음정과 박자를 익혀보세요.';
    }
    
    // 구체적인 개선 포인트
    if (avgPitchError > 25) {
      feedback += '\n\n📊 평균 음정 오차: ${avgPitchError.toStringAsFixed(0)} cents';
      if (avgPitchError > 50) {
        feedback += ' (반음의 ${(avgPitchError / 100).toStringAsFixed(1)}배)';
      }
    }
    
    if (avgTimingError > 0.1) {
      feedback += '\n⏱️ 평균 타이밍 오차: ${(avgTimingError * 1000).toStringAsFixed(0)}ms';
    }
    
    return feedback;
  }
  
  /// 노트 시퀀스를 세그먼트로 분할 (프레이즈 단위 분석)
  List<List<double>> segmentMelody(
    List<double> pitchSequence,
    {double silenceThreshold = 50.0, int minSegmentLength = 10}
  ) {
    final segments = <List<double>>[];
    var currentSegment = <double>[];
    
    for (final pitch in pitchSequence) {
      if (pitch > silenceThreshold) {
        currentSegment.add(pitch);
      } else {
        // 침묵 구간 발견
        if (currentSegment.length >= minSegmentLength) {
          segments.add(List.from(currentSegment));
        }
        currentSegment.clear();
      }
    }
    
    // 마지막 세그먼트 추가
    if (currentSegment.length >= minSegmentLength) {
      segments.add(currentSegment);
    }
    
    return segments;
  }
  
  /// 실시간 정렬 (스트리밍 모드)
  /// 사용자가 노래하는 동안 실시간으로 정렬
  class RealtimeAligner {
    final List<double> referenceMelody;
    final List<double> userBuffer = [];
    final int windowSize;
    final double sampleRate;
    
    RealtimeAligner({
      required this.referenceMelody,
      this.windowSize = 500,  // 5초 윈도우 (100Hz 기준)
      this.sampleRate = 100.0,
    });
    
    /// 새로운 피치 데이터 추가
    void addPitchData(double pitch) {
      userBuffer.add(pitch);
      
      // 버퍼 크기 제한
      if (userBuffer.length > windowSize * 2) {
        userBuffer.removeRange(0, userBuffer.length - windowSize);
      }
    }
    
    /// 현재까지의 정렬 결과 계산
    AlignmentResult? getCurrentAlignment(DTWMelodyAligner aligner) {
      if (userBuffer.length < 10) return null;
      
      // 현재 위치 추정
      final currentPosition = _estimateCurrentPosition();
      
      // 참조 멜로디의 해당 구간 추출
      final startIdx = math.max(0, currentPosition - windowSize ~/ 2);
      final endIdx = math.min(
        referenceMelody.length,
        currentPosition + windowSize ~/ 2,
      );
      
      if (endIdx <= startIdx) return null;
      
      final refSegment = referenceMelody.sublist(startIdx, endIdx);
      
      // DTW 정렬 수행
      return aligner.alignMelody(refSegment, userBuffer);
    }
    
    /// 현재 위치 추정 (간단한 휴리스틱)
    int _estimateCurrentPosition() {
      // 실제 구현에서는 더 정교한 추정 알고리즘 사용
      // 예: 이전 정렬 결과 기반 추정
      return (userBuffer.length * referenceMelody.length ~/ 
              (windowSize * 2)).clamp(0, referenceMelody.length - 1);
    }
  }
}

/// DTW 시각화를 위한 헬퍼 클래스
class DTWVisualizationData {
  final List<List<double>> costMatrix;
  final List<DTWMelodyAligner.AlignmentPoint> optimalPath;
  final int referenceLength;
  final int userLength;
  
  DTWVisualizationData({
    required this.costMatrix,
    required this.optimalPath,
    required this.referenceLength,
    required this.userLength,
  });
  
  /// 히트맵용 정규화된 매트릭스
  List<List<double>> get normalizedMatrix {
    double maxVal = 0;
    for (final row in costMatrix) {
      for (final val in row) {
        if (val != double.infinity && val > maxVal) {
          maxVal = val;
        }
      }
    }
    
    return costMatrix.map((row) {
      return row.map((val) {
        if (val == double.infinity) return 1.0;
        return (val / maxVal).clamp(0.0, 1.0);
      }).toList();
    }).toList();
  }
}