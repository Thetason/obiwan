import 'package:flutter/material.dart';
import 'dart:math' as math;

class ParticleSystem extends StatefulWidget {
  final bool isActive;
  final double intensity;
  final Color primaryColor;
  final Color secondaryColor;

  const ParticleSystem({
    super.key,
    required this.isActive,
    required this.intensity,
    this.primaryColor = const Color(0xFF6366F1),
    this.secondaryColor = const Color(0xFF8B5CF6),
  });

  @override
  State<ParticleSystem> createState() => _ParticleSystemState();
}

class _ParticleSystemState extends State<ParticleSystem>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  final List<Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 16), // 60 FPS
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    
    _initializeParticles();
    
    if (widget.isActive) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(ParticleSystem oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive && !oldWidget.isActive) {
      _animationController.repeat();
    } else if (!widget.isActive && oldWidget.isActive) {
      _animationController.stop();
    }
    
    if (widget.intensity != oldWidget.intensity) {
      _updateParticleIntensity();
    }
  }

  void _initializeParticles() {
    _particles.clear();
    for (int i = 0; i < 50; i++) {
      _particles.add(_createParticle());
    }
  }

  Particle _createParticle() {
    return Particle(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      vx: (_random.nextDouble() - 0.5) * 0.01,
      vy: (_random.nextDouble() - 0.5) * 0.01,
      size: _random.nextDouble() * 4 + 1,
      life: _random.nextDouble(),
      maxLife: _random.nextDouble() * 2 + 1,
      color: _random.nextBool() ? widget.primaryColor : widget.secondaryColor,
    );
  }

  void _updateParticleIntensity() {
    for (var particle in _particles) {
      particle.intensity = widget.intensity;
    }
  }

  void _updateParticles() {
    for (var particle in _particles) {
      particle.update();
      
      // 파티클 재생성
      if (particle.life <= 0 || 
          particle.x < 0 || particle.x > 1 ||
          particle.y < 0 || particle.y > 1) {
        final newParticle = _createParticle();
        particle.x = newParticle.x;
        particle.y = newParticle.y;
        particle.vx = newParticle.vx;
        particle.vy = newParticle.vy;
        particle.life = newParticle.life;
        particle.maxLife = newParticle.maxLife;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        if (widget.isActive) {
          _updateParticles();
        }
        
        return CustomPaint(
          size: Size.infinite,
          painter: ParticlePainter(
            particles: _particles,
            isActive: widget.isActive,
            intensity: widget.intensity,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

class Particle {
  double x, y, vx, vy, size, life, maxLife;
  double intensity = 0.0;
  Color color;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.life,
    required this.maxLife,
    required this.color,
  });

  void update() {
    x += vx * (1 + intensity);
    y += vy * (1 + intensity);
    life -= 0.016; // 60 FPS
    
    // 강도에 따른 속도 조정
    vx *= (1 + intensity * 0.1);
    vy *= (1 + intensity * 0.1);
  }

  double get opacity {
    return (life / maxLife).clamp(0.0, 1.0) * (0.3 + intensity * 0.7);
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final bool isActive;
  final double intensity;

  ParticlePainter({
    required this.particles,
    required this.isActive,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final paint = Paint()..style = PaintingStyle.fill;

    for (var particle in particles) {
      paint.color = particle.color.withOpacity(particle.opacity);
      
      final particleSize = particle.size * (1 + intensity);
      canvas.drawCircle(
        Offset(
          particle.x * size.width,
          particle.y * size.height,
        ),
        particleSize,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class FloatingNotes extends StatefulWidget {
  final bool isActive;
  final double intensity;
  final Color primaryColor;

  const FloatingNotes({
    super.key,
    required this.isActive,
    required this.intensity,
    this.primaryColor = const Color(0xFF6366F1),
  });

  @override
  State<FloatingNotes> createState() => _FloatingNotesState();
}

class _FloatingNotesState extends State<FloatingNotes>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<FloatingNote> _notes = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _initializeNotes();
    
    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(FloatingNotes oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
    }
  }

  void _initializeNotes() {
    final noteIcons = [
      Icons.music_note,
      Icons.queue_music,
      Icons.audiotrack,
      Icons.graphic_eq,
    ];

    for (int i = 0; i < 8; i++) {
      _notes.add(FloatingNote(
        icon: noteIcons[_random.nextInt(noteIcons.length)],
        startX: _random.nextDouble(),
        startY: _random.nextDouble(),
        speed: _random.nextDouble() * 0.5 + 0.2,
        rotation: _random.nextDouble() * 2 * math.pi,
        size: _random.nextDouble() * 20 + 15,
        delay: _random.nextDouble() * 2,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: FloatingNotesPainter(
            notes: _notes,
            animation: _controller.value,
            isActive: widget.isActive,
            intensity: widget.intensity,
            color: widget.primaryColor,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class FloatingNote {
  final IconData icon;
  final double startX, startY, speed, rotation, size, delay;

  FloatingNote({
    required this.icon,
    required this.startX,
    required this.startY,
    required this.speed,
    required this.rotation,
    required this.size,
    required this.delay,
  });
}

class FloatingNotesPainter extends CustomPainter {
  final List<FloatingNote> notes;
  final double animation;
  final bool isActive;
  final double intensity;
  final Color color;

  FloatingNotesPainter({
    required this.notes,
    required this.animation,
    required this.isActive,
    required this.intensity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    for (var note in notes) {
      final progress = ((animation + note.delay) % 1.0);
      final opacity = (1 - progress) * intensity * 0.6;
      
      if (opacity <= 0) continue;

      final x = note.startX * size.width;
      final y = (note.startY - progress * note.speed) * size.height;
      
      if (y < -50) continue;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(note.rotation + animation * 2 * math.pi);

      final textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(note.icon.codePoint),
          style: TextStyle(
            fontFamily: note.icon.fontFamily,
            fontSize: note.size * (1 + intensity * 0.5),
            color: color.withOpacity(opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PulseEffect extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final double intensity;
  final Color color;

  const PulseEffect({
    super.key,
    required this.child,
    required this.isActive,
    required this.intensity,
    this.color = const Color(0xFF6366F1),
  });

  @override
  State<PulseEffect> createState() => _PulseEffectState();
}

class _PulseEffectState extends State<PulseEffect>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: Duration(milliseconds: (1000 - widget.intensity * 500).round()),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.0 + widget.intensity * 0.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulseEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: widget.isActive ? [
              BoxShadow(
                color: widget.color.withOpacity(_opacityAnimation.value * widget.intensity),
                blurRadius: 30 * widget.intensity,
                spreadRadius: 10 * widget.intensity,
              ),
            ] : null,
          ),
          child: Transform.scale(
            scale: widget.isActive ? _scaleAnimation.value : 1.0,
            child: widget.child,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}