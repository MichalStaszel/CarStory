import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../engine/progress.dart';

/// The player's character, painted in an original style inspired by 1990s
/// point-and-click adventure backdrops: flat painted shapes, warm lamp light,
/// rain on the window. Items the player found appear on the figure.
/// Drawn on a 300 x 400 canvas and scaled to fit.
class PortraitPainter extends CustomPainter {
  PortraitPainter(this.progress, {this.stamp});
  final Progress progress;
  final String? stamp;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final s = math.min(size.width / 300, size.height / 400);
    canvas.translate((size.width - 300 * s) / 2, (size.height - 400 * s) / 2);
    canvas.scale(s);
    _scene(canvas);
    _figure(canvas);
    _items(canvas);
    if (progress.done && stamp != null) _stamp(canvas, stamp!);
    canvas.restore();
  }

  Paint _fill(Color c) => Paint()..color = c;

  Path _poly(List<double> pts) {
    final p = Path()..moveTo(pts[0], pts[1]);
    for (var i = 2; i < pts.length; i += 2) {
      p.lineTo(pts[i], pts[i + 1]);
    }
    return p..close();
  }

  void _scene(Canvas c) {
    const full = Rect.fromLTWH(0, 0, 300, 400);
    c.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1D2B3A), Color(0xFF3C4B52), Color(0xFF7A5A3A)],
          stops: [0, .55, 1],
        ).createShader(full),
    );
    // Wallpaper stripes.
    c.drawRect(const Rect.fromLTWH(150, 0, 150, 260), _fill(const Color(0x8C5B2F26)));
    for (var x = 170.0; x < 300; x += 30) {
      c.drawRect(Rect.fromLTWH(x, 0, 5, 260), _fill(const Color(0x807A4434)));
    }
    // Window with rain and city lights.
    c.drawRect(const Rect.fromLTWH(22, 30, 120, 170), _fill(const Color(0xFF2A3B4A)));
    c.drawRect(const Rect.fromLTWH(26, 176, 112, 20), _fill(const Color(0xFF1A2430)));
    for (final x in const <double>[34, 58, 98, 118]) {
      c.drawRect(Rect.fromLTWH(x, 181, 6, 6), _fill(const Color(0xFFF2C46B)));
    }
    final rain = Paint()
      ..color = const Color(0x8C9FB6C4)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 22; i++) {
      final x = 28.0 + (i * 37) % 110, y = 36.0 + (i * 53) % 150;
      c.drawLine(Offset(x, y), Offset(x - 3, y + 10 + (i % 3) * 4), rain);
    }
    final frame = Paint()
      ..color = const Color(0xFF4A3322)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    c.drawRect(const Rect.fromLTWH(22, 30, 120, 170), frame);
    c.drawLine(const Offset(82, 30), const Offset(82, 200), frame..strokeWidth = 6);
    c.drawLine(const Offset(22, 115), const Offset(142, 115), frame);
    // Lamp glow.
    c.drawRect(
      full,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(.56, -.6),
          radius: .7,
          colors: [Color(0xD9FFD58A), Color(0x59E59A4A), Color(0x00E59A4A)],
          stops: [0, .35, 1],
        ).createShader(full),
    );
    c.drawRect(const Rect.fromLTWH(0, 330, 300, 70), _fill(const Color(0xFF2C1D15)));
  }

  void _figure(Canvas c) {
    // Trench coat.
    final coat = Path()
      ..moveTo(78, 400)
      ..lineTo(92, 262)
      ..quadraticBezierTo(104, 224, 150, 214)
      ..quadraticBezierTo(196, 224, 208, 262)
      ..lineTo(222, 400)
      ..close();
    c.drawPath(
      coat,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC9A86A), Color(0xFF9C7A45), Color(0xFF5E4526)],
        ).createShader(const Rect.fromLTWH(78, 214, 144, 186)),
    );
    c.drawPath(
      Path()
        ..moveTo(150, 214)
        ..quadraticBezierTo(196, 224, 208, 262)
        ..lineTo(222, 400)
        ..lineTo(170, 400)
        ..lineTo(160, 268)
        ..close(),
      _fill(const Color(0x735E4526)),
    );
    // Arms and hands.
    c.drawPath(
        Path()
          ..moveTo(92, 262)
          ..quadraticBezierTo(72, 300, 80, 352)
          ..lineTo(102, 352)
          ..quadraticBezierTo(100, 304, 112, 276)
          ..close(),
        _fill(const Color(0xFFA8864F)));
    c.drawPath(
        Path()
          ..moveTo(208, 262)
          ..quadraticBezierTo(228, 300, 220, 352)
          ..lineTo(198, 352)
          ..quadraticBezierTo(200, 304, 188, 276)
          ..close(),
        _fill(const Color(0xFF6E5230)));
    c.drawOval(Rect.fromCenter(center: const Offset(91, 358), width: 26, height: 22), _fill(const Color(0xFFD49A6A)));
    c.drawOval(Rect.fromCenter(center: const Offset(209, 358), width: 26, height: 22), _fill(const Color(0xFFB98058)));
    // Lapels, shirt, tie, belt.
    c.drawPath(_poly([128, 222, 150, 300, 172, 222, 164, 218, 150, 262, 136, 218]), _fill(const Color(0xFFEFE6D4)));
    c.drawPath(_poly([146, 236, 154, 236, 157, 300, 150, 312, 143, 300]), _fill(const Color(0xFF8E2A1C)));
    c.drawPath(_poly([120, 222, 150, 300, 124, 300, 104, 252]), _fill(const Color(0xFFB38F55)));
    c.drawPath(_poly([180, 222, 150, 300, 176, 300, 196, 252]), _fill(const Color(0xFF7D5F35)));
    c.drawRect(const Rect.fromLTWH(90, 318, 120, 14), _fill(const Color(0xFF6B5030)));
    c.drawRect(
        const Rect.fromLTWH(142, 316, 16, 18),
        Paint()
          ..color = const Color(0xFFC9A24A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    // Neck and head.
    c.drawRect(const Rect.fromLTWH(138, 196, 24, 26), _fill(const Color(0xFFB98058)));
    final face = Rect.fromCenter(center: const Offset(150, 168), width: 60, height: 74);
    c.drawOval(
      face,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFFF0C79A), Color(0xFFD49A6A), Color(0xFF8E5A3A)], stops: [0, .6, 1])
            .createShader(face),
    );
    final hatShadow = Path()
      ..moveTo(120, 150)
      ..quadraticBezierTo(150, 162, 180, 150)
      ..lineTo(180, 160)
      ..quadraticBezierTo(150, 170, 120, 160)
      ..close();
    c.drawPath(hatShadow, _fill(const Color(0x733A2418)));
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4
      ..color = const Color(0xFF2A1810);
    c.drawPath(Path()..moveTo(133, 160)..quadraticBezierTo(139, 157, 145, 160), line);
    c.drawPath(Path()..moveTo(155, 160)..quadraticBezierTo(161, 157, 167, 160), line);
    c.drawPath(Path()..moveTo(150, 164)..quadraticBezierTo(146, 178, 149, 183)..lineTo(156, 182),
        line..color = const Color(0xFF7A4A30)..strokeWidth = 2);
    c.drawPath(Path()..moveTo(139, 191)..quadraticBezierTo(150, 195, 161, 190),
        line..color = const Color(0xFF5A2E20)..strokeWidth = 2.4);
    // Fedora.
    const hatShader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF5A4334), Color(0xFF241A14)],
    );
    final hatPaint = Paint()..shader = hatShader.createShader(const Rect.fromLTWH(100, 100, 100, 56));
    c.drawPath(
        Path()
          ..moveTo(100, 146)
          ..quadraticBezierTo(150, 128, 200, 146)
          ..quadraticBezierTo(206, 152, 196, 154)
          ..quadraticBezierTo(150, 142, 104, 154)
          ..quadraticBezierTo(94, 152, 100, 146)
          ..close(),
        hatPaint);
    c.drawPath(
        Path()
          ..moveTo(118, 144)
          ..quadraticBezierTo(120, 106, 150, 102)
          ..quadraticBezierTo(180, 106, 182, 144)
          ..quadraticBezierTo(150, 136, 118, 144)
          ..close(),
        hatPaint);
    c.drawPath(
        Path()
          ..moveTo(119, 134)
          ..quadraticBezierTo(150, 128, 181, 134)
          ..lineTo(182, 144)
          ..quadraticBezierTo(150, 136, 118, 144)
          ..close(),
        _fill(const Color(0xD98E2A1C)));
  }

  void _items(Canvas c) {
    final p = progress;
    if (p.clues.containsKey('badge')) {
      c.drawOval(Rect.fromCenter(center: const Offset(174, 248), width: 16, height: 20), _fill(const Color(0xFFE0B452)));
      c.drawOval(Rect.fromCenter(center: const Offset(174, 248), width: 10, height: 13), _fill(const Color(0xFFA87A1F)));
    }
    if (p.items.containsKey('notebook')) {
      c.save();
      c.translate(66, 286);
      c.rotate(-8 * math.pi / 180);
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 34, 46), const Radius.circular(3)),
          _fill(const Color(0xFF3B2A20)));
      c.drawRect(const Rect.fromLTWH(3, 3, 28, 40), _fill(const Color(0xFF4A3528)));
      final gold = Paint()
        ..color = const Color(0xFFC9A24A)
        ..strokeWidth = 1.6;
      c.drawLine(const Offset(8, 12), const Offset(26, 12), gold);
      c.drawLine(const Offset(8, 18), const Offset(22, 18), gold);
      c.restore();
    }
    if (p.items.containsKey('page')) {
      c.save();
      c.translate(212, 296);
      c.rotate(10 * math.pi / 180);
      c.drawPath(_poly([0, 0, 28, 0, 30, 36, 16, 36, 0, 38]), _fill(const Color(0xFFE8DCC2)));
      c.restore();
    }
    if (p.items.containsKey('revolver')) {
      c.save();
      c.translate(206, 352);
      c.rotate(18 * math.pi / 180);
      c.drawRect(const Rect.fromLTWH(-4, 0, 36, 8), _fill(const Color(0xFF9AA3A8)));
      c.drawRect(const Rect.fromLTWH(-4, 0, 36, 3), _fill(const Color(0xFFD9E0E3)));
      c.drawCircle(const Offset(4, 6), 7, _fill(const Color(0xFF7D868B)));
      c.drawPath(_poly([-10, 6, -12, 20, -8, 26, 0, 24, -2, 16, 2, 8]), _fill(const Color(0xFF3A2A1E)));
      c.restore();
    }
    if (p.items.containsKey('key7')) {
      final gold = Paint()
        ..color = const Color(0xFFE0B452)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      c.drawLine(const Offset(86, 366), const Offset(86, 388), gold..strokeWidth = 1.5);
      c.drawCircle(const Offset(86, 394), 6, gold..strokeWidth = 3);
    }
  }

  void _stamp(Canvas c, String text) {
    c.save();
    c.translate(150, 368);
    c.rotate(-5 * math.pi / 180);
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 190, height: 36), const Radius.circular(5));
    c.drawRRect(r, _fill(const Color(0x992C1D15)));
    c.drawRRect(
        r,
        Paint()
          ..color = const Color(0xFFD4503A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Color(0xFFE0604A), fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 2),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 186);
    tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
    c.restore();
  }

  @override
  bool shouldRepaint(PortraitPainter old) => true;
}
