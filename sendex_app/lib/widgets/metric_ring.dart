import 'dart:math';
import 'package:flutter/material.dart';

class MetricRing extends StatelessWidget {
  final double value;
  final double maxValue;
  final String label;
  final String unit;
  final IconData icon;
  final Color color;

  const MetricRing({
    super.key,
    required this.value,
    required this.maxValue,
    required this.label,
    required this.unit,
    required this.icon,
    this.color = const Color(0xFF58A6FF),
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: CustomPaint(
            painter: _RingPainter(fraction: fraction, color: color),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(height: 2),
                  Text(
                    value.toStringAsFixed(0),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        Text(unit, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color color;

  _RingPainter({required this.fraction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const strokeWidth = 5.0;

    final bgPaint = Paint()
      ..color = Colors.grey[800]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -pi / 2, 2 * pi * fraction, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.fraction != fraction;
}
