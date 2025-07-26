# 사용자 데이터 수집 전략

## 개요

AI 보컬 트레이너의 지속적인 개선을 위한 사용자 데이터 수집 전략입니다. 개인정보 보호와 데이터 품질을 모두 고려한 윤리적이고 효과적인 접근 방식을 제시합니다.

## 1. 데이터 수집 원칙

### 1.1 개인정보 보호 우선
- **완전 익명화**: 음성 데이터는 개인 식별이 불가능하도록 처리
- **선택적 참여**: 사용자가 데이터 수집 여부를 자유롭게 선택
- **투명성**: 수집 목적과 사용 방법 명확한 고지
- **최소 수집**: AI 개선에 필요한 최소한의 데이터만 수집

### 1.2 데이터 품질 보장
- **전문가 검증**: 수집된 데이터의 전문가 레이블링
- **다양성 확보**: 다양한 레벨과 연령대의 사용자 데이터
- **지속적 검증**: 주기적인 데이터 품질 평가 및 개선

## 2. 수집 데이터 유형

### 2.1 핵심 음성 특성 데이터
```dart
class CollectedVocalData {
  // 익명화된 식별자
  final String anonymousUserId;
  
  // 음성 분석 결과 (개인 식별 불가능한 수치 데이터만)
  final double pitchStability;
  final BreathingType breathingType;
  final ResonancePosition resonancePosition;
  final VibratoQuality vibratoQuality;
  final int overallScore;
  
  // 훈련 컨텍스트
  final TrainingMode trainingMode;
  final TrainingDifficulty difficulty;
  final Duration sessionDuration;
  
  // 전문가 평가 (옵션)
  final int? expertScore;
  final String? expertFeedback;
  
  // 메타데이터
  final DateTime timestamp;
  final String appVersion;
  final bool isConsentGiven;
}
```

### 2.2 학습 진행도 데이터
- 단계별 진행 속도
- 개선 패턴
- 어려움을 겪는 영역
- 효과적인 피드백 유형

### 2.3 사용 패턴 데이터
- 연습 빈도와 시간
- 선호하는 훈련 모드
- 앱 사용 패턴
- 피드백 반응도

## 3. 데이터 수집 구현

### 3.1 동의 관리 시스템
```dart
class DataCollectionConsent {
  static const String CONSENT_KEY = 'data_collection_consent';
  
  static Future<bool> hasUserConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(CONSENT_KEY) ?? false;
  }
  
  static Future<void> setUserConsent(bool consent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(CONSENT_KEY, consent);
  }
  
  static Widget buildConsentDialog(BuildContext context) {
    return AlertDialog(
      title: Text('AI 개선을 위한 데이터 협조'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('더 나은 AI 보컬 트레이너를 만들기 위해 익명화된 학습 데이터를 수집하고 있습니다.'),
          SizedBox(height: 16),
          _buildDataUsageInfo(),
          SizedBox(height: 16),
          _buildPrivacyGarantees(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _handleConsentDecision(context, false),
          child: Text('참여하지 않기'),
        ),
        ElevatedButton(
          onPressed: () => _handleConsentDecision(context, true),
          child: Text('참여하기'),
        ),
      ],
    );
  }
}
```

### 3.2 데이터 익명화 처리
```dart
class DataAnonymizer {
  static const String _saltKey = 'anonymization_salt';
  
  static String generateAnonymousId(String deviceId) {
    // 디바이스 ID를 일방향 해시로 변환
    final salt = _getSalt();
    final combined = deviceId + salt;
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
  
  static CollectedVocalData anonymizeVocalAnalysis(
    VocalAnalysis analysis,
    TrainingMode mode,
    TrainingDifficulty difficulty,
  ) {
    return CollectedVocalData(
      anonymousUserId: generateAnonymousId(deviceId),
      pitchStability: analysis.pitchStability,
      breathingType: analysis.breathingType,
      resonancePosition: analysis.resonancePosition,
      vibratoQuality: analysis.vibratoQuality,
      overallScore: analysis.overallScore,
      trainingMode: mode,
      difficulty: difficulty,
      timestamp: DateTime.now().toUtc(),
      appVersion: _getAppVersion(),
      isConsentGiven: true,
    );
  }
  
  static bool _containsPersonalInfo(dynamic data) {
    // 개인정보 포함 여부 검사 로직
    return false;
  }
}
```

### 3.3 안전한 데이터 전송
```dart
class SecureDataTransmission {
  static const String COLLECTION_ENDPOINT = 'https://api.vocaltrainer.ai/data/collect';
  
  static Future<bool> sendCollectedData(List<CollectedVocalData> dataSet) async {
    try {
      // 데이터 검증
      if (!_validateDataSet(dataSet)) {
        return false;
      }
      
      // 암호화
      final encryptedData = await _encryptDataSet(dataSet);
      
      // 전송
      final response = await http.post(
        Uri.parse(COLLECTION_ENDPOINT),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Version': '1.0',
          'X-Client-Version': await _getAppVersion(),
        },
        body: json.encode({
          'data': encryptedData,
          'timestamp': DateTime.now().toIso8601String(),
          'dataCount': dataSet.length,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('데이터 전송 실패: $e');
      return false;
    }
  }
  
  static bool _validateDataSet(List<CollectedVocalData> dataSet) {
    return dataSet.every((data) => 
      data.isConsentGiven && 
      !DataAnonymizer._containsPersonalInfo(data)
    );
  }
}
```

## 4. 데이터 활용 계획

### 4.1 AI 모델 개선
- **피드백 정확도 향상**: 사용자 반응 데이터로 피드백 알고리즘 개선
- **개인화 알고리즘**: 학습 패턴 기반 맞춤형 훈련 코스 개발
- **새로운 평가 지표**: 기존 전문가 기준과 실제 사용자 데이터 비교 분석

### 4.2 훈련 커리큘럼 최적화
- **효과적인 학습 순서**: 데이터 기반 최적 훈련 단계 설계
- **난이도 조절**: 사용자 진행 속도에 맞는 난이도 자동 조절
- **취약점 파악**: 많은 사용자가 어려워하는 영역 식별 및 개선

### 4.3 새로운 기능 개발
- **트렌드 분석**: 사용자 요구사항 기반 신기능 개발
- **성능 최적화**: 실제 사용 패턴 기반 앱 성능 개선

## 5. 데이터 보안 및 저장

### 5.1 저장 방식
```dart
class SecureDataStorage {
  static const String LOCAL_STORAGE_KEY = 'pending_collection_data';
  
  static Future<void> storeDataLocally(CollectedVocalData data) async {
    final prefs = await SharedPreferences.getInstance();
    final existingData = prefs.getStringList(LOCAL_STORAGE_KEY) ?? [];
    
    // 암호화하여 저장
    final encryptedData = await _encryptData(data);
    existingData.add(encryptedData);
    
    // 최대 100개까지만 로컬 저장
    if (existingData.length > 100) {
      existingData.removeAt(0);
    }
    
    await prefs.setStringList(LOCAL_STORAGE_KEY, existingData);
  }
  
  static Future<void> uploadPendingData() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingData = prefs.getStringList(LOCAL_STORAGE_KEY) ?? [];
    
    if (pendingData.isNotEmpty) {
      final decryptedData = <CollectedVocalData>[];
      for (final encrypted in pendingData) {
        final data = await _decryptData(encrypted);
        decryptedData.add(data);
      }
      
      final success = await SecureDataTransmission.sendCollectedData(decryptedData);
      if (success) {
        await prefs.remove(LOCAL_STORAGE_KEY);
      }
    }
  }
}
```

### 5.2 서버 보안
- **종단간 암호화**: 클라이언트에서 서버까지 전체 구간 암호화
- **접근 제어**: 권한이 있는 연구진만 데이터 접근 가능
- **정기적 감사**: 데이터 접근 및 사용 내역 정기 검토
- **자동 삭제**: 연구 목적 달성 후 자동 데이터 삭제

## 6. 사용자 권리 보장

### 6.1 투명성 제공
```dart
class DataTransparency {
  static Widget buildDataUsageInfoPage() {
    return Scaffold(
      appBar: AppBar(title: Text('데이터 사용 현황')),
      body: Column(
        children: [
          _buildCollectionStats(),
          _buildUsageDescription(),
          _buildConsentManager(),
          _buildDataDeletionOption(),
        ],
      ),
    );
  }
  
  static Widget _buildCollectionStats() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('수집된 데이터 현황', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('익명화된 세션 수:'),
                Text('${UserDataManager.getCollectedSessionCount()}'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('마지막 전송:'),
                Text('${UserDataManager.getLastUploadDate()}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

### 6.2 동의 철회 및 데이터 삭제
```dart
class ConsentManagement {
  static Future<void> withdrawConsent() async {
    // 로컬 동의 상태 변경
    await DataCollectionConsent.setUserConsent(false);
    
    // 로컬 저장된 대기 중인 데이터 삭제
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SecureDataStorage.LOCAL_STORAGE_KEY);
    
    // 서버에 데이터 삭제 요청
    await _requestDataDeletion();
  }
  
  static Future<void> _requestDataDeletion() async {
    try {
      final anonymousId = DataAnonymizer.generateAnonymousId(deviceId);
      await http.delete(
        Uri.parse('https://api.vocaltrainer.ai/data/user/$anonymousId'),
        headers: {'Authorization': 'Bearer ${await _getAuthToken()}'},
      );
    } catch (e) {
      print('데이터 삭제 요청 실패: $e');
    }
  }
}
```

## 7. 품질 보장 프로세스

### 7.1 전문가 검증
```dart
class ExpertValidation {
  static Future<void> submitForExpertReview(CollectedVocalData data) async {
    if (data.overallScore > 90 || data.overallScore < 30) {
      // 극단적인 점수는 전문가 검증 요청
      await _requestExpertReview(data);
    }
  }
  
  static Future<void> _requestExpertReview(CollectedVocalData data) async {
    final reviewRequest = {
      'dataId': data.anonymousUserId,
      'analysisResults': data.toJson(),
      'aiScore': data.overallScore,
      'requestType': 'verification',
      'priority': data.overallScore < 30 ? 'high' : 'normal',
    };
    
    await http.post(
      Uri.parse('https://api.vocaltrainer.ai/expert/review'),
      body: json.encode(reviewRequest),
    );
  }
}
```

### 7.2 데이터 품질 모니터링
```dart
class DataQualityMonitor {
  static Future<DataQualityReport> generateQualityReport() async {
    final recentData = await _getRecentCollectedData();
    
    return DataQualityReport(
      totalSamples: recentData.length,
      averageScore: _calculateAverageScore(recentData),
      scoreDistribution: _analyzeScoreDistribution(recentData),
      modeDistribution: _analyzeModeDistribution(recentData),
      anomalies: _detectAnomalies(recentData),
    );
  }
  
  static List<DataAnomaly> _detectAnomalies(List<CollectedVocalData> data) {
    final anomalies = <DataAnomaly>[];
    
    // 비정상적인 패턴 감지
    for (final sample in data) {
      if (sample.pitchStability > 1.0 || sample.pitchStability < 0.0) {
        anomalies.add(DataAnomaly(
          type: 'invalid_pitch_stability',
          value: sample.pitchStability,
          dataId: sample.anonymousUserId,
        ));
      }
    }
    
    return anomalies;
  }
}
```

## 8. 윤리적 고려사항

### 8.1 데이터 사용 원칙
- **목적 제한**: 수집 목적 외 사용 금지
- **최소 수집**: 필요한 최소한의 데이터만 수집
- **정기 삭제**: 목적 달성 후 자동 삭제
- **투명한 운영**: 데이터 사용 현황 공개

### 8.2 편향 방지
- **다양성 확보**: 연령, 성별, 지역 등 다양한 사용자 데이터
- **균형잡힌 샘플링**: 특정 그룹에 편중되지 않도록 조절
- **지속적 모니터링**: 편향 발생 여부 정기 점검

## 9. 법적 준수

### 9.1 개인정보보호법 준수
- **수집 동의**: 명시적 동의 절차
- **목적 고지**: 수집 목적 명확한 안내
- **안전한 보관**: 기술적, 관리적 보호조치
- **삭제 권리**: 사용자 요청 시 즉시 삭제

### 9.2 국제 표준 준수
- **GDPR 준수**: EU 개인정보보호 규정 준수
- **CCPA 준수**: 캘리포니아 소비자 프라이버시법 준수
- **ISO 27001**: 정보보안 관리체계 인증

## 10. 실행 계획

### 10.1 단계별 구현
1. **1단계 (1-2개월)**: 기본 수집 시스템 구축
2. **2단계 (3-4개월)**: 전문가 검증 시스템 추가
3. **3단계 (5-6개월)**: 품질 모니터링 자동화
4. **4단계 (7-8개월)**: AI 모델 개선 적용

### 10.2 성공 지표
- **참여율**: 전체 사용자 중 30% 이상 데이터 수집 동의
- **품질 점수**: 전문가 검증 통과율 95% 이상
- **AI 개선**: 피드백 정확도 15% 이상 향상
- **사용자 만족도**: 앱 평점 4.5점 이상 유지

이 전략을 통해 사용자 프라이버시를 보호하면서도 AI 시스템의 지속적인 개선을 위한 양질의 데이터를 수집할 수 있습니다.