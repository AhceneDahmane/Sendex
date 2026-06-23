import 'dart:math';
import 'package:flutter/material.dart';
import '../models/gps_point.dart';

class PitchHeatmap extends StatelessWidget {
  final List<GpsPoint> points;

  const PitchHeatmap({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return CustomPaint(
          size: Size(w, h),
          painter: _PitchPainter(points, w, h),
        );
      },
    );
  }
}

class _PitchPainter extends CustomPainter {
  final List<GpsPoint> points;
  final double w;
  final double h;

  _PitchPainter(this.points, this.w, this.h);

  @override
  void paint(Canvas canvas, Size size) {
    _drawPitch(canvas);
    if (points.isEmpty) {
      _drawCentreCircle(canvas);
      return;
    }
    _drawHeatmap(canvas);
  }

  void _drawPitch(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFF2D7D3A);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & Size(w, h), const Radius.circular(4)), paint);
  }

  void _drawCentreCircle(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(w / 2, h / 2), min(w, h) * 0.2, paint);
  }

  void _drawHeatmap(Canvas canvas) {
    final latRange = _calcRange((p) => p.lat);
    final lngRange = _calcRange((p) => p.lng);
    final padding = 20.0;

    for (final p in points) {
      final x = padding + ((p.lng - lngRange.$1) / (lngRange.$2 - lngRange.$1 + 0.01)) * (w - 2 * padding);
      final y = padding + ((latRange.$2 - p.lat) / (latRange.$2 - latRange.$1 + 0.01)) * (h - 2 * padding);
      final alpha = (p.speed / 30).clamp(0.1, 0.9);
      final color = p.speed > 18
          ? Color.fromRGBO(255, 51, 51, alpha)
          : Color.fromRGBO(77, 153, 255, alpha * 0.6);

      canvas.drawCircle(Offset(x, y), p.speed > 18 ? 5 : 4, Paint()..color = color);
    }

    final sprints = points.where((p) => p.speed > 18);
    if (sprints.length > 1) {
      final paint = Paint()
        ..color = Colors.red.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (final s in sprints) {
        final x = padding + ((s.lng - lngRange.$1) / (lngRange.$2 - lngRange.$1 + 0.01)) * (w - 2 * padding);
        final y = padding + ((latRange.$2 - s.lat) / (latRange.$2 - latRange.$1 + 0.01)) * (h - 2 * padding);
        canvas.drawCircle(Offset(x, y), 8, paint);
      }
    }
  }

  (double, double) _calcRange(double Function(GpsPoint) f) {
    double min = double.infinity, max = double.negativeInfinity;
    for (final p in points) {
      final v = f(p);
      if (v < min) min = v;
      if (v > max) max = v;
    }
    return (min, max);
  }

  @override
  bool shouldRepaint(covariant _PitchPainter old) => old.points != points;
}
