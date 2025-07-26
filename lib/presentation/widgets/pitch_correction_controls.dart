import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../features/audio_analysis/pitch_correction_engine.dart';

class PitchCorrectionControls extends StatefulWidget {
  final PitchCorrectionConfig config;
  final ValueChanged<PitchCorrectionConfig> onConfigChanged;
  final VoidCallback? onToggleCorrection;
  final bool isActive;
  
  const PitchCorrectionControls({
    Key? key,
    required this.config,
    required this.onConfigChanged,
    this.onToggleCorrection,
    this.isActive = false,
  }) : super(key: key);
  
  @override
  State<PitchCorrectionControls> createState() => _PitchCorrectionControlsState();
}

class _PitchCorrectionControlsState extends State<PitchCorrectionControls> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    if (widget.isActive) {
      _animationController.forward();
    }
  }
  
  @override
  void didUpdateWidget(PitchCorrectionControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (widget.isActive) ...[
              const SizedBox(height: 20),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    _buildCorrectionStrengthSlider(),
                    const SizedBox(height: 16),
                    _buildScaleSelector(),
                    const SizedBox(height: 16),
                    _buildAdvancedSettings(),
                    const SizedBox(height: 16),
                    _buildPresets(),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.tune,
              color: widget.isActive ? Theme.of(context).primaryColor : Colors.grey,
              size: 28,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '음정 보정 (Auto-Tune)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.isActive ? '활성화됨' : '비활성화됨',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: widget.isActive ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        CupertinoSwitch(
          value: widget.isActive,
          onChanged: (_) => widget.onToggleCorrection?.call(),
          activeColor: Theme.of(context).primaryColor,
        ),
      ],
    );
  }
  
  Widget _buildCorrectionStrengthSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '보정 강도',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              '${(widget.config.correctionStrength * 100).round()}%',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: widget.config.correctionStrength,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            onChanged: (value) {
              widget.onConfigChanged(
                widget.config.copyWith(correctionStrength: value),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('자연스러움', style: Theme.of(context).textTheme.bodySmall),
            Text('로봇 같음', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
  
  Widget _buildScaleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '스케일 선택',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ScaleType.values.map((scale) {
            final isSelected = widget.config.scaleType == scale;
            return ChoiceChip(
              label: Text(_getScaleName(scale)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  widget.onConfigChanged(
                    widget.config.copyWith(scaleType: scale),
                  );
                }
              },
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? Theme.of(context).primaryColor : null,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  Widget _buildAdvancedSettings() {
    return ExpansionTile(
      title: const Text('고급 설정'),
      tilePadding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 8),
        _buildSliderSetting(
          label: 'Attack Time',
          value: widget.config.attackTime * 1000, // Convert to ms
          min: 1,
          max: 50,
          unit: 'ms',
          onChanged: (value) {
            widget.onConfigChanged(
              widget.config.copyWith(attackTime: value / 1000),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildSliderSetting(
          label: 'Release Time',
          value: widget.config.releaseTime * 1000, // Convert to ms
          min: 10,
          max: 200,
          unit: 'ms',
          onChanged: (value) {
            widget.onConfigChanged(
              widget.config.copyWith(releaseTime: value / 1000),
            );
          },
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('포먼트 보존'),
          subtitle: const Text('자연스러운 음색 유지'),
          value: widget.config.preserveFormants,
          onChanged: (value) {
            widget.onConfigChanged(
              widget.config.copyWith(preserveFormants: value),
            );
          },
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        _buildSliderSetting(
          label: '기준 피치 (A4)',
          value: widget.config.referencePitch,
          min: 430,
          max: 450,
          unit: 'Hz',
          divisions: 20,
          onChanged: (value) {
            widget.onConfigChanged(
              widget.config.copyWith(referencePitch: value),
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildSliderSetting({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required ValueChanged<double> onChanged,
    int? divisions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(
              '${value.toStringAsFixed(value < 10 ? 1 : 0)} $unit',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions ?? (max - min).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }
  
  Widget _buildPresets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '프리셋',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPresetButton(
                '자연스러움',
                Icons.nature,
                () => _applyNaturalPreset(),
              ),
              const SizedBox(width: 8),
              _buildPresetButton(
                'T-Pain',
                Icons.android,
                () => _applyTPainPreset(),
              ),
              const SizedBox(width: 8),
              _buildPresetButton(
                '미세 조정',
                Icons.tune,
                () => _applySubtlePreset(),
              ),
              const SizedBox(width: 8),
              _buildPresetButton(
                '팝',
                Icons.music_note,
                () => _applyPopPreset(),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPresetButton(String label, IconData icon, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
  
  String _getScaleName(ScaleType scale) {
    switch (scale) {
      case ScaleType.major:
        return '메이저';
      case ScaleType.minor:
        return '마이너';
      case ScaleType.pentatonic:
        return '펜타토닉';
      case ScaleType.blues:
        return '블루스';
      case ScaleType.chromatic:
        return '반음계';
    }
  }
  
  void _applyNaturalPreset() {
    widget.onConfigChanged(
      const PitchCorrectionConfig(
        correctionStrength: 0.3,
        scaleType: ScaleType.chromatic,
        attackTime: 0.020,
        releaseTime: 0.100,
        preserveFormants: true,
      ),
    );
  }
  
  void _applyTPainPreset() {
    widget.onConfigChanged(
      const PitchCorrectionConfig(
        correctionStrength: 1.0,
        scaleType: ScaleType.major,
        attackTime: 0.001,
        releaseTime: 0.001,
        preserveFormants: false,
      ),
    );
  }
  
  void _applySubtlePreset() {
    widget.onConfigChanged(
      const PitchCorrectionConfig(
        correctionStrength: 0.15,
        scaleType: ScaleType.chromatic,
        attackTime: 0.050,
        releaseTime: 0.150,
        preserveFormants: true,
      ),
    );
  }
  
  void _applyPopPreset() {
    widget.onConfigChanged(
      const PitchCorrectionConfig(
        correctionStrength: 0.7,
        scaleType: ScaleType.major,
        attackTime: 0.005,
        releaseTime: 0.030,
        preserveFormants: true,
      ),
    );
  }
}