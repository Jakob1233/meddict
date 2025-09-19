import 'dart:math' as math;

import 'package:flutter/material.dart';

const Color _summerBlue = Color(0xFF26547C);
const Color _summerPink = Color(0xFFEF476F);
const Color _summerYellow = Color(0xFFFFD166);

class RingTripletChart extends StatelessWidget {
  const RingTripletChart({
    super.key,
    required this.mass,
    required this.difficulty,
    required this.pastQ,
    this.size = 72,
  });

  final double mass;
  final double difficulty;
  final double pastQ;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final ringBackground = isDark
        ? theme.colorScheme.onSurface.withOpacity(0.18)
        : theme.colorScheme.outlineVariant.withOpacity(0.25);

    final specs = [
      _RingSpec(progress: _clamp01(mass / 100), color: _summerBlue, strokeWidth: 10),
      _RingSpec(progress: _clamp01(difficulty / 100), color: _summerPink, strokeWidth: 9),
      _RingSpec(progress: _clamp01(pastQ / 100), color: _summerYellow, strokeWidth: 8),
    ];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
      builder: (context, animation, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingTripletPainter(
              specs: specs
                  .map((spec) => spec.copyWith(progress: spec.progress * animation))
                  .toList(),
              backgroundColor: ringBackground,
            ),
          ),
        );
      },
    );
  }

  static double _clamp01(double value) {
    if (value.isNaN) return 0;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }
}

class _RingSpec {
  const _RingSpec({required this.progress, required this.color, required this.strokeWidth});

  final double progress;
  final Color color;
  final double strokeWidth;

  _RingSpec copyWith({double? progress, Color? color, double? strokeWidth}) {
    return _RingSpec(
      progress: progress ?? this.progress,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
    );
  }
}

class _RingTripletPainter extends CustomPainter {
  _RingTripletPainter({required this.specs, required this.backgroundColor});

  final List<_RingSpec> specs;
  final Color backgroundColor;

  static const double _gap = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    double radius = math.min(size.width, size.height) / 2;

    for (final spec in specs) {
      final adjustedRadius = radius - (spec.strokeWidth / 2);
      final rect = Rect.fromCircle(center: center, radius: adjustedRadius);

      final backgroundPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = spec.strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = backgroundColor;

      canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, backgroundPaint);

      final sweep = math.pi * 2 * spec.progress.clamp(0, 1);
      if (sweep > 0) {
        final progressPaint = Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = spec.strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = spec.color;

        canvas.drawArc(rect, -math.pi / 2, sweep, false, progressPaint);
      }

      radius = adjustedRadius - spec.strokeWidth / 2 - _gap;
      if (radius <= 0) break;
    }
  }

  @override
  bool shouldRepaint(covariant _RingTripletPainter oldDelegate) {
    if (oldDelegate.specs.length != specs.length) return true;
    for (var i = 0; i < specs.length; i++) {
      final current = specs[i];
      final previous = oldDelegate.specs[i];
      if (current.progress != previous.progress || current.color != previous.color) {
        return true;
      }
    }
    return oldDelegate.backgroundColor != backgroundColor;
  }
}
