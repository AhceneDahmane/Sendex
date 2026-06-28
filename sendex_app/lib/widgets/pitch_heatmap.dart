import 'dart:math';
import 'package:flutter/material.dart';
import '../models/gps_point.dart';

class PitchHeatmap extends StatelessWidget {
  final List<GpsPoint> points;
  final String sport;
  final double? fieldLength;
  final double? fieldWidth;

  const PitchHeatmap({
    super.key,
    required this.points,
    this.sport = 'Football',
    this.fieldLength,
    this.fieldWidth,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final cw = constraints.maxWidth;
        final ch = constraints.maxHeight;

        final fl = fieldLength ?? 105;
        final fw = fieldWidth ?? 68;
        final fieldRatio = fl / fw;
        final canvasRatio = cw / ch;

        double ox, oy, pw, ph;
        if (fieldRatio > canvasRatio) {
          pw = cw;
          ph = cw / fieldRatio;
          ox = 0;
          oy = (ch - ph) / 2;
        } else {
          ph = ch;
          pw = ch * fieldRatio;
          ox = (cw - pw) / 2;
          oy = 0;
        }

        return CustomPaint(
          size: Size(cw, ch),
          painter: _PitchPainter(points, cw, ch, sport, ox, oy, pw, ph),
        );
      },
    );
  }
}

class _PitchPainter extends CustomPainter {
  final List<GpsPoint> points;
  final double cw, ch, ox, oy, pw, ph;
  final String sport;

  _PitchPainter(this.points, this.cw, this.ch, this.sport, this.ox, this.oy, this.pw, this.ph);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(ox, oy, pw, ph));
    _drawField(canvas);
    if (points.isEmpty) {
      _drawCentreCircle(canvas);
    } else {
      _drawHeatmap(canvas);
    }
    canvas.restore();
  }

  void _drawField(Canvas canvas) {
    final paint = Paint()..color = _fieldColor();
    canvas.drawRRect(RRect.fromRectAndRadius(Offset(ox, oy) & Size(pw, ph), const Radius.circular(4)), paint);
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(Rect.fromLTWH(ox + 2, oy + 2, pw - 4, ph - 4), linePaint);
    _drawSportLines(canvas, linePaint);
  }

  Color _fieldColor() {
    switch (sport) {
      case 'Basketball':
        return const Color(0xFFC68642);
      case 'Tennis':
        return const Color(0xFF2E7D32);
      case 'Handball':
        return const Color(0xFF5D4037);
      case 'Rugby':
        return const Color(0xFF33691E);
      case 'Athletics':
        return const Color(0xFF4E342E);
      default:
        return const Color(0xFF2D7D3A);
    }
  }

  double get w => pw;
  double get h => ph;

  void _drawSportLines(Canvas canvas, Paint line) {
    switch (sport) {
      case 'Basketball':
        _drawBasketball(canvas, line);
        break;
      case 'Rugby':
        _drawRugby(canvas, line);
        break;
      case 'Handball':
        _drawHandball(canvas, line);
        break;
      case 'Tennis':
        _drawTennis(canvas, line);
        break;
      case 'Athletics':
        _drawAthletics(canvas, line);
        break;
      default:
        _drawFootball(canvas, line);
    }
  }

  void _drawFootball(Canvas canvas, Paint line) {
    canvas.drawLine(Offset(ox, oy + h / 2), Offset(ox + w, oy + h / 2), line);
    canvas.drawCircle(Offset(ox + w / 2, oy + h / 2), min(w, h) * 0.15, line);
    canvas.drawCircle(Offset(ox + w / 2, oy + h / 2), 3, line);
    final paW = w * 0.2;
    final paH = h * 0.45;
    canvas.drawRect(Rect.fromLTWH(ox, oy + h / 2 - paH / 2, paW, paH), line);
    canvas.drawRect(Rect.fromLTWH(ox + w - paW, oy + h / 2 - paH / 2, paW, paH), line);
    final gaW = w * 0.08;
    final gaH = h * 0.2;
    canvas.drawRect(Rect.fromLTWH(ox, oy + h / 2 - gaH / 2, gaW, gaH), line);
    canvas.drawRect(Rect.fromLTWH(ox + w - gaW, oy + h / 2 - gaH / 2, gaW, gaH), line);
    canvas.drawCircle(Offset(ox + paW * 0.7, oy + h / 2), 3, line);
    canvas.drawCircle(Offset(ox + w - paW * 0.7, oy + h / 2), 3, line);
  }

  void _drawBasketball(Canvas canvas, Paint line) {
    canvas.drawLine(Offset(ox, oy + h / 2), Offset(ox + w, oy + h / 2), line);
    canvas.drawCircle(Offset(ox + w / 2, oy + h / 2), min(w, h) * 0.15, line);
    canvas.drawArc(Rect.fromLTWH(ox - w * 0.3, oy + h * 0.15, w * 0.6, h * 0.7), 0, pi, false, line);
    canvas.drawArc(Rect.fromLTWH(ox + w * 0.7, oy + h * 0.15, w * 0.6, h * 0.7), 0, pi, true, line);
    canvas.drawCircle(Offset(ox + w * 0.15, oy + h / 2), h * 0.12, line);
    canvas.drawCircle(Offset(ox + w * 0.85, oy + h / 2), h * 0.12, line);
    canvas.drawRect(Rect.fromLTWH(ox, oy + h * 0.35, w * 0.15, h * 0.3), line);
    canvas.drawRect(Rect.fromLTWH(ox + w * 0.85, oy + h * 0.35, w * 0.15, h * 0.3), line);
  }

  void _drawRugby(Canvas canvas, Paint line) {
    canvas.drawLine(Offset(ox, oy + h / 2), Offset(ox + w, oy + h / 2), line);
    canvas.drawLine(Offset(ox + w * 0.22, oy), Offset(ox + w * 0.22, oy + h), line);
    canvas.drawLine(Offset(ox + w * 0.78, oy), Offset(ox + w * 0.78, oy + h), line);
    canvas.drawLine(Offset(ox + w * 0.1, oy), Offset(ox + w * 0.1, oy + h), line);
    canvas.drawLine(Offset(ox + w * 0.9, oy), Offset(ox + w * 0.9, oy + h), line);
    canvas.drawCircle(Offset(ox + w / 2, oy + h / 2), min(w, h) * 0.08, line);
    canvas.drawLine(Offset(ox, oy + h * 0.3), Offset(ox, oy + h * 0.7), Paint()..color = Colors.red.withValues(alpha: 0.4)..strokeWidth = 3);
    canvas.drawLine(Offset(ox + w, oy + h * 0.3), Offset(ox + w, oy + h * 0.7), Paint()..color = Colors.red.withValues(alpha: 0.4)..strokeWidth = 3);
    canvas.drawLine(Offset(ox + w * 0.05, oy), Offset(ox + w * 0.05, oy + h), line);
    canvas.drawLine(Offset(ox + w * 0.95, oy), Offset(ox + w * 0.95, oy + h), line);
  }

  void _drawHandball(Canvas canvas, Paint line) {
    canvas.drawLine(Offset(ox, oy + h / 2), Offset(ox + w, oy + h / 2), line);
    canvas.drawCircle(Offset(ox + w / 2, oy + h / 2), min(w, h) * 0.06, line);
    canvas.drawArc(Rect.fromLTWH(ox - w * 0.15, oy + h * 0.15, w * 0.3, h * 0.7), -pi / 2, pi, false, line);
    canvas.drawArc(Rect.fromLTWH(ox + w * 0.85, oy + h * 0.15, w * 0.3, h * 0.7), pi / 2, pi, false, line);
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawArc(Rect.fromLTWH(ox - w * 0.25, oy + h * 0.05, w * 0.5, h * 0.9), -pi / 2, pi, false, dashPaint);
    canvas.drawArc(Rect.fromLTWH(ox + w * 0.75, oy + h * 0.05, w * 0.5, h * 0.9), pi / 2, pi, false, dashPaint);
    canvas.drawLine(Offset(ox, oy + h * 0.35), Offset(ox, oy + h * 0.65), Paint()..color = Colors.white..strokeWidth = 3);
    canvas.drawLine(Offset(ox + w, oy + h * 0.35), Offset(ox + w, oy + h * 0.65), Paint()..color = Colors.white..strokeWidth = 3);
  }

  void _drawTennis(Canvas canvas, Paint line) {
    final m = 0.1;
    canvas.drawLine(Offset(ox + w / 2, oy), Offset(ox + w / 2, oy + h), Paint()..color = Colors.white.withValues(alpha: 0.3)..strokeWidth = 3);
    canvas.drawLine(Offset(ox, oy + h * 0.28), Offset(ox + w, oy + h * 0.28), line);
    canvas.drawLine(Offset(ox, oy + h * 0.72), Offset(ox + w, oy + h * 0.72), line);
    canvas.drawLine(Offset(ox + w / 2, oy + h * 0.28), Offset(ox + w / 2, oy + h * 0.72), line);
    canvas.drawLine(Offset(ox + w * m, oy), Offset(ox + w * m, oy + h), line);
    canvas.drawLine(Offset(ox + w * (1 - m), oy), Offset(ox + w * (1 - m), oy + h), line);
    final d = 0.05;
    canvas.drawLine(Offset(ox + w * d, oy), Offset(ox + w * d, oy + h), line);
    canvas.drawLine(Offset(ox + w * (1 - d), oy), Offset(ox + w * (1 - d), oy + h), line);
  }

  void _drawAthletics(Canvas canvas, Paint line) {
    final rx = w * 0.35;
    final ry = h * 0.4;
    final center = Offset(ox + w / 2, oy + h / 2);
    canvas.drawOval(Rect.fromCenter(center: center, width: rx * 2, height: ry * 2), line);
    canvas.drawOval(Rect.fromCenter(center: center, width: rx * 1.7, height: ry * 1.7), line);
    canvas.drawOval(Rect.fromCenter(center: center, width: rx * 1.4, height: ry * 1.4), line);
    canvas.drawOval(Rect.fromCenter(center: center, width: rx * 1.1, height: ry * 1.1), line);
    canvas.drawLine(Offset(ox + w * 0.5 - 10, center.dy - ry), Offset(ox + w * 0.5 - 10, center.dy + ry), Paint()..color = Colors.red.withValues(alpha: 0.4)..strokeWidth = 3);
    canvas.drawLine(Offset(ox + w * 0.3, oy), Offset(ox + w * 0.3, oy + h), line);
    canvas.drawLine(Offset(ox + w * 0.7, oy), Offset(ox + w * 0.7, oy + h), line);
  }

  void _drawCentreCircle(Canvas canvas) {
    final radius = min(w, h) * (sport == 'Basketball' ? 0.15 : 0.2);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(ox + w / 2, oy + h / 2), radius, paint);
    if (sport == 'Football' || sport == 'Rugby' || sport == 'Handball') {
      canvas.drawLine(Offset(ox, oy + h / 2), Offset(ox + w, oy + h / 2), paint);
    }
  }

  void _drawHeatmap(Canvas canvas) {
    final latRange = _calcRange((p) => p.lat);
    final lngRange = _calcRange((p) => p.lng);
    const padding = 20.0;

    for (final p in points) {
      final x = ox + padding + ((p.lng - lngRange.$1) / (lngRange.$2 - lngRange.$1 + 0.01)) * (w - 2 * padding);
      final y = oy + padding + ((latRange.$2 - p.lat) / (latRange.$2 - latRange.$1 + 0.01)) * (h - 2 * padding);
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
        final x = ox + padding + ((s.lng - lngRange.$1) / (lngRange.$2 - lngRange.$1 + 0.01)) * (w - 2 * padding);
        final y = oy + padding + ((latRange.$2 - s.lat) / (latRange.$2 - latRange.$1 + 0.01)) * (h - 2 * padding);
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
  bool shouldRepaint(covariant _PitchPainter old) =>
      old.points != points || old.sport != sport || old.pw != pw || old.ph != ph;
}
