import 'dart:math' as math;
import 'package:flutter/material.dart';

class CircularAudioVisualizer extends StatefulWidget {
  final double amplitude;
  final bool isRecording;
  final bool isPaused;
  final double size;
  final bool isDark;

  const CircularAudioVisualizer({
    super.key,
    required this.amplitude,
    required this.isRecording,
    required this.isPaused,
    this.size = 200,
    this.isDark = false,
  });

  @override
  State<CircularAudioVisualizer> createState() => _CircularAudioVisualizerState();
}

class _CircularAudioVisualizerState extends State<CircularAudioVisualizer>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for breathing effect
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Wave animation - use reverse to eliminate glitch at loop end
    // This creates a smooth ping-pong effect that never jumps
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Use smooth curve for reverse animation - no glitch when reversing
    _waveAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _waveController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedAmplitude = (widget.amplitude * 100).clamp(0.0, 100.0) / 100.0;
    
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _waveAnimation]),
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _AbstractWavePainter(
            amplitude: normalizedAmplitude,
            isRecording: widget.isRecording,
            isPaused: widget.isPaused,
            pulseValue: _pulseAnimation.value,
            waveValue: _waveAnimation.value,
            isDark: widget.isDark,
          ),
        );
      },
    );
  }
}

class _AbstractWavePainter extends CustomPainter {
  final double amplitude;
  final bool isRecording;
  final bool isPaused;
  final double pulseValue;
  final double waveValue;
  final bool isDark;

  _AbstractWavePainter({
    required this.amplitude,
    required this.isRecording,
    required this.isPaused,
    required this.pulseValue,
    required this.waveValue,
    this.isDark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    if (!isRecording) {
      // Static state - more visible abstract shapes
      _drawAbstractShapes(canvas, center, maxRadius, 0.5, false);
      return;
    }

    if (isPaused) {
      // Paused state - static abstract shapes with orange tint
      _drawAbstractShapes(canvas, center, maxRadius, 0.5, true);
      return;
    }

    // Active recording - dynamic abstract shapes based on amplitude
    final intensity = math.max(amplitude, 0.1);
    _drawAbstractShapes(canvas, center, maxRadius, intensity, false);
  }

  void _drawAbstractShapes(Canvas canvas, Offset center, double maxRadius, double intensity, bool isPaused) {
    // Draw multiple overlapping organic shapes for a more beautiful effect
    
    final numShapes = 12; // More shapes for richer visual
    final baseOpacity = isPaused ? 0.6 : (isDark ? 0.45 : 0.75);
    
    // Use waveValue directly - with reverse animation, it smoothly goes 0->2π->0
    // This eliminates any glitch at the loop boundary
    final rotationOffset = waveValue;
    
    for (int i = 0; i < numShapes; i++) {
      // Smooth rotation - rotationOffset smoothly oscillates between 0 and 2π
      final baseAngle = (i * 2 * math.pi / numShapes);
      final angle = baseAngle + rotationOffset * 0.5;
      
      // More dynamic distance variation
      final distanceVariation = 0.5 + (intensity * 0.4) * pulseValue;
      final distance = maxRadius * (0.35 + (intensity * 0.35) * distanceVariation);
      
      // Calculate position for this oval with smoother movement
      final x = center.dx + math.cos(angle) * distance * 0.4;
      final y = center.dy + math.sin(angle) * distance * 0.4;
      
      // More organic size variation
      final sizeVariation = 1 + 0.3 * math.sin(rotationOffset * 2 + i);
      final ovalWidth = maxRadius * (0.35 + (intensity * 0.45) * sizeVariation);
      final ovalHeight = maxRadius * (0.25 + (intensity * 0.35) * sizeVariation);
      
      // Opacity decreases for outer shapes with smoother gradient
      final opacityFactor = 1.0 - (i / numShapes) * 0.4;
      final opacity = baseOpacity * opacityFactor * (isPaused ? 0.85 : 1.0);
      
      // Create oval shape
      final rect = Rect.fromCenter(
        center: Offset(x, y),
        width: ovalWidth,
        height: ovalHeight,
      );
      
      // Rotate the oval
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + rotationOffset * 0.2);
      canvas.translate(-x, -y);
      
      // Use gradient-like shades for more beautiful effect
      Color baseColor;
      if (isDark) {
        // White with slight variation
        final brightness = 1.0 - (i / numShapes) * 0.2;
        baseColor = Color.fromRGBO(
          (255 * brightness).round(),
          (255 * brightness).round(),
          (255 * brightness).round(),
          1.0,
        );
      } else {
        // Rich gray gradient from dark to light
        final grayValue = (200 - (i * 12)).clamp(110, 200);
        baseColor = Color.fromRGBO(grayValue, grayValue, grayValue, 1.0);
      }
      
      final paint = Paint()
        ..color = isPaused 
            ? Colors.orange.withValues(alpha: opacity)
            : baseColor.withValues(alpha: opacity)
        ..style = PaintingStyle.fill
        ..blendMode = isDark ? BlendMode.plus : BlendMode.srcOver;
      
      canvas.drawOval(rect, paint);
      canvas.restore();
    }
    
    // Draw additional inner shapes for more depth and beauty
    for (int i = 0; i < 6; i++) {
      final baseAngle = (i * math.pi / 3);
      final angle = baseAngle + rotationOffset * 0.3;
      final distance = maxRadius * (0.15 + intensity * 0.25) * pulseValue;
      
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;
      
      final sizeVariation = 1 + 0.2 * math.sin(rotationOffset * 3 + i);
      final size = maxRadius * (0.12 + intensity * 0.12) * pulseValue * sizeVariation;
      
      // Use shades of gray for light mode, white for dark mode
      final baseColor = isDark 
          ? Colors.white.withValues(alpha: 0.8 - (i / 6) * 0.3)
          : Color.fromRGBO((150 - (i * 18)).clamp(110, 150), (150 - (i * 18)).clamp(110, 150), (150 - (i * 18)).clamp(110, 150), 1.0);
      final paint = Paint()
        ..color = isPaused
            ? Colors.orange.withValues(alpha: 0.35 * intensity)
            : baseColor.withValues(alpha: (isDark ? 0.3 : 0.55) * intensity)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(x, y), size, paint);
    }
    
    // Draw central core with gradient effect
    final coreSize = maxRadius * 0.18 * (0.85 + intensity * 0.45) * pulseValue;
    
    // Create a more beautiful core with gradient-like effect
    final coreSteps = 3;
    for (int step = 0; step < coreSteps; step++) {
      final stepSize = coreSize * (1.0 - step * 0.3);
      final stepOpacity = (1.0 - step * 0.25);
      
      final coreColor = isDark 
          ? Colors.white.withValues(alpha: stepOpacity * 0.9)
          : Color.fromRGBO(
              (140 - step * 20).clamp(100, 140),
              (140 - step * 20).clamp(100, 140),
              (140 - step * 20).clamp(100, 140),
              1.0,
            );
      
      final corePaint = Paint()
        ..color = isPaused
            ? Colors.orange.withValues(alpha: 0.4 * stepOpacity)
            : coreColor.withValues(alpha: (isDark ? 0.5 : 0.75) * intensity * stepOpacity)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(center, stepSize, corePaint);
    }
  }

  @override
  bool shouldRepaint(_AbstractWavePainter oldDelegate) {
    return oldDelegate.amplitude != amplitude ||
        oldDelegate.isRecording != isRecording ||
        oldDelegate.isPaused != isPaused ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.waveValue != waveValue ||
        oldDelegate.isDark != isDark;
  }
}
