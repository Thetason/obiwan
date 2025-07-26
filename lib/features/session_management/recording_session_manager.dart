import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Comprehensive recording session management with cloud sync capabilities
class RecordingSessionManager {
  static const String _sessionsKey = 'vocal_training_sessions';
  static const String _userIdKey = 'user_id';
  static const int _maxLocalSessions = 50;
  
  final StreamController<List<VocalSession>> _sessionsController = 
      StreamController<List<VocalSession>>.broadcast();
  
  Stream<List<VocalSession>> get sessionsStream => _sessionsController.stream;
  
  List<VocalSession> _sessions = [];
  late SharedPreferences _prefs;
  CloudSyncService? _cloudSync;
  String? _userId;
  
  Future<void> initialize({CloudSyncService? cloudSync}) async {
    _prefs = await SharedPreferences.getInstance();
    _cloudSync = cloudSync;
    _userId = _prefs.getString(_userIdKey) ?? _generateUserId();
    await _prefs.setString(_userIdKey, _userId!);
    
    await _loadLocalSessions();
    if (_cloudSync != null) {
      await _syncWithCloud();
    }
  }
  
  /// Create a new recording session
  Future<VocalSession> createSession({
    required String name,
    SessionType type = SessionType.practice,
    Map<String, dynamic>? metadata,
  }) async {
    final session = VocalSession(
      id: _generateSessionId(),
      userId: _userId!,
      name: name,
      type: type,
      createdAt: DateTime.now(),
      metadata: metadata ?? {},
    );
    
    _sessions.insert(0, session);
    await _saveLocalSessions();
    _sessionsController.add(List.from(_sessions));
    
    if (_cloudSync != null) {
      _cloudSync!.uploadSession(session);
    }
    
    return session;
  }
  
  /// Start recording for a session
  Future<void> startRecording(String sessionId) async {
    final session = _sessions.firstWhere((s) => s.id == sessionId);
    session.startRecording();
    await _saveLocalSessions();
    _sessionsController.add(List.from(_sessions));
  }
  
  /// Stop recording and save audio data
  Future<void> stopRecording(
    String sessionId, 
    Float32List audioData,
    {VocalAnalysisResult? analysis}
  ) async {
    final session = _sessions.firstWhere((s) => s.id == sessionId);
    
    final recording = await session.stopRecording(
      audioData: audioData,
      analysis: analysis,
    );
    
    await _saveLocalSessions();
    _sessionsController.add(List.from(_sessions));
    
    if (_cloudSync != null && recording != null) {
      _cloudSync!.uploadRecording(sessionId, recording);
    }
  }
  
  /// Add analysis result to a recording
  Future<void> addAnalysisResult(
    String sessionId,
    String recordingId,
    VocalAnalysisResult analysis
  ) async {
    final session = _sessions.firstWhere((s) => s.id == sessionId);
    final recording = session.recordings.firstWhere((r) => r.id == recordingId);
    
    recording.analysis = analysis;
    recording.updatedAt = DateTime.now();
    
    await _saveLocalSessions();
    _sessionsController.add(List.from(_sessions));
    
    if (_cloudSync != null) {
      _cloudSync!.updateRecording(sessionId, recording);
    }
  }
  
  /// Get session by ID
  VocalSession? getSession(String sessionId) {
    try {
      return _sessions.firstWhere((s) => s.id == sessionId);
    } catch (e) {
      return null;
    }
  }
  
  /// Get all sessions
  List<VocalSession> getAllSessions() => List.from(_sessions);
  
  /// Get sessions by type
  List<VocalSession> getSessionsByType(SessionType type) {
    return _sessions.where((s) => s.type == type).toList();
  }
  
  /// Delete session
  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    await _saveLocalSessions();
    _sessionsController.add(List.from(_sessions));
    
    if (_cloudSync != null) {
      _cloudSync!.deleteSession(sessionId);
    }
  }
  
  /// Get session statistics
  SessionStatistics getSessionStatistics() {
    final now = DateTime.now();
    final thisWeek = now.subtract(const Duration(days: 7));
    final thisMonth = now.subtract(const Duration(days: 30));
    
    final thisWeekSessions = _sessions.where((s) => s.createdAt.isAfter(thisWeek)).length;
    final thisMonthSessions = _sessions.where((s) => s.createdAt.isAfter(thisMonth)).length;
    
    final totalDuration = _sessions.fold<Duration>(
      Duration.zero,
      (sum, session) => sum + session.totalDuration,
    );
    
    final totalRecordings = _sessions.fold<int>(
      0,
      (sum, session) => sum + session.recordings.length,
    );
    
    final averageAccuracy = _sessions
        .expand((s) => s.recordings)
        .where((r) => r.analysis != null)
        .map((r) => r.analysis!.overallScore)
        .fold<double>(0, (sum, score) => sum + score) / 
        math.max(1, _sessions.expand((s) => s.recordings).length);
    
    return SessionStatistics(
      totalSessions: _sessions.length,
      thisWeekSessions: thisWeekSessions,
      thisMonthSessions: thisMonthSessions,
      totalDuration: totalDuration,
      totalRecordings: totalRecordings,
      averageAccuracy: averageAccuracy,
      lastSessionDate: _sessions.isNotEmpty ? _sessions.first.createdAt : null,
    );
  }
  
  /// Export session data
  Future<Map<String, dynamic>> exportSessionData(String sessionId) async {
    final session = getSession(sessionId);
    if (session == null) throw Exception('Session not found');
    
    return {
      'session': session.toJson(),
      'recordings': session.recordings.map((r) => r.toJson()).toList(),
      'exported_at': DateTime.now().toIso8601String(),
      'version': '1.0',
    };
  }
  
  /// Import session data
  Future<void> importSessionData(Map<String, dynamic> data) async {
    try {
      final sessionData = data['session'] as Map<String, dynamic>;
      final session = VocalSession.fromJson(sessionData);
      
      final recordingsData = data['recordings'] as List<dynamic>;
      session.recordings.clear();
      session.recordings.addAll(
        recordingsData.map((r) => VocalRecording.fromJson(r as Map<String, dynamic>))
      );
      
      _sessions.insert(0, session);
      await _saveLocalSessions();
      _sessionsController.add(List.from(_sessions));
    } catch (e) {
      throw Exception('Failed to import session data: $e');
    }
  }
  
  /// Sync with cloud service
  Future<void> _syncWithCloud() async {
    if (_cloudSync == null) return;
    
    try {
      // Download cloud sessions
      final cloudSessions = await _cloudSync!.downloadSessions(_userId!);
      
      // Merge with local sessions
      for (final cloudSession in cloudSessions) {
        final existingIndex = _sessions.indexWhere((s) => s.id == cloudSession.id);
        if (existingIndex >= 0) {
          // Update if cloud version is newer
          if (cloudSession.updatedAt.isAfter(_sessions[existingIndex].updatedAt)) {
            _sessions[existingIndex] = cloudSession;
          }
        } else {
          _sessions.add(cloudSession);
        }
      }
      
      // Sort by creation date
      _sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      await _saveLocalSessions();
      _sessionsController.add(List.from(_sessions));
    } catch (e) {
      debugPrint('Cloud sync error: $e');
    }
  }
  
  /// Save sessions to local storage
  Future<void> _saveLocalSessions() async {
    try {
      // Keep only the most recent sessions to avoid storage issues
      final sessionsToSave = _sessions.take(_maxLocalSessions).toList();
      
      final jsonData = sessionsToSave.map((s) => s.toJson()).toList();
      await _prefs.setString(_sessionsKey, jsonEncode(jsonData));
    } catch (e) {
      debugPrint('Failed to save sessions: $e');
    }
  }
  
  /// Load sessions from local storage
  Future<void> _loadLocalSessions() async {
    try {
      final jsonString = _prefs.getString(_sessionsKey);
      if (jsonString != null) {
        final jsonData = jsonDecode(jsonString) as List<dynamic>;
        _sessions = jsonData
            .map((json) => VocalSession.fromJson(json as Map<String, dynamic>))
            .toList();
        
        _sessionsController.add(List.from(_sessions));
      }
    } catch (e) {
      debugPrint('Failed to load sessions: $e');
      _sessions = [];
    }
  }
  
  String _generateSessionId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_userId?.substring(0, 8)}';
  }
  
  String _generateUserId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${(math.Random().nextDouble() * 1000000).round()}';
  }
  
  void dispose() {
    _sessionsController.close();
  }
}

/// Cloud synchronization service interface
abstract class CloudSyncService {
  Future<void> uploadSession(VocalSession session);
  Future<void> uploadRecording(String sessionId, VocalRecording recording);
  Future<void> updateRecording(String sessionId, VocalRecording recording);
  Future<void> deleteSession(String sessionId);
  Future<List<VocalSession>> downloadSessions(String userId);
}

/// Firebase implementation of cloud sync service
class FirebaseCloudSyncService implements CloudSyncService {
  // Note: This is a mock implementation
  // In a real app, you would integrate with Firebase Firestore
  
  @override
  Future<void> uploadSession(VocalSession session) async {
    // Mock implementation
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint('Uploaded session: ${session.name}');
  }
  
  @override
  Future<void> uploadRecording(String sessionId, VocalRecording recording) async {
    await Future.delayed(const Duration(milliseconds: 300));
    debugPrint('Uploaded recording for session: $sessionId');
  }
  
  @override
  Future<void> updateRecording(String sessionId, VocalRecording recording) async {
    await Future.delayed(const Duration(milliseconds: 200));
    debugPrint('Updated recording for session: $sessionId');
  }
  
  @override
  Future<void> deleteSession(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    debugPrint('Deleted session: $sessionId');
  }
  
  @override
  Future<List<VocalSession>> downloadSessions(String userId) async {
    await Future.delayed(const Duration(seconds: 1));
    debugPrint('Downloaded sessions for user: $userId');
    return [];
  }
}

/// Vocal training session model
class VocalSession {
  final String id;
  final String userId;
  String name;
  final SessionType type;
  final DateTime createdAt;
  DateTime updatedAt;
  SessionStatus status;
  final Map<String, dynamic> metadata;
  final List<VocalRecording> recordings;
  DateTime? recordingStartTime;
  
  VocalSession({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.createdAt,
    DateTime? updatedAt,
    this.status = SessionStatus.created,
    required this.metadata,
    List<VocalRecording>? recordings,
  }) : updatedAt = updatedAt ?? createdAt,
       recordings = recordings ?? [];
  
  Duration get totalDuration {
    return recordings.fold(
      Duration.zero,
      (sum, recording) => sum + recording.duration,
    );
  }
  
  double get averageScore {
    final analyses = recordings
        .where((r) => r.analysis != null)
        .map((r) => r.analysis!.overallScore);
    
    if (analyses.isEmpty) return 0.0;
    return analyses.reduce((a, b) => a + b) / analyses.length;
  }
  
  void startRecording() {
    status = SessionStatus.recording;
    recordingStartTime = DateTime.now();
    updatedAt = DateTime.now();
  }
  
  Future<VocalRecording?> stopRecording({
    required Float32List audioData,
    VocalAnalysisResult? analysis,
  }) async {
    if (status != SessionStatus.recording || recordingStartTime == null) {
      return null;
    }
    
    final duration = DateTime.now().difference(recordingStartTime!);
    
    final recording = VocalRecording(
      id: '${id}_rec_${recordings.length + 1}',
      sessionId: id,
      audioData: audioData,
      duration: duration,
      createdAt: recordingStartTime!,
      analysis: analysis,
    );
    
    recordings.add(recording);
    status = SessionStatus.completed;
    recordingStartTime = null;
    updatedAt = DateTime.now();
    
    return recording;
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'type': type.toString(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status.toString(),
      'metadata': metadata,
      'recordings': recordings.map((r) => r.toJson()).toList(),
    };
  }
  
  factory VocalSession.fromJson(Map<String, dynamic> json) {
    return VocalSession(
      id: json['id'],
      userId: json['userId'],
      name: json['name'],
      type: SessionType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => SessionType.practice,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      status: SessionStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => SessionStatus.created,
      ),
      metadata: Map<String, dynamic>.from(json['metadata']),
      recordings: (json['recordings'] as List<dynamic>?)
          ?.map((r) => VocalRecording.fromJson(r as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

/// Individual vocal recording within a session
class VocalRecording {
  final String id;
  final String sessionId;
  final Float32List audioData;
  final Duration duration;
  final DateTime createdAt;
  DateTime updatedAt;
  VocalAnalysisResult? analysis;
  final Map<String, dynamic> metadata;
  
  VocalRecording({
    required this.id,
    required this.sessionId,
    required this.audioData,
    required this.duration,
    required this.createdAt,
    DateTime? updatedAt,
    this.analysis,
    Map<String, dynamic>? metadata,
  }) : updatedAt = updatedAt ?? createdAt,
       metadata = metadata ?? {};
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'audioDataLength': audioData.length,
      'duration': duration.inMilliseconds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'analysis': analysis?.toJson(),
      'metadata': metadata,
    };
  }
  
  factory VocalRecording.fromJson(Map<String, dynamic> json) {
    // Note: Audio data is not persisted in JSON for storage efficiency
    return VocalRecording(
      id: json['id'],
      sessionId: json['sessionId'],
      audioData: Float32List(json['audioDataLength'] ?? 0),
      duration: Duration(milliseconds: json['duration']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      analysis: json['analysis'] != null 
          ? VocalAnalysisResult.fromJson(json['analysis'])
          : null,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
}

/// Vocal analysis result model
class VocalAnalysisResult {
  final double overallScore;
  final double pitchAccuracy;
  final double rhythmAccuracy;
  final double toneQuality;
  final Map<String, double> detailedMetrics;
  final List<String> suggestions;
  final DateTime analyzedAt;
  
  VocalAnalysisResult({
    required this.overallScore,
    required this.pitchAccuracy,
    required this.rhythmAccuracy,
    required this.toneQuality,
    required this.detailedMetrics,
    required this.suggestions,
    DateTime? analyzedAt,
  }) : analyzedAt = analyzedAt ?? DateTime.now();
  
  Map<String, dynamic> toJson() {
    return {
      'overallScore': overallScore,
      'pitchAccuracy': pitchAccuracy,
      'rhythmAccuracy': rhythmAccuracy,
      'toneQuality': toneQuality,
      'detailedMetrics': detailedMetrics,
      'suggestions': suggestions,
      'analyzedAt': analyzedAt.toIso8601String(),
    };
  }
  
  factory VocalAnalysisResult.fromJson(Map<String, dynamic> json) {
    return VocalAnalysisResult(
      overallScore: json['overallScore']?.toDouble() ?? 0.0,
      pitchAccuracy: json['pitchAccuracy']?.toDouble() ?? 0.0,
      rhythmAccuracy: json['rhythmAccuracy']?.toDouble() ?? 0.0,
      toneQuality: json['toneQuality']?.toDouble() ?? 0.0,
      detailedMetrics: Map<String, double>.from(json['detailedMetrics'] ?? {}),
      suggestions: List<String>.from(json['suggestions'] ?? []),
      analyzedAt: DateTime.parse(json['analyzedAt']),
    );
  }
}

/// Session statistics model
class SessionStatistics {
  final int totalSessions;
  final int thisWeekSessions;
  final int thisMonthSessions;
  final Duration totalDuration;
  final int totalRecordings;
  final double averageAccuracy;
  final DateTime? lastSessionDate;
  
  SessionStatistics({
    required this.totalSessions,
    required this.thisWeekSessions,
    required this.thisMonthSessions,
    required this.totalDuration,
    required this.totalRecordings,
    required this.averageAccuracy,
    this.lastSessionDate,
  });
}

/// Session types
enum SessionType {
  practice,
  lesson,
  performance,
  evaluation,
  warmup,
}

/// Session status
enum SessionStatus {
  created,
  recording,
  completed,
  archived,
}

import 'dart:math' as math;