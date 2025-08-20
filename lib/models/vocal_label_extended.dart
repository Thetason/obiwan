/// Extended Vocal Label Model for Double-Check System
/// AI 초벌 라벨링 + 사용자 검증 시스템
class VocalLabel {
  final String id;
  final String source; // 'youtube', 'local', 'recording'
  final String artist;
  final String title;
  final DateTime timestamp;
  
  // AI Analysis Results
  final double confidence; // AI 신뢰도 (0-1)
  final double pitchAccuracy; // 음정 정확도 (0-1)
  final double? avgFrequency; // 평균 주파수
  final String? vocalRange; // 음역대
  final String? techniqueType; // 발성 기법
  final double? duration; // 길이 (초)
  
  // Quality Scores
  final int? quality; // 1-5 stars
  final double? technique; // 0-1
  final double? emotion; // 0-1
  
  // Double-Check System Fields
  final bool humanVerified; // 사용자 검증 여부
  final DateTime? verifiedAt; // 검증 시간
  final String? verifiedBy; // 검증자
  final String? notes; // 검토 노트
  final String? rejectionReason; // 거부 사유
  
  // Status
  final LabelStatus status; // pending, approved, rejected, modified
  
  VocalLabel({
    required this.id,
    required this.source,
    required this.artist,
    required this.title,
    required this.timestamp,
    required this.confidence,
    required this.pitchAccuracy,
    this.avgFrequency,
    this.vocalRange,
    this.techniqueType,
    this.duration,
    this.quality,
    this.technique,
    this.emotion,
    this.humanVerified = false,
    this.verifiedAt,
    this.verifiedBy,
    this.notes,
    this.rejectionReason,
    this.status = LabelStatus.pending,
  });
  
  /// Copy with modifications
  VocalLabel copyWith({
    String? id,
    String? source,
    String? artist,
    String? title,
    DateTime? timestamp,
    double? confidence,
    double? pitchAccuracy,
    double? avgFrequency,
    String? vocalRange,
    String? techniqueType,
    double? duration,
    int? quality,
    double? technique,
    double? emotion,
    bool? humanVerified,
    DateTime? verifiedAt,
    String? verifiedBy,
    String? notes,
    String? rejectionReason,
    LabelStatus? status,
  }) {
    return VocalLabel(
      id: id ?? this.id,
      source: source ?? this.source,
      artist: artist ?? this.artist,
      title: title ?? this.title,
      timestamp: timestamp ?? this.timestamp,
      confidence: confidence ?? this.confidence,
      pitchAccuracy: pitchAccuracy ?? this.pitchAccuracy,
      avgFrequency: avgFrequency ?? this.avgFrequency,
      vocalRange: vocalRange ?? this.vocalRange,
      techniqueType: techniqueType ?? this.techniqueType,
      duration: duration ?? this.duration,
      quality: quality ?? this.quality,
      technique: technique ?? this.technique,
      emotion: emotion ?? this.emotion,
      humanVerified: humanVerified ?? this.humanVerified,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      notes: notes ?? this.notes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      status: status ?? this.status,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source': source,
      'artist': artist,
      'title': title,
      'timestamp': timestamp.toIso8601String(),
      'confidence': confidence,
      'pitchAccuracy': pitchAccuracy,
      'avgFrequency': avgFrequency,
      'vocalRange': vocalRange,
      'techniqueType': techniqueType,
      'duration': duration,
      'quality': quality,
      'technique': technique,
      'emotion': emotion,
      'humanVerified': humanVerified,
      'verifiedAt': verifiedAt?.toIso8601String(),
      'verifiedBy': verifiedBy,
      'notes': notes,
      'rejectionReason': rejectionReason,
      'status': status.toString().split('.').last,
    };
  }
  
  factory VocalLabel.fromJson(Map<String, dynamic> json) {
    return VocalLabel(
      id: json['id'],
      source: json['source'],
      artist: json['artist'],
      title: json['title'],
      timestamp: DateTime.parse(json['timestamp']),
      confidence: json['confidence'].toDouble(),
      pitchAccuracy: json['pitchAccuracy'].toDouble(),
      avgFrequency: json['avgFrequency']?.toDouble(),
      vocalRange: json['vocalRange'],
      techniqueType: json['techniqueType'],
      duration: json['duration']?.toDouble(),
      quality: json['quality'],
      technique: json['technique']?.toDouble(),
      emotion: json['emotion']?.toDouble(),
      humanVerified: json['humanVerified'] ?? false,
      verifiedAt: json['verifiedAt'] != null 
        ? DateTime.parse(json['verifiedAt']) 
        : null,
      verifiedBy: json['verifiedBy'],
      notes: json['notes'],
      rejectionReason: json['rejectionReason'],
      status: _parseStatus(json['status']),
    );
  }
  
  static LabelStatus _parseStatus(String? status) {
    switch (status) {
      case 'approved':
        return LabelStatus.approved;
      case 'rejected':
        return LabelStatus.rejected;
      case 'modified':
        return LabelStatus.modified;
      default:
        return LabelStatus.pending;
    }
  }
  
  /// 신뢰도 레벨 계산
  String get confidenceLevel {
    if (confidence > 0.8) return 'HIGH';
    if (confidence > 0.6) return 'MEDIUM';
    return 'LOW';
  }
  
  /// 품질 별점 텍스트
  String get qualityStars {
    if (quality == null) return '미평가';
    return '⭐' * quality!;
  }
  
  /// 검증 상태 텍스트
  String get verificationStatus {
    if (humanVerified) {
      return '✅ 검증됨';
    } else {
      return '⏳ 대기중';
    }
  }
}

/// 라벨 상태
enum LabelStatus {
  pending,  // AI 생성 완료, 검토 대기
  approved, // 사용자 승인
  rejected, // 사용자 거부
  modified, // 사용자 수정 후 승인
}

/// 더블체크 통계
class DoubleCheckStats {
  final int totalLabels;
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;
  final int modifiedCount;
  final double avgConfidence;
  final double approvalRate;
  
  DoubleCheckStats({
    required this.totalLabels,
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.modifiedCount,
    required this.avgConfidence,
    required this.approvalRate,
  });
  
  factory DoubleCheckStats.fromLabels(List<VocalLabel> labels) {
    final total = labels.length;
    if (total == 0) {
      return DoubleCheckStats(
        totalLabels: 0,
        pendingCount: 0,
        approvedCount: 0,
        rejectedCount: 0,
        modifiedCount: 0,
        avgConfidence: 0,
        approvalRate: 0,
      );
    }
    
    int pending = 0, approved = 0, rejected = 0, modified = 0;
    double totalConfidence = 0;
    
    for (final label in labels) {
      totalConfidence += label.confidence;
      switch (label.status) {
        case LabelStatus.pending:
          pending++;
          break;
        case LabelStatus.approved:
          approved++;
          break;
        case LabelStatus.rejected:
          rejected++;
          break;
        case LabelStatus.modified:
          modified++;
          break;
      }
    }
    
    final verifiedCount = approved + modified;
    final processedCount = verifiedCount + rejected;
    
    return DoubleCheckStats(
      totalLabels: total,
      pendingCount: pending,
      approvedCount: approved,
      rejectedCount: rejected,
      modifiedCount: modified,
      avgConfidence: totalConfidence / total,
      approvalRate: processedCount > 0 ? verifiedCount / processedCount : 0,
    );
  }
  
  /// 진행률 (0-1)
  double get progressRate => totalLabels > 0 
    ? (approvedCount + rejectedCount + modifiedCount) / totalLabels 
    : 0;
  
  /// 남은 작업 수
  int get remainingCount => pendingCount;
  
  /// 완료된 작업 수
  int get completedCount => approvedCount + rejectedCount + modifiedCount;
}