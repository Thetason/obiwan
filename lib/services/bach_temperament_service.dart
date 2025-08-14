import 'dart:math' as math;

/// 바흐 평균율(Well-Tempered) 기반 음정 분석 서비스
/// 12평균율(12-TET) 체계로 모든 조성의 음정을 정확히 분석
class BachTemperamentService {
  static const double _A4_FREQUENCY = 440.0; // 표준 A4 (라)
  static const int _SEMITONES_PER_OCTAVE = 12;
  
  /// 바흐 평균율 기준 음계 이름들
  static const List<String> _NOTE_NAMES = [
    'C', 'C#/Db', 'D', 'D#/Eb', 'E', 'F', 
    'F#/Gb', 'G', 'G#/Ab', 'A', 'A#/Bb', 'B'
  ];
  
  /// 독일식 음계 이름 (바흐가 사용한 방식)
  static const List<String> _GERMAN_NOTE_NAMES = [
    'C', 'Cis/Des', 'D', 'Dis/Es', 'E', 'F',
    'Fis/Ges', 'G', 'Gis/As', 'A', 'Ais/B', 'H'
  ];
  
  /// 완전한 12평균율 주파수 테이블 (C0부터 B8까지 108개 음정)
  static final Map<String, double> _COMPLETE_FREQUENCY_TABLE = _generateCompleteFrequencyTable();
  
  /// 주파수를 바흐 평균율 음정으로 변환
  static TemperamentNote frequencyToTemperamentNote(double frequency) {
    if (frequency <= 0) {
      return TemperamentNote.empty();
    }
    
    // A4(440Hz)를 기준으로 반음 계산
    double semitonesFromA4 = 12.0 * (math.log(frequency / _A4_FREQUENCY) / math.ln2);
    
    // 가장 가까운 반음으로 반올림
    int nearestSemitone = semitonesFromA4.round();
    
    // 옥타브와 음계 계산
    int octave = 4 + (nearestSemitone + 9) ~/ 12;
    int noteIndex = (nearestSemitone + 9) % 12;
    if (noteIndex < 0) {
      noteIndex += 12;
      octave--;
    }
    
    // 이론적 주파수 계산
    double theoreticalFreq = _A4_FREQUENCY * math.pow(2, nearestSemitone / 12.0);
    
    // 센트 단위 오차 계산 (1 반음 = 100 센트)
    double centsError = 1200.0 * (math.log(frequency / theoreticalFreq) / math.ln2);
    
    return TemperamentNote(
      noteName: _NOTE_NAMES[noteIndex],
      germanName: _GERMAN_NOTE_NAMES[noteIndex],
      octave: octave,
      frequency: frequency,
      theoreticalFrequency: theoreticalFreq,
      centsError: centsError,
      semitoneFromA4: nearestSemitone,
    );
  }
  
  /// 완전한 주파수 테이블 생성 (C0~B8)
  static Map<String, double> _generateCompleteFrequencyTable() {
    final Map<String, double> table = {};
    
    for (int octave = 0; octave <= 8; octave++) {
      for (int noteIndex = 0; noteIndex < 12; noteIndex++) {
        final noteName = _NOTE_NAMES[noteIndex];
        final fullNoteName = '$noteName$octave';
        
        // C4 = 261.63Hz를 기준으로 계산
        double c4Frequency = 261.6255653005986;
        int semitonesFromC4 = (octave - 4) * 12 + noteIndex;
        double frequency = c4Frequency * math.pow(2, semitonesFromC4 / 12.0);
        
        table[fullNoteName] = frequency;
      }
    }
    
    return table;
  }
  
  /// 특정 음정의 이론적 주파수 반환
  static double getTheoreticalFrequency(String noteName, int octave) {
    final fullName = '$noteName$octave';
    return _COMPLETE_FREQUENCY_TABLE[fullName] ?? 0.0;
  }
  
  /// 모든 음정 리스트 반환
  static List<String> getAllNotes() {
    return _COMPLETE_FREQUENCY_TABLE.keys.toList()..sort();
  }
  
  /// 조성별 스케일 분석
  static List<TemperamentNote> analyzeScale(String rootNote, ScaleType scaleType) {
    final intervals = _getScaleIntervals(scaleType);
    final notes = <TemperamentNote>[];
    
    // 루트 음정부터 시작해서 스케일 구성
    int rootIndex = _NOTE_NAMES.indexOf(rootNote);
    if (rootIndex == -1) rootIndex = 0;
    
    for (int interval in intervals) {
      int noteIndex = (rootIndex + interval) % 12;
      String noteName = _NOTE_NAMES[noteIndex];
      double frequency = getTheoreticalFrequency(noteName, 4);
      notes.add(frequencyToTemperamentNote(frequency));
    }
    
    return notes;
  }
  
  /// 스케일 타입별 인터벌 반환
  static List<int> _getScaleIntervals(ScaleType scaleType) {
    switch (scaleType) {
      case ScaleType.major:
        return [0, 2, 4, 5, 7, 9, 11]; // 도레미파솔라시
      case ScaleType.minor:
        return [0, 2, 3, 5, 7, 8, 10]; // 자연단조
      case ScaleType.harmonicMinor:
        return [0, 2, 3, 5, 7, 8, 11]; // 화성단조
      case ScaleType.melodicMinor:
        return [0, 2, 3, 5, 7, 9, 11]; // 선율단조
      case ScaleType.dorian:
        return [0, 2, 3, 5, 7, 9, 10]; // 도리안
      case ScaleType.chromatic:
        return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]; // 반음계
    }
  }
  
  /// 코드 분석
  static List<TemperamentNote> analyzeChord(String rootNote, ChordType chordType) {
    final intervals = _getChordIntervals(chordType);
    final notes = <TemperamentNote>[];
    
    int rootIndex = _NOTE_NAMES.indexOf(rootNote);
    if (rootIndex == -1) rootIndex = 0;
    
    for (int interval in intervals) {
      int noteIndex = (rootIndex + interval) % 12;
      String noteName = _NOTE_NAMES[noteIndex];
      double frequency = getTheoreticalFrequency(noteName, 4);
      notes.add(frequencyToTemperamentNote(frequency));
    }
    
    return notes;
  }
  
  /// 코드 타입별 인터벌 반환
  static List<int> _getChordIntervals(ChordType chordType) {
    switch (chordType) {
      case ChordType.major:
        return [0, 4, 7]; // 장3화음
      case ChordType.minor:
        return [0, 3, 7]; // 단3화음
      case ChordType.diminished:
        return [0, 3, 6]; // 감3화음
      case ChordType.augmented:
        return [0, 4, 8]; // 증3화음
      case ChordType.major7:
        return [0, 4, 7, 11]; // 장7화음
      case ChordType.minor7:
        return [0, 3, 7, 10]; // 단7화음
      case ChordType.dominant7:
        return [0, 4, 7, 10]; // 속7화음
    }
  }
}

/// 바흐 평균율 음정 정보 클래스
class TemperamentNote {
  final String noteName;        // 음계 이름 (C, D, E, ...)
  final String germanName;      // 독일식 이름 (바흐 방식)
  final int octave;            // 옥타브
  final double frequency;      // 실제 주파수
  final double theoreticalFrequency; // 이론적 주파수
  final double centsError;     // 센트 단위 오차
  final int semitoneFromA4;    // A4로부터의 반음 거리
  
  const TemperamentNote({
    required this.noteName,
    required this.germanName,
    required this.octave,
    required this.frequency,
    required this.theoreticalFrequency,
    required this.centsError,
    required this.semitoneFromA4,
  });
  
  factory TemperamentNote.empty() {
    return const TemperamentNote(
      noteName: '',
      germanName: '',
      octave: 0,
      frequency: 0.0,
      theoreticalFrequency: 0.0,
      centsError: 0.0,
      semitoneFromA4: 0,
    );
  }
  
  /// 전체 음정 이름 (음계 + 옥타브)
  String get fullName => '$noteName$octave';
  
  /// 독일식 전체 이름
  String get germanFullName => '$germanName$octave';
  
  /// 음정 정확도 (센트 기준)
  double get accuracy => math.max(0, 100 - centsError.abs());
  
  /// 음정 상태
  TemperamentAccuracy get accuracyLevel {
    double absCents = centsError.abs();
    if (absCents < 5) return TemperamentAccuracy.perfect;
    if (absCents < 10) return TemperamentAccuracy.excellent;
    if (absCents < 20) return TemperamentAccuracy.good;
    if (absCents < 50) return TemperamentAccuracy.fair;
    return TemperamentAccuracy.poor;
  }
  
  @override
  String toString() {
    return '$fullName (${frequency.toStringAsFixed(1)}Hz, ${centsError.toStringAsFixed(1)}¢)';
  }
}

/// 스케일 타입
enum ScaleType {
  major,          // 장조
  minor,          // 단조
  harmonicMinor,  // 화성단조
  melodicMinor,   // 선율단조
  dorian,         // 도리안
  chromatic,      // 반음계
}

/// 코드 타입  
enum ChordType {
  major,        // 장3화음
  minor,        // 단3화음
  diminished,   // 감3화음
  augmented,    // 증3화음
  major7,       // 장7화음
  minor7,       // 단7화음
  dominant7,    // 속7화음
}

/// 음정 정확도 레벨
enum TemperamentAccuracy {
  perfect,    // 완벽 (±5센트)
  excellent,  // 우수 (±10센트)
  good,       // 양호 (±20센트)
  fair,       // 보통 (±50센트)
  poor,       // 미흡 (±50센트 초과)
}