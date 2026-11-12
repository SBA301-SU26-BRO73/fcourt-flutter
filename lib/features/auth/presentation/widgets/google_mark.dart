import 'package:flutter/material.dart';

/// Google "G" in its four brand colours, drawn from the 24x24 vector paths.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Google',
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _GooglePainter()),
    ),
  );
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    void fill(Color c, Path p) {
      canvas.drawPath(
        p..close(),
        Paint()
          ..color = c
          ..isAntiAlias = true,
      );
    }

    fill(
      const Color(0xFF4285F4),
      Path()
        ..moveTo(21.6, 12.2)
        ..cubicTo(21.6, 11.5, 21.5, 10.8, 21.4, 10.1)
        ..lineTo(12, 10.1)
        ..lineTo(12, 14.1)
        ..lineTo(17.4, 14.1)
        ..cubicTo(17.2, 15.4, 16.4, 16.6, 15.4, 17.3)
        ..lineTo(15.4, 19.9)
        ..lineTo(18.8, 19.9)
        ..cubicTo(20.8, 18.0, 21.6, 15.4, 21.6, 12.2),
    );
    fill(
      const Color(0xFF34A853),
      Path()
        ..moveTo(12, 22)
        ..cubicTo(14.7, 22, 17, 21.1, 18.8, 19.5)
        ..lineTo(15.4, 16.9)
        ..cubicTo(14.5, 17.5, 13.4, 17.9, 12, 17.9)
        ..cubicTo(9.4, 17.9, 7.2, 16.2, 6.4, 13.9)
        ..lineTo(2.9, 13.9)
        ..lineTo(2.9, 16.6)
        ..cubicTo(4.6, 20.0, 8.0, 22, 12, 22),
    );
    fill(
      const Color(0xFFFBBC05),
      Path()
        ..moveTo(6.4, 13.9)
        ..cubicTo(6.2, 13.3, 6.1, 12.7, 6.1, 12.0)
        ..cubicTo(6.1, 11.3, 6.2, 10.7, 6.4, 10.1)
        ..lineTo(6.4, 7.4)
        ..lineTo(2.9, 7.4)
        ..cubicTo(2.3, 8.8, 2.0, 10.4, 2.0, 12.0)
        ..cubicTo(2.0, 13.6, 2.3, 15.2, 2.9, 16.6),
    );
    fill(
      const Color(0xFFEA4335),
      Path()
        ..moveTo(12, 6.1)
        ..cubicTo(13.5, 6.1, 14.8, 6.6, 15.8, 7.6)
        ..lineTo(18.8, 4.6)
        ..cubicTo(17.0, 2.9, 14.7, 2, 12, 2)
        ..cubicTo(8.0, 2, 4.6, 4.1, 2.9, 7.4)
        ..lineTo(6.4, 10.1)
        ..cubicTo(7.2, 7.8, 9.4, 6.1, 12, 6.1),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
