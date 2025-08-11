import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfessionalPianoKeyboard extends StatefulWidget {
  final String activeNote;
  final Function(String) onKeyPressed;
  
  const ProfessionalPianoKeyboard({
    super.key,
    required this.activeNote,
    required this.onKeyPressed,
  });
  
  @override
  State<ProfessionalPianoKeyboard> createState() => _ProfessionalPianoKeyboardState();
}

class _ProfessionalPianoKeyboardState extends State<ProfessionalPianoKeyboard>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _glowController;
  final ScrollController _scrollController = ScrollController();
  
  // C3 to C6 (3 octaves for vocal range)
  final List<String> whiteKeys = [
    'C3', 'D3', 'E3', 'F3', 'G3', 'A3', 'B3',
    'C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4',
    'C5', 'D5', 'E5', 'F5', 'G5', 'A5', 'B5',
    'C6',
  ];
  
  final List<String> blackKeys = [
    'C#3', 'D#3', 'F#3', 'G#3', 'A#3',
    'C#4', 'D#4', 'F#4', 'G#4', 'A#4',
    'C#5', 'D#5', 'F#5', 'G#5', 'A#5',
  ];
  
  // Black key positions (which white key they appear after)
  final Map<String, int> blackKeyPositions = {
    'C#3': 0, 'D#3': 1, 'F#3': 3, 'G#3': 4, 'A#3': 5,
    'C#4': 7, 'D#4': 8, 'F#4': 10, 'G#4': 11, 'A#4': 12,
    'C#5': 14, 'D#5': 15, 'F#5': 17, 'G#5': 18, 'A#5': 19,
  };
  
  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Auto-scroll to active key
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToActiveKey();
    });
  }
  
  void _scrollToActiveKey() {
    if (widget.activeNote.isEmpty) return;
    
    final index = whiteKeys.indexOf(widget.activeNote);
    if (index != -1) {
      final position = index * 50.0;
      _scrollController.animateTo(
        position - 150, // Center the key
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }
  
  @override
  void didUpdateWidget(ProfessionalPianoKeyboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeNote != oldWidget.activeNote) {
      _glowController.forward().then((_) {
        _glowController.reverse();
      });
      _scrollToActiveKey();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            // Piano keys container
            SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Container(
                height: 120,
                child: Stack(
                  children: [
                    // White keys
                    Row(
                      children: whiteKeys.map((note) {
                        return _buildWhiteKey(note);
                      }).toList(),
                    ),
                    
                    // Black keys
                    ...blackKeys.map((note) {
                      final position = blackKeyPositions[note]!;
                      return Positioned(
                        left: (position * 50) + 35,
                        top: 0,
                        child: _buildBlackKey(note),
                      );
                    }),
                  ],
                ),
              ),
            ),
            
            // Gradient overlays for visual depth
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 30,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 30,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWhiteKey(String note) {
    final isActive = widget.activeNote == note;
    final noteColor = _getNoteColor(note);
    
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        widget.onKeyPressed(note);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 50,
        height: 120,
        margin: const EdgeInsets.only(right: 1),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isActive
              ? [
                  noteColor.withOpacity(0.9),
                  noteColor.withOpacity(0.7),
                ]
              : [
                  Colors.white.withOpacity(0.95),
                  Colors.grey.shade200,
                ],
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(5),
            bottomRight: Radius.circular(5),
          ),
          boxShadow: [
            BoxShadow(
              color: isActive
                ? noteColor.withOpacity(0.5)
                : Colors.black.withOpacity(0.3),
              blurRadius: isActive ? 10 : 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Key press effect
            if (isActive)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          colors: [
                            noteColor.withOpacity(_glowController.value * 0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            
            // Note label
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Text(
                note,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isActive
                    ? Colors.white
                    : Colors.black.withOpacity(0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBlackKey(String note) {
    final isActive = widget.activeNote == note;
    final noteColor = _getNoteColor(note);
    
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        widget.onKeyPressed(note);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 30,
        height: 70,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isActive
              ? [
                  noteColor.withOpacity(0.9),
                  noteColor.withOpacity(0.7),
                ]
              : [
                  Colors.grey.shade900,
                  Colors.black,
                ],
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(3),
            bottomRight: Radius.circular(3),
          ),
          boxShadow: [
            BoxShadow(
              color: isActive
                ? noteColor.withOpacity(0.5)
                : Colors.black.withOpacity(0.5),
              blurRadius: isActive ? 8 : 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isActive
          ? Center(
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white,
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            )
          : null,
      ),
    );
  }
  
  Color _getNoteColor(String note) {
    // Color coding by note for visual feedback
    if (note.startsWith('C')) return Colors.red;
    if (note.startsWith('D')) return Colors.orange;
    if (note.startsWith('E')) return Colors.yellow;
    if (note.startsWith('F')) return Colors.green;
    if (note.startsWith('G')) return Colors.blue;
    if (note.startsWith('A')) return Colors.indigo;
    if (note.startsWith('B')) return Colors.purple;
    return Colors.grey;
  }
  
  @override
  void dispose() {
    _glowController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}