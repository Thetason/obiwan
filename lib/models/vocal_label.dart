/// Vocal Label Model for Admin Mode YouTube Data Labeling
/// Contains all necessary fields for labeling vocal samples from YouTube
class VocalLabel {
  final String id;
  final String youtubeUrl;
  final String artistName;
  final String songTitle;
  final double startTime;
  final double endTime;
  
  // 5 Essential Labels for AI Training
  final int overallQuality; // 1-5 stars
  final String technique; // chest, mix, head, belt
  final String tone; // dark, warm, neutral, bright
  final double pitchAccuracy; // 0-100%
  final double breathSupport; // 0-100%
  
  // Optional notes
  final String? notes;
  
  // Metadata
  final DateTime createdAt;
  final String createdBy;

  VocalLabel({
    required this.id,
    required this.youtubeUrl,
    required this.artistName,
    required this.songTitle,
    required this.startTime,
    required this.endTime,
    required this.overallQuality,
    required this.technique,
    required this.tone,
    required this.pitchAccuracy,
    required this.breathSupport,
    this.notes,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'youtubeUrl': youtubeUrl,
      'artistName': artistName,
      'songTitle': songTitle,
      'startTime': startTime,
      'endTime': endTime,
      'overallQuality': overallQuality,
      'technique': technique,
      'tone': tone,
      'pitchAccuracy': pitchAccuracy,
      'breathSupport': breathSupport,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  factory VocalLabel.fromJson(Map<String, dynamic> json) {
    return VocalLabel(
      id: json['id'],
      youtubeUrl: json['youtubeUrl'],
      artistName: json['artistName'],
      songTitle: json['songTitle'],
      startTime: json['startTime'].toDouble(),
      endTime: json['endTime'].toDouble(),
      overallQuality: json['overallQuality'],
      technique: json['technique'],
      tone: json['tone'],
      pitchAccuracy: json['pitchAccuracy'].toDouble(),
      breathSupport: json['breathSupport'].toDouble(),
      notes: json['notes'],
      createdAt: DateTime.parse(json['createdAt']),
      createdBy: json['createdBy'],
    );
  }
}

/// Vocal Technique Options
class VocalTechnique {
  static const String chest = 'chest';
  static const String mix = 'mix';
  static const String head = 'head';
  static const String belt = 'belt';
  
  static const List<String> all = [chest, mix, head, belt];
}

/// Vocal Tone Options
class VocalTone {
  static const String dark = 'dark';
  static const String warm = 'warm';
  static const String neutral = 'neutral';
  static const String bright = 'bright';
  
  static const List<String> all = [dark, warm, neutral, bright];
}