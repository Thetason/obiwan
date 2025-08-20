import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/vocal_label.dart';

/// 라벨 검토 카드 위젯
/// AI가 생성한 초벌 라벨을 사용자가 검토/수정하는 UI
class LabelReviewCard extends StatefulWidget {
  final VocalLabel label;
  final Function(VocalLabel) onApprove;
  final Function(VocalLabel) onReject;
  final Function(VocalLabel) onModify;
  
  const LabelReviewCard({
    Key? key,
    required this.label,
    required this.onApprove,
    required this.onReject,
    required this.onModify,
  }) : super(key: key);
  
  @override
  State<LabelReviewCard> createState() => _LabelReviewCardState();
}

class _LabelReviewCardState extends State<LabelReviewCard> {
  bool _isModifying = false;
  late TextEditingController _artistController;
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  double _qualityRating = 0;
  double _techniqueScore = 0;
  double _emotionScore = 0;
  
  @override
  void initState() {
    super.initState();
    _artistController = TextEditingController(text: widget.label.artist);
    _titleController = TextEditingController(text: widget.label.title);
    _notesController = TextEditingController(text: widget.label.notes ?? '');
    _qualityRating = widget.label.quality?.toDouble() ?? 3.0;
    _techniqueScore = widget.label.technique ?? 0.5;
    _emotionScore = widget.label.emotion ?? 0.5;
  }
  
  @override
  void dispose() {
    _artistController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),
          
          // Content
          Expanded(
            child: _isModifying ? _buildEditForm() : _buildReviewContent(),
          ),
          
          // Action Buttons
          _buildActionButtons(),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C4DFF),
            const Color(0xFF448AFF),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(
            _getConfidenceIcon(),
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.label.artist} - ${widget.label.title}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'AI 신뢰도: ${(widget.label.confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _buildConfidenceBadge(),
        ],
      ),
    );
  }
  
  Widget _buildReviewContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI 분석 결과
          _buildSection('AI 분석 결과', [
            _buildInfoRow('음정 정확도', '${(widget.label.pitchAccuracy * 100).toStringAsFixed(1)}%'),
            _buildInfoRow('평균 주파수', '${widget.label.avgFrequency?.toStringAsFixed(1)} Hz'),
            _buildInfoRow('음역대', widget.label.vocalRange ?? 'N/A'),
            _buildInfoRow('발성 기법', widget.label.techniqueType ?? 'N/A'),
          ]),
          
          const SizedBox(height: 24),
          
          // 품질 평가
          _buildSection('품질 평가', [
            _buildRatingBar('전체 품질', _qualityRating, 5),
            _buildRatingBar('기술 점수', _techniqueScore, 1),
            _buildRatingBar('감정 표현', _emotionScore, 1),
          ]),
          
          const SizedBox(height: 24),
          
          // 메타데이터
          _buildSection('메타데이터', [
            _buildInfoRow('소스', widget.label.source),
            _buildInfoRow('길이', '${widget.label.duration?.toStringAsFixed(1)}초'),
            _buildInfoRow('생성 시간', _formatDate(widget.label.timestamp)),
          ]),
          
          if (widget.label.notes != null && widget.label.notes!.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSection('노트', [
              Text(
                widget.label.notes!,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
  
  Widget _buildEditForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 기본 정보 수정
          _buildTextField('아티스트', _artistController),
          const SizedBox(height: 16),
          _buildTextField('제목', _titleController),
          const SizedBox(height: 24),
          
          // 품질 평가 수정
          _buildSlider('전체 품질', _qualityRating, 5, (value) {
            setState(() => _qualityRating = value);
          }),
          const SizedBox(height: 16),
          _buildSlider('기술 점수', _techniqueScore, 1, (value) {
            setState(() => _techniqueScore = value);
          }),
          const SizedBox(height: 16),
          _buildSlider('감정 표현', _emotionScore, 1, (value) {
            setState(() => _emotionScore = value);
          }),
          const SizedBox(height: 24),
          
          // 노트 수정
          _buildTextField('검토 노트', _notesController, maxLines: 3),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: _isModifying ? _buildModifyActions() : _buildReviewActions(),
    );
  }
  
  Widget _buildReviewActions() {
    return Row(
      children: [
        // Reject Button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => widget.onReject(widget.label),
            icon: const Icon(Icons.close, size: 20),
            label: const Text('거부'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        
        // Modify Button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _isModifying = true),
            icon: const Icon(Icons.edit, size: 20),
            label: const Text('수정'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[400],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        
        // Approve Button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => widget.onApprove(widget.label),
            icon: const Icon(Icons.check, size: 20),
            label: const Text('승인'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[400],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildModifyActions() {
    return Row(
      children: [
        // Cancel Button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _isModifying = false),
            icon: const Icon(Icons.close, size: 20),
            label: const Text('취소'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[400],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        
        // Save Button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _saveModifications,
            icon: const Icon(Icons.save, size: 20),
            label: const Text('저장 & 승인'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  void _saveModifications() {
    final modifiedLabel = widget.label.copyWith(
      artist: _artistController.text,
      title: _titleController.text,
      notes: _notesController.text,
      quality: _qualityRating.round(),
      technique: _techniqueScore,
      emotion: _emotionScore,
      humanVerified: true,
      verifiedAt: DateTime.now(),
    );
    
    widget.onModify(modifiedLabel);
    setState(() => _isModifying = false);
  }
  
  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2C3E50),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRatingBar(String label, double value, double max) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              Text(
                max > 1 
                  ? '${value.toStringAsFixed(0)}/${max.toStringAsFixed(0)}'
                  : '${(value * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Color(0xFF2C3E50),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: value / max,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              _getScoreColor(value / max),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF7C4DFF)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSlider(String label, double value, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2C3E50),
              ),
            ),
            Text(
              max > 1 
                ? value.toStringAsFixed(1)
                : '${(value * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Color(0xFF7C4DFF),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: max,
          divisions: max > 1 ? max.round() : 100,
          activeColor: const Color(0xFF7C4DFF),
          onChanged: onChanged,
        ),
      ],
    );
  }
  
  Widget _buildConfidenceBadge() {
    final confidence = widget.label.confidence;
    final color = confidence > 0.8 
      ? Colors.green 
      : confidence > 0.6 
        ? Colors.orange 
        : Colors.red;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        confidence > 0.8 ? 'HIGH' : confidence > 0.6 ? 'MED' : 'LOW',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  IconData _getConfidenceIcon() {
    final confidence = widget.label.confidence;
    if (confidence > 0.8) return Icons.verified;
    if (confidence > 0.6) return Icons.help_outline;
    return Icons.warning_amber;
  }
  
  Color _getScoreColor(double score) {
    if (score > 0.8) return Colors.green;
    if (score > 0.6) return Colors.orange;
    if (score > 0.4) return Colors.amber;
    return Colors.red;
  }
  
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}