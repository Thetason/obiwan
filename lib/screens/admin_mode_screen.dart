import 'package:flutter/material.dart';
import 'dart:async';
import '../models/vocal_label.dart';

/// Admin Mode for YouTube Vocal Sample Labeling
/// Allows manual labeling of vocal performances from YouTube
class AdminModeScreen extends StatefulWidget {
  const AdminModeScreen({Key? key}) : super(key: key);

  @override
  State<AdminModeScreen> createState() => _AdminModeScreenState();
}

class _AdminModeScreenState extends State<AdminModeScreen> {
  final _urlController = TextEditingController();
  final _artistController = TextEditingController();
  final _songController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Time selection
  double _startTime = 0.0;
  double _endTime = 15.0;
  
  // 5 Essential Labels
  int _overallQuality = 3; // 1-5 stars
  String _selectedTechnique = VocalTechnique.mix;
  String _selectedTone = VocalTone.neutral;
  double _pitchAccuracy = 85.0; // 0-100%
  double _breathSupport = 70.0; // 0-100%
  
  // Saved labels (in-memory for now)
  List<VocalLabel> _savedLabels = [];
  
  @override
  void dispose() {
    _urlController.dispose();
    _artistController.dispose();
    _songController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  void _saveLabel() async {
    if (_urlController.text.isEmpty || _artistController.text.isEmpty || _songController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('YouTube URL, 아티스트명, 곡명을 모두 입력해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final label = VocalLabel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      youtubeUrl: _urlController.text,
      artistName: _artistController.text,
      songTitle: _songController.text,
      startTime: _startTime,
      endTime: _endTime,
      overallQuality: _overallQuality,
      technique: _selectedTechnique,
      tone: _selectedTone,
      pitchAccuracy: _pitchAccuracy,
      breathSupport: _breathSupport,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      createdAt: DateTime.now(),
      createdBy: 'admin',
    );
    
    setState(() {
      _savedLabels.add(label);
    });
    
    // TODO: Save to persistent storage (JSON file or database)
    print('✅ Label saved: ${label.toJson()}');
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('라벨 저장 완료! 총 ${_savedLabels.length}개'),
        backgroundColor: Colors.green,
      ),
    );
    
    // Clear notes for next label
    _notesController.clear();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text(
          'Admin Mode - YouTube 라벨링',
          style: TextStyle(color: Color(0xFF2D3748), fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3748)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8.0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_savedLabels.length} labels',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            _buildInfoCard(),
            const SizedBox(height: 16),
            
            // Time Range
            _buildTimeRangeCard(),
            const SizedBox(height: 16),
            
            // 5 Essential Labels
            _buildLabelsCard(),
            const SizedBox(height: 16),
            
            // Save Button
            _buildSaveButton(),
            const SizedBox(height: 24),
            
            // Recent Labels List
            if (_savedLabels.isNotEmpty) _buildRecentLabels(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YouTube 비디오 정보',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: 'YouTube URL',
              hintText: 'https://youtube.com/watch?v=...',
              prefixIcon: const Icon(Icons.link, color: Color(0xFF7C4DFF)),
              filled: true,
              fillColor: const Color(0xFFF8F9FE),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _artistController,
                  decoration: InputDecoration(
                    labelText: '아티스트',
                    prefixIcon: const Icon(Icons.person, color: Color(0xFF7C4DFF)),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FE),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _songController,
                  decoration: InputDecoration(
                    labelText: '곡명',
                    prefixIcon: const Icon(Icons.music_note, color: Color(0xFF7C4DFF)),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FE),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '분석 구간 (초)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _startTime.toString(),
                  decoration: const InputDecoration(
                    labelText: '시작 (초)',
                    filled: true,
                    fillColor: Color(0xFFF8F9FE),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      _startTime = double.tryParse(value) ?? 0.0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  initialValue: _endTime.toString(),
                  decoration: const InputDecoration(
                    labelText: '끝 (초)',
                    filled: true,
                    fillColor: Color(0xFFF8F9FE),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      _endTime = double.tryParse(value) ?? 15.0;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'YouTube에서 해당 구간을 들으며 아래 항목들을 라벨링하세요',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '5개 필수 라벨',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 20),
          
          // Overall Quality
          _buildQualitySection(),
          const SizedBox(height: 24),
          
          // Technique
          _buildTechniqueSection(),
          const SizedBox(height: 24),
          
          // Tone
          _buildToneSection(),
          const SizedBox(height: 24),
          
          // Pitch Accuracy
          _buildSliderSection(
            '음정 정확도',
            _pitchAccuracy,
            (value) => setState(() => _pitchAccuracy = value),
            const Color(0xFF7C4DFF),
          ),
          const SizedBox(height: 20),
          
          // Breath Support
          _buildSliderSection(
            '호흡 지지력',
            _breathSupport,
            (value) => setState(() => _breathSupport = value),
            const Color(0xFF5B8DEE),
          ),
          const SizedBox(height: 20),
          
          // Notes
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: '메모 (선택사항)',
              hintText: '특별히 주목할 점이나 추가 설명...',
              filled: true,
              fillColor: const Color(0xFFF8F9FE),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '전체적인 품질',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _overallQuality = index + 1;
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  index < _overallQuality ? Icons.star : Icons.star_border,
                  color: const Color(0xFFFFB800),
                  size: 32,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTechniqueSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '발성 기법',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: VocalTechnique.all.map((technique) {
            final isSelected = _selectedTechnique == technique;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTechnique = technique;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF7C4DFF) : const Color(0xFFF8F9FE),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF7C4DFF) : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  technique.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF2D3748),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildToneSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '음색',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: VocalTone.all.map((tone) {
            final isSelected = _selectedTone == tone;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTone = tone;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF5B8DEE) : const Color(0xFFF8F9FE),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF5B8DEE) : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  tone.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF2D3748),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSliderSection(String title, double value, Function(double) onChanged, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2D3748),
              ),
            ),
            Text(
              '${value.toInt()}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 20,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _saveLabel,
        icon: const Icon(Icons.save, color: Colors.white),
        label: const Text(
          'AI 학습용 라벨 저장',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C4DFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildRecentLabels() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '최근 라벨링 결과',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 16),
          ..._savedLabels.reversed.take(5).map((label) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${label.artistName} - ${label.songTitle}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${label.startTime}s-${label.endTime}s | ${label.technique} | ${label.tone}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ...List.generate(label.overallQuality, (index) {
                        return const Icon(Icons.star, size: 16, color: Color(0xFFFFB800));
                      }),
                      const SizedBox(width: 8),
                      Text(
                        '음정: ${label.pitchAccuracy.toInt()}% | 호흡: ${label.breathSupport.toInt()}%',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}