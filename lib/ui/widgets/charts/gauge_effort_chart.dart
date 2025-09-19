import 'dart:math' as math;

import 'package:flutter/material.dart';

class GaugeEffortChart extends StatelessWidget {
  const GaugeEffortChart({
    super.key,
    required this.score,
    this.size = 240,
    this.label = 'gemittelter Aufwand',
    this.updatedAt,
  });

  final double score;
  final double size;
  final String label;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final palette = _GaugePalette.resolve(theme);
     final updatedText = _formatUpdatedAt(updatedAt);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _normalize(score)),
      duration: const Duration(milliseconds: 680),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) {
        final displayValue = (progress * 100).clamp(0, 100).round();
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scaleX: -1,
                alignment: Alignment.center,
                child: CustomPaint(
                  size: Size.square(size),
                  painter: _GaugePainter(
                    progress: progress,
                    segments: palette.segments,
                    trackColor: palette.track,
                    pointerColor: palette.pointer,
                    shadowColor: palette.shadow,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$displayValue',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.textTheme.titleMedium?.color?.withOpacity(
                        0.8,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ), 
                        if (updatedText != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Zuletzt aktualisiert: $updatedText',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static double _normalize(double value) {
    if (value.isNaN) return 0;
    if (value < 0) return 0;
    if (value > 100) return 1;
    return value / 100;
  }
}
  String? _formatUpdatedAt(DateTime? date) {
    if (date == null) return null;
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year · $hour:$minute';
  }

class _GaugeSegment {
  const _GaugeSegment({
    required this.start,
    required this.end,
    required this.color,
  });

  final double start;
  final double end;
  final Color color;
}

class _GaugePalette {
  const _GaugePalette({
    required this.track,
    required this.pointer,
    required this.shadow,
    required this.segments,
  });

  final Color track;
  final Color pointer;
  final Color shadow;
  final List<_GaugeSegment> segments;

  static _GaugePalette resolve(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final track = theme.colorScheme.surfaceVariant.withOpacity(
      isDark ? 0.35 : 0.22,
    );
    final pointer = theme.colorScheme.primary;
    final shadow = theme.shadowColor.withOpacity(isDark ? 0.18 : 0.28);

    final green = isDark ? const Color(0xFF30D158) : const Color(0xFF34C759);
    final yellow = isDark ? const Color(0xFFFFD60A) : const Color(0xFFFFC043);
    final red = isDark ? const Color(0xFFFF375F) : const Color(0xFFFF4D67);

    return _GaugePalette(
      track: track,
      pointer: pointer,
      shadow: shadow,
      segments: <_GaugeSegment>[
        _GaugeSegment(start: 0.0, end: 0.6, color: green),
        _GaugeSegment(start: 0.6, end: 0.85, color: yellow),
        _GaugeSegment(start: 0.85, end: 1.0, color: red),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.progress,
    required this.segments,
    required this.trackColor,
    required this.pointerColor,
    required this.shadowColor,
  });

  final double progress;
  final List<_GaugeSegment> segments;
  final Color trackColor;
  final Color pointerColor;
  final Color shadowColor;

  static const double _strokeWidth = 16;
  static const double _pointerWidth = 6;
  static const double _startAngle = math.pi;
  static const double _sweepAngle = math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width, size.height) / 2 - _strokeWidth;
    final center = Offset(size.width / 2, size.height / 2 + _strokeWidth * 0.5);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final basePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    canvas.drawArc(rect, _startAngle, _sweepAngle, false, basePaint);

    for (final segment in segments) {
      final activeEnd = progress.clamp(0, 1);
      if (activeEnd <= segment.start) continue;
      final segmentEnd = math.min(segment.end, activeEnd);
      final startAngle = _startAngle + _sweepAngle * segment.start;
      final sweep = _sweepAngle * (segmentEnd - segment.start);

      final paint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = segment.color;

      canvas.drawArc(rect, startAngle, sweep, false, paint);
    }

    final pointerAngle = _startAngle + _sweepAngle * progress.clamp(0, 1);
    final pointerLength = radius - _strokeWidth * 0.25;
    final pointerEnd = Offset(
      center.dx + math.cos(pointerAngle) * pointerLength,
      center.dy + math.sin(pointerAngle) * pointerLength,
    );

    final pointerShadow = Paint()
      ..color = shadowColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _pointerWidth + 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(center, pointerEnd, pointerShadow);

    final pointerPaint = Paint()
      ..color = pointerColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _pointerWidth
      ..style = PaintingStyle.stroke;

    canvas.drawLine(center, pointerEnd, pointerPaint);

    final knobPaint = Paint()..color = pointerColor.withOpacity(0.12);
    canvas.drawCircle(center, _strokeWidth * 1.1, knobPaint);
    canvas.drawCircle(
      center,
      _pointerWidth * 1.2,
      Paint()..color = pointerColor,
    );

    final tipPaint = Paint()..color = pointerColor;
    canvas.drawCircle(pointerEnd, _pointerWidth * 0.9, tipPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    if (oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor) {
      return true;
    }
    if (oldDelegate.pointerColor != pointerColor ||
        oldDelegate.shadowColor != shadowColor) {
      return true;
    }
    if (oldDelegate.segments.length != segments.length) return true;
    for (var i = 0; i < segments.length; i++) {
      final current = segments[i];
      final previous = oldDelegate.segments[i];
      if (current.start != previous.start ||
          current.end != previous.end ||
          current.color != previous.color) {
        return true;
      }
    }
    return false;
  }
}
