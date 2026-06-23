import 'package:flutter/material.dart';
import '../models/gps_point.dart';

class SpeedChart extends StatelessWidget {
  final List<GpsPoint> points;

  const SpeedChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return CustomPaint(
          size: Size(w, h),
          painter: _SpeedPainter(points, w, h),
        );
      },
    );
  }
}

class _SpeedPainter extends CustomPainter {
  final List<GpsPoint> points;
  final double w;
  final double h;

  _SpeedPainter(this.points, this.w, this.h);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.grey[900]!);
      return;
    }

    // Background
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.grey[900]!);

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.grey[700]!
      ..strokeWidth = 0.5;
    final maxSpeed = points.map((p) => p.speed).reduce((a, b) => a > b ? a : b).clamp(1, 30);
    for (int i = 0; i <= 4; i++) {
      final y = h * (1 - i / 4);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Speed line
    final linePaint = Paint()
      ..color = Colors.blue[300]!
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    final step = w / (points.length - 1);

    for (int i = 0; i < points.length; i++) {
      final x = i * step;
      final y = h * (1 - points[i].speed / maxSpeed);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    // Sprint threshold line
    final sprintPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final sprintY = h * (1 - 18 / maxSpeed);
    canvas.drawLine(Offset(0, sprintY), Offset(w, sprintY), sprintPaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: "Sprint",
      style: TextStyle(color: Colors.red.withValues(alpha: 0.6), fontSize: 10),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(w - textPainter.width - 4, sprintY - 14));
  }

  @override
  bool shouldRepaint(covariant _SpeedPainter old) => old.points != points;
}
