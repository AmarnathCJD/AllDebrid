import 'package:flutter/material.dart';
import 'dart:math';

/// Creative animated AI icon - Morphing Brain/Lightning concept
class AnimatedAIIcon extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  final double size;

  const AnimatedAIIcon({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.size = 24,
  });

  @override
  State<AnimatedAIIcon> createState() => _AnimatedAIIconState();
}

class _AnimatedAIIconState extends State<AnimatedAIIcon>
    with TickerProviderStateMixin {
  late AnimationController _morphController;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _morphController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.isLoading ? null : widget.onPressed,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.purple.shade400.withValues(alpha: 0.3),
        highlightColor: Colors.purple.shade400.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: widget.size + 16,
            height: widget.size + 16,
            child: AnimatedBuilder(
              animation: Listenable.merge([_morphController, _glowController]),
              builder: (context, child) {
                return CustomPaint(
                  painter: _CreativeAIIconPainter(
                    morphProgress: _morphController.value,
                    glowProgress: _glowController.value,
                    isLoading: widget.isLoading,
                  ),
                  size: Size(widget.size + 16, widget.size + 16),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for creative AI icon - Morphing between brain and lightning
class _CreativeAIIconPainter extends CustomPainter {
  final double morphProgress;
  final double glowProgress;
  final bool isLoading;

  _CreativeAIIconPainter({
    required this.morphProgress,
    required this.glowProgress,
    required this.isLoading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.25;

    // Animate between brain color and lightning color
    final brainColor = Color.lerp(
      Colors.purple.shade400,
      Colors.amber.shade400,
      (sin(morphProgress * 2 * pi) + 1) / 2,
    )!;

    // Draw outer glow
    final glowIntensity = (sin(glowProgress * 2 * pi) + 1) / 2;
    final outerGlowPaint = Paint()
      ..color = brainColor.withValues(alpha: 0.2 * glowIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(center, baseRadius * 1.4, outerGlowPaint);

    // Draw brain lobes (3 bumps)
    final lobe1Angle = -pi / 2;
    final lobe2Angle = -pi / 2 + (2 * pi / 3);
    final lobe3Angle = -pi / 2 + (4 * pi / 3);

    final lobeRadius = baseRadius * 0.55;
    final lobeCenterRadius = baseRadius * 0.6;

    // Morph between brain bumps and lightning points
    final morphFactor = (sin(morphProgress * 2 * pi) + 1) / 2;
    final bumpiestFactor =
        morphFactor < 0.5 ? morphFactor * 2 : 2 - morphFactor * 2;

    for (int i = 0; i < 3; i++) {
      final angle = [lobe1Angle, lobe2Angle, lobe3Angle][i];
      final x = center.dx + lobeCenterRadius * cos(angle);
      final y = center.dy + lobeCenterRadius * sin(angle);
      final lobePos = Offset(x, y);

      // Lobe glow
      final lobeGlowPaint = Paint()
        ..color = brainColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(
        lobePos,
        lobeRadius * (0.7 + bumpiestFactor * 0.3),
        lobeGlowPaint,
      );

      // Lobe fill
      final lobeFillPaint = Paint()
        ..color = brainColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        lobePos,
        lobeRadius * (0.6 + bumpiestFactor * 0.25),
        lobeFillPaint,
      );

      // Draw connection lines to center
      final connectionPaint = Paint()
        ..color = brainColor.withValues(alpha: 0.4)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;

      final connectionPoint = Offset(
        center.dx + (baseRadius * 0.3) * cos(angle),
        center.dy + (baseRadius * 0.3) * sin(angle),
      );

      canvas.drawLine(connectionPoint, lobePos, connectionPaint);
    }

    // Draw central core
    final corePaint = Paint()
      ..color = brainColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, baseRadius * 0.35, corePaint);

    // Draw inner glow in core
    final coreGlowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3 * glowIntensity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, baseRadius * 0.15, coreGlowPaint);

    // Optional: draw crackling effect during loading
    if (isLoading) {
      _drawLoadingCrackles(canvas, center, baseRadius, brainColor);
    }
  }

  void _drawLoadingCrackles(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    final crackPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Create 3 random crackling lines around the icon
    final random = Random(42); // Consistent randomness

    for (int i = 0; i < 3; i++) {
      final angle = (glowProgress * 2 * pi) + (i * 2 * pi / 3);
      final startX = center.dx + radius * 1.3 * cos(angle);
      final startY = center.dy + radius * 1.3 * sin(angle);

      final endX = startX + (radius * 0.3) * cos(angle + random.nextDouble());
      final endY = startY + (radius * 0.3) * sin(angle + random.nextDouble());

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        crackPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CreativeAIIconPainter oldDelegate) {
    return oldDelegate.morphProgress != morphProgress ||
        oldDelegate.glowProgress != glowProgress ||
        oldDelegate.isLoading != isLoading;
  }
}

/// AI Button with enhanced styling
class AIRecommendationButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const AIRecommendationButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade600.withValues(alpha: 0.1),
            Colors.amber.shade600.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.purple.shade400.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.purple.shade400.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedAIIcon(
                  onPressed: onPressed,
                  isLoading: isLoading,
                  size: 20,
                ),
                const SizedBox(width: 8),
                if (!isLoading)
                  const Text(
                    'AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  )
                else
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation(Colors.purple.shade400),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
