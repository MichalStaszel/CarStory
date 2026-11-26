import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../engine/progress.dart';

/// The story's protagonist as a moody painted portrait in the spirit of
/// mid-90s painted adventure-game backdrops (original art, not copied from
/// any game): a hotel room at night, rain on the glass, a red neon sign
/// outside, cold rim light, the face lost under the hat brim. The figure is
/// the story's fixed protagonist, so the player projects onto it; found
/// items are shown separately as evidence, not hung on the figure.
///
/// Painted on a 300 x 400 canvas and scaled to fit.
class PortraitPainter extends CustomPainter {
  PortraitPainter(this.progress, {this.stamp});
  final Progress progress;
  final String? stamp;

  static const _night = Color(0xFF0A0D12);
  static const _wall = Color(0xFF1A1F26);
  static const _windowCold = Color(0xFF41606F);
  static const _rim = Color(0xFF9FBACB);
  static const _neon = Color(0xFFB3262B);
  static const _coat = Color(0xFF2A241F);
  static const _coatLit = Color(0xFF4A4038);
  static const _hat = Color(0xFF15110F);
  static const _skinShadow = Color(0xFF241915);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final s = math.min(size.width / 300, size.height / 400);
    canvas.translate((size.width - 300 * s) / 2, (size.height - 400 * s) / 2);
    canvas.scale(s);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 300, 400));
    final rnd = math.Random(312);
    _room(canvas, rnd);
    _figure(canvas, rnd);
    _smoke(canvas);
    _finish(canvas, rnd);
    if (progress.done && stamp != null) _stamp(canvas, stamp!);
    canvas.restore();
  }

  /// Short semi-transparent strokes inside [region]: the painted texture.
  void _brush(Canvas c, Path region, math.Random rnd,
      {required Color color, Color? light, int count = 260, double len = 10, double width = 3, double angle = -1.2, double jitter = .5, double alpha = .18}) {
    c.save();
    c.clipPath(region);
    final b = region.getBounds();
    final p = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width;
    for (var i = 0; i < count; i++) {
      final x = b.left + rnd.nextDouble() * b.width;
      final y = b.top + rnd.nextDouble() * b.height;
      final a = angle + (rnd.nextDouble() - .5) * jitter;
      final l = len * (.5 + rnd.nextDouble());
      final shade = (rnd.nextDouble() - .5) * .25;
      p.color = Color.lerp(color, shade > 0 ? (light ?? color) : Colors.black, shade.abs() * 2)!
          .withValues(alpha: alpha * (.5 + rnd.nextDouble()));
      c.drawLine(Offset(x, y), Offset(x + math.cos(a) * l, y + math.sin(a) * l), p);
    }
    c.restore();
  }

  void _room(Canvas c, math.Random rnd) {
    const full = Rect.fromLTWH(0, 0, 300, 400);
    c.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF1C2630), _wall, _night],
          stops: [0, .45, 1],
        ).createShader(full),
    );
    _brush(c, Path()..addRect(full), rnd, color: const Color(0xFF26303A), count: 500, len: 18, width: 5, angle: -1.45, alpha: .12);

    // Tall window on the right with rain and the neon sign beyond.
    final window = Path()..addRect(const Rect.fromLTWH(186, 22, 104, 300));
    c.drawPath(
      window,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2E4654), _windowCold, Color(0xFF22323C)],
        ).createShader(const Rect.fromLTWH(186, 22, 104, 300)),
    );
    // Neon glow and sign bars, blurred by the wet glass.
    c.drawCircle(const Offset(262, 120), 70,
        Paint()
          ..color = _neon.withValues(alpha: .35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));
    final bar = Paint()
      ..color = const Color(0xFFE0484A)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    for (var i = 0; i < 4; i++) {
      c.drawLine(Offset(250, 70.0 + i * 26), Offset(272, 70.0 + i * 26), bar);
    }
    c.drawLine(const Offset(261, 60), const Offset(261, 170), bar..strokeWidth = 3);
    _brush(c, window, rnd, color: const Color(0xFF6E8C9C), count: 220, len: 14, width: 2, angle: 1.5, jitter: .15, alpha: .2);
    // Rain running down the glass.
    final rain = Paint()
      ..strokeWidth = 1
      ..color = const Color(0x66C8DCE6);
    for (var i = 0; i < 70; i++) {
      final x = 188 + rnd.nextDouble() * 100, y = 24 + rnd.nextDouble() * 290;
      c.drawLine(Offset(x, y), Offset(x - .8, y + 6 + rnd.nextDouble() * 14), rain);
    }
    // Mullions and the dark frame.
    final frame = Paint()
      ..color = const Color(0xFF0B0E12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    c.drawRect(const Rect.fromLTWH(186, 22, 104, 300), frame);
    c.drawLine(const Offset(238, 22), const Offset(238, 322), frame..strokeWidth = 5);
    c.drawLine(const Offset(186, 160), const Offset(290, 160), frame);
    // Window light falling into the room.
    c.drawPath(
      Path()
        ..moveTo(186, 22)
        ..lineTo(186, 322)
        ..lineTo(40, 400)
        ..lineTo(0, 400)
        ..lineTo(0, 300)
        ..close(),
      Paint()
        ..shader = const LinearGradient(colors: [Color(0x1441606F), Color(0x0041606F)])
            .createShader(const Rect.fromLTWH(0, 22, 186, 378)),
    );
  }

  void _figure(Canvas c, math.Random rnd) {
    // Coat and shoulders, three-quarter view, turned toward the window.
    final coat = Path()
      ..moveTo(34, 400)
      ..cubicTo(36, 336, 52, 290, 96, 268)
      ..cubicTo(114, 258, 124, 246, 130, 226)
      ..lineTo(168, 228)
      ..cubicTo(176, 246, 192, 258, 214, 268)
      ..cubicTo(240, 282, 250, 334, 252, 400)
      ..close();
    c.drawPath(coat, Paint()..color = _coat);
    _brush(c, coat, rnd, color: _coat, light: _coatLit, count: 360, len: 18, width: 5, angle: 1.35, jitter: .3, alpha: .35);
    // Folds.
    final fold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0x66080605)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    c.drawPath(Path()..moveTo(96, 300)..cubicTo(90, 330, 92, 370, 88, 400), fold);
    c.drawPath(Path()..moveTo(214, 300)..cubicTo(220, 340, 218, 372, 222, 400), fold);
    // Thin cold rim light on the window-side shoulder and sleeve.
    c.drawPath(
      Path()
        ..moveTo(168, 230)
        ..cubicTo(176, 248, 192, 260, 214, 270)
        ..cubicTo(238, 284, 248, 334, 250, 400),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = _rim.withValues(alpha: .55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
    // Warm neon spill on the coat front.
    c.drawCircle(const Offset(200, 330), 60,
        Paint()
          ..color = _neon.withValues(alpha: .14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25));

    // Neck, drawn under the head and collar.
    c.drawPath(
        Path()
          ..moveTo(136, 196)
          ..lineTo(164, 208)
          ..lineTo(160, 246)
          ..lineTo(134, 242)
          ..close(),
        Paint()..color = const Color(0xFF1E1512));
    // Shirt and tie in deep shadow.
    c.drawPath(Path()..moveTo(138, 238)..lineTo(160, 240)..lineTo(150, 300)..close(), Paint()..color = const Color(0xFF4E4943));
    c.drawPath(Path()..moveTo(146, 242)..lineTo(153, 242)..lineTo(154, 294)..lineTo(149, 298)..close(),
        Paint()..color = const Color(0xFF3E1113));
    // Turned-up collar and lapels.
    final collarL = Path()
      ..moveTo(122, 200)
      ..lineTo(128, 266)
      ..lineTo(148, 302)
      ..lineTo(138, 240)
      ..close();
    final collarR = Path()
      ..moveTo(174, 210)
      ..lineTo(170, 262)
      ..lineTo(150, 302)
      ..lineTo(160, 240)
      ..close();
    c.drawPath(collarL, Paint()..color = const Color(0xFF1D1916));
    c.drawPath(collarR, Paint()..color = const Color(0xFF36302A));
    c.drawLine(const Offset(174, 210), const Offset(170, 262),
        Paint()
          ..color = _rim.withValues(alpha: .55)
          ..strokeWidth = 1.4);

    // Head, three-quarter profile facing the window: back of the skull on
    // the left, an ear, the face turned right and almost all in shadow.
    final head = Path()
      ..moveTo(124, 146)
      ..cubicTo(118, 164, 120, 186, 130, 198)
      ..cubicTo(140, 210, 154, 216, 164, 216)
      ..lineTo(170, 212)
      ..lineTo(174, 202)
      ..lineTo(178, 196)
      ..lineTo(176, 188)
      ..lineTo(181, 180)
      ..lineTo(177, 170)
      ..cubicTo(178, 160, 176, 150, 172, 144)
      ..close();
    c.drawPath(head, Paint()..color = _skinShadow);
    _brush(c, head, rnd, color: _skinShadow, light: const Color(0xFF4A3328), count: 120, len: 6, width: 2.5, angle: 1.4, alpha: .4);
    // Ear.
    c.drawOval(const Rect.fromLTWH(132, 166, 9, 16), Paint()..color = const Color(0xFF2E201A));
    // Cold rim light along brow, nose, lips and jaw.
    final rimPath = Path()
      ..moveTo(174, 156)
      ..lineTo(177, 170)
      ..lineTo(181, 180)
      ..lineTo(176, 188)
      ..lineTo(178, 196)
      ..lineTo(174, 202)
      ..lineTo(170, 212)
      ..cubicTo(164, 217, 156, 217, 148, 212);
    c.drawPath(
        rimPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeJoin = StrokeJoin.round
          ..color = _rim.withValues(alpha: .8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .7));
    // Faint warm fill on the cheek from the neon.
    c.drawCircle(const Offset(160, 192), 14,
        Paint()
          ..color = const Color(0xFF8A3A2E).withValues(alpha: .22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    // Cigarette with ember.
    c.drawLine(const Offset(175, 199), const Offset(193, 197),
        Paint()
          ..color = const Color(0xFFCFC6B8)
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round);
    c.drawCircle(const Offset(194, 197), 2, Paint()..color = const Color(0xFFFF8A3D));
    c.drawCircle(const Offset(194, 197), 6,
        Paint()
          ..color = const Color(0x66FF6A2D)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

    // Fedora: pinched crown, band, wide brim snapped down in front.
    final crown = Path()
      ..moveTo(120, 142)
      ..cubicTo(118, 124, 120, 110, 126, 102)
      ..cubicTo(136, 96, 146, 102, 152, 100)
      ..cubicTo(160, 96, 172, 96, 178, 104)
      ..cubicTo(182, 114, 184, 128, 184, 140)
      ..close();
    c.drawPath(crown, Paint()..color = _hat);
    _brush(c, crown, rnd, color: _hat, light: const Color(0xFF3A302A), count: 90, len: 8, width: 2.5, angle: .15, alpha: .5);
    // Band.
    c.drawPath(Path()..moveTo(120, 132)..cubicTo(140, 128, 166, 128, 184, 130)..lineTo(184, 140)..cubicTo(160, 138, 140, 140, 120, 142)..close(),
        Paint()..color = const Color(0xFF080606));
    final brim = Path()
      ..moveTo(96, 150)
      ..cubicTo(118, 136, 170, 132, 200, 142)
      ..cubicTo(210, 146, 208, 154, 198, 156)
      ..cubicTo(176, 150, 136, 150, 106, 160)
      ..cubicTo(94, 162, 90, 156, 96, 150)
      ..close();
    c.drawPath(brim, Paint()..color = const Color(0xFF0E0B09));
    // Rim light on the crown edge and brim.
    c.drawPath(
        Path()
          ..moveTo(176, 102)
          ..cubicTo(181, 112, 183, 124, 184, 138),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = _rim.withValues(alpha: .6));
    c.drawPath(
        Path()
          ..moveTo(178, 137)
          ..cubicTo(190, 139, 202, 142, 206, 149),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = _rim.withValues(alpha: .75));
    // Brim shadow across the eyes.
    c.drawPath(
      Path()
        ..moveTo(124, 152)
        ..cubicTo(140, 154, 164, 154, 178, 158)
        ..lineTo(177, 174)
        ..cubicTo(160, 172, 140, 172, 122, 170)
        ..close(),
      Paint()
        ..color = const Color(0xDD050404)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  void _smoke(Canvas c) {
    final smoke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final curls = [
      (Path()
        ..moveTo(195, 194)
        ..cubicTo(206, 170, 190, 150, 204, 120)
        ..cubicTo(214, 98, 200, 80, 212, 54), 9.0, .28),
      (Path()
        ..moveTo(196, 193)
        ..cubicTo(214, 176, 220, 150, 212, 130)
        ..cubicTo(206, 112, 222, 96, 230, 70), 5.0, .2),
    ];
    for (final (path, w, a) in curls) {
      c.drawPath(path, smoke
        ..strokeWidth = w
        ..color = Colors.white.withValues(alpha: a));
    }
  }

  void _finish(Canvas c, math.Random rnd) {
    const full = Rect.fromLTWH(0, 0, 300, 400);
    // Film grain.
    final grain = Paint();
    for (var i = 0; i < 2600; i++) {
      grain.color = (rnd.nextBool() ? Colors.white : Colors.black).withValues(alpha: .04 + rnd.nextDouble() * .05);
      c.drawRect(Rect.fromLTWH(rnd.nextDouble() * 300, rnd.nextDouble() * 400, 1.2, 1.2), grain);
    }
    // Vignette.
    c.drawRect(
      full,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(.15, -.15),
          radius: .95,
          colors: [Color(0x00000000), Color(0x00000000), Color(0xCC000000)],
          stops: [0, .55, 1],
        ).createShader(full),
    );
  }

  void _stamp(Canvas c, String text) {
    c.save();
    c.translate(150, 366);
    c.rotate(-4 * math.pi / 180);
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 196, height: 34), const Radius.circular(3));
    c.drawRRect(
        r,
        Paint()
          ..color = const Color(0xCCB3262B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Color(0xDDCF3A3A), fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 3),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 190);
    tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
    c.restore();
  }

  @override
  bool shouldRepaint(PortraitPainter old) => old.progress != progress || old.stamp != stamp;
}
