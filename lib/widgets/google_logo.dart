import 'dart:math' as math;
import 'package:flutter/material.dart';

class GoogleLogo extends StatelessWidget {
  final double size;
  final Color backgroundColor;

  const GoogleLogo({
    super.key,
    required this.size,
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: GoogleLogoPainter(backgroundColor: backgroundColor),
      ),
    );
  }
}

class GoogleLogoPainter extends CustomPainter {
  final Color backgroundColor;
  const GoogleLogoPainter({this.backgroundColor = Colors.white});

  double degToRad(double deg) => deg * math.pi / 180.0;

  @override
  void paint(Canvas canvas, Size size) {
    final double side = math.min(size.width, size.height);
    final Offset center = Offset(side / 2, side / 2);

    // Ring thickness and radius
    final double strokeWidth = side * 0.165;
    final double radius = (side - strokeWidth) / 2;
    final Rect arcRect = Rect.fromCircle(center: center, radius: radius);

    final Paint arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // The actual Google "G" logo color arrangement (clockwise from gap):
    // Gap at right side (3 o'clock)
    // Blue (right to bottom) -> Green (bottom to left)
    // -> Yellow (left to top) -> Red (top, stops before gap)

    // Starting angle at 0° (3 o'clock / right side) where gap begins

    // Blue arc: starts from right side, goes down
    const double blueStartDeg = 0.0;
    const double blueSweepDeg = 90.0;

    // Green arc: from bottom going to left
    final double greenStartDeg = blueStartDeg + blueSweepDeg;
    const double greenSweepDeg = 90.0;

    // Yellow arc: from left going up
    final double yellowStartDeg = greenStartDeg + greenSweepDeg;
    const double yellowSweepDeg = 90.0;

    // Red arc: from top going toward right (stops before gap)
    final double redStartDeg = yellowStartDeg + yellowSweepDeg;
    const double redSweepDeg = 45.0;

    // Draw Blue arc (right to bottom)
    arcPaint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      arcRect,
      degToRad(blueStartDeg),
      degToRad(blueSweepDeg),
      false,
      arcPaint,
    );

    // Draw Green arc (bottom to left)
    arcPaint.color = const Color(0xFF34A853);
    canvas.drawArc(
      arcRect,
      degToRad(greenStartDeg),
      degToRad(greenSweepDeg),
      false,
      arcPaint,
    );

    // Draw Yellow arc (left to top)
    arcPaint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      arcRect,
      degToRad(yellowStartDeg),
      degToRad(yellowSweepDeg),
      false,
      arcPaint,
    );

    // Draw Red arc (top, partial)
    arcPaint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      arcRect,
      degToRad(redStartDeg),
      degToRad(redSweepDeg),
      false,
      arcPaint,
    );

    // Inner cutout (background circle)
    final Paint innerPaint = Paint()..color = backgroundColor;
    final double innerRadius = radius - strokeWidth / 2;
    canvas.drawCircle(center, innerRadius, innerPaint);

    // Blue horizontal bar extending from center to the right (through the gap)
    final Paint barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    // The bar extends horizontally to the right at the same vertical center
    // Extended further and with square edge on the right
    final double barLength = radius + strokeWidth * 0.6;
    final double barHeight = strokeWidth * 0.95;

    // Create horizontal bar with rounded left edge and square right edge
    final Path barPath = Path();
    final double barTop = center.dy - barHeight / 2;
    final double barLeft = center.dx;

    // Start from top-left with rounded corner
    barPath.moveTo(barLeft, barTop + barHeight / 2);
    barPath.arcToPoint(
      Offset(barLeft, barTop + barHeight),
      radius: Radius.circular(barHeight / 2),
      clockwise: false,
    );

    // Bottom edge going right
    barPath.lineTo(barLeft + barLength, barTop + barHeight);

    // Right edge (square)
    barPath.lineTo(barLeft + barLength, barTop);

    // Top edge going back left
    barPath.lineTo(barLeft, barTop);

    // Close with left rounded corner
    barPath.arcToPoint(
      Offset(barLeft, barTop + barHeight / 2),
      radius: Radius.circular(barHeight / 2),
      clockwise: false,
    );

    canvas.drawPath(barPath, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
