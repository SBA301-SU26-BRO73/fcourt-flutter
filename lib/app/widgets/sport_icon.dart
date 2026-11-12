import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Sports the app draws an icon for.
enum SportKind { tennis, badminton, pickleball, football, basketball, volleyball, other }

/// Maps a sport (type) name, with or without Vietnamese diacritics, to a kind.
SportKind sportKindOf(String? name) {
  final text = (name ?? '').toLowerCase();
  bool has(List<String> words) => words.any(text.contains);
  if (has(['tennis', 'quần vợt', 'quan vot'])) return SportKind.tennis;
  if (has(['cầu lông', 'cau long', 'badminton'])) return SportKind.badminton;
  if (has(['pickleball'])) return SportKind.pickleball;
  if (has(['bóng đá', 'bong da', 'football', 'soccer', 'futsal'])) {
    return SportKind.football;
  }
  if (has(['bóng rổ', 'bong ro', 'basketball'])) return SportKind.basketball;
  if (has(['bóng chuyền', 'bong chuyen', 'volleyball'])) {
    return SportKind.volleyball;
  }
  return SportKind.other;
}

/// One outlined icon per sport, in the same 2dp-stroke style as the Material
/// icons used everywhere else. Material has no badminton or pickleball glyph,
/// so those two are drawn here.
class SportIcon extends StatelessWidget {
  const SportIcon(this.kind, {super.key, this.size = 24, this.color});

  /// Convenience for a sport (type) name.
  SportIcon.named(String? name, {super.key, this.size = 24, this.color})
    : kind = sportKindOf(name);

  final SportKind kind;
  final double size;
  final Color? color;

  static IconData? _material(SportKind kind) => switch (kind) {
    SportKind.tennis => Icons.sports_tennis_outlined,
    SportKind.football => Icons.sports_soccer_outlined,
    SportKind.basketball => Icons.sports_basketball_outlined,
    SportKind.volleyball => Icons.sports_volleyball_outlined,
    SportKind.other => Icons.stadium_outlined,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final tint = color ?? IconTheme.of(context).color ?? Colors.black;
    final data = _material(kind);
    if (data != null) return Icon(data, size: size, color: tint);
    return Semantics(
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: kind == SportKind.badminton
              ? _ShuttlecockPainter(tint)
              : _PicklePainter(tint),
        ),
      ),
    );
  }
}

Paint _stroke(Color color, double unit) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.8 * unit
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

class _ShuttlecockPainter extends CustomPainter {
  const _ShuttlecockPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 24;
    final paint = _stroke(color, u);
    Offset p(double x, double y) => Offset(x * u, y * u);
    // Cork.
    canvas.drawCircle(p(12, 19.2), 2.4 * u, paint);
    // Skirt of feathers.
    final skirt = Path()
      ..moveTo(10.1, 17.5)
      ..lineTo(5.2, 5.2)
      ..quadraticBezierTo(12, 2, 18.8, 5.2)
      ..lineTo(13.9, 17.5);
    canvas.drawPath(skirt.transform(Matrix4.diagonal3Values(u, u, 1).storage), paint);
    canvas.drawLine(p(12, 16.8), p(12, 3.6), paint);
    canvas.drawLine(p(7.3, 10.4), p(16.7, 10.4), paint);
  }

  @override
  bool shouldRepaint(_ShuttlecockPainter old) => old.color != color;
}

class _PicklePainter extends CustomPainter {
  const _PicklePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 24;
    final paint = _stroke(color, u);
    canvas.save();
    canvas.scale(u);
    // Paddle: head and handle, tilted down to the right.
    canvas.save();
    canvas.translate(9.2, 8.6);
    canvas.rotate(-math.pi / 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-4.4, -8.2, 8.8, 10.6),
        const Radius.circular(4.4),
      ),
      paint,
    );
    canvas.drawLine(const Offset(0, 2.4), const Offset(0, 6.6), paint);
    canvas.restore();
    // Ball.
    final ball = _stroke(color, 1);
    canvas.drawCircle(const Offset(17.6, 17.6), 3.4, ball);
    final dot = Paint()..color = color;
    for (final o in const [Offset(16.4, 16.6), Offset(18.6, 17.2), Offset(17.4, 19.0)]) {
      canvas.drawCircle(o, .55, dot);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PicklePainter old) => old.color != color;
}
