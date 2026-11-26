import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/story.dart';
import 'theme.dart';

/// Found items as evidence on the case file: a dark slot with a painted
/// object, like an adventure-game inventory.
class EvidenceTile extends StatelessWidget {
  const EvidenceTile({super.key, required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const RadialGradient(colors: [Color(0xFF2A2420), Color(0xFF120F0D)], radius: .9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF3A3029)),
              ),
              child: CustomPaint(painter: EvidenceIconPainter(item.id)),
            ),
          ),
          const SizedBox(height: 6),
          Text(item.name, style: const TextStyle(color: Noir.paper, fontWeight: FontWeight.w600, fontSize: 14)),
          Text(item.desc, style: const TextStyle(color: Noir.dim, fontSize: 12)),
        ]),
      );
}

/// Draws one evidence object on a 120 x 90 canvas, scaled to fit.
class EvidenceIconPainter extends CustomPainter {
  EvidenceIconPainter(this.id);
  final String id;

  static const _steel = Color(0xFF8C969C);
  static const _steelDark = Color(0xFF4E565B);
  static const _brass = Color(0xFFB08A3E);
  static const _leather = Color(0xFF3B2A20);
  static const _paper = Color(0xFFD9CDB4);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 120, size.height / 90);
    canvas.save();
    canvas.translate((size.width - 120 * s) / 2, (size.height - 90 * s) / 2);
    canvas.scale(s);
    // Soft pool of desk-lamp light under the object.
    canvas.drawOval(const Rect.fromLTWH(18, 58, 84, 18),
        Paint()
          ..color = Colors.black.withValues(alpha: .5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    switch (id) {
      case 'revolver':
        _revolver(canvas);
      case 'key7':
        _key(canvas);
      case 'notebook':
        _notebook(canvas);
      case 'page':
        _page(canvas);
      default:
        _tag(canvas);
    }
    canvas.restore();
  }

  void _revolver(Canvas c) {
    c.save();
    c.translate(60, 45);
    c.rotate(-.12);
    final barrel = Path()..addRRect(RRect.fromLTRBR(-6, -14, 46, -5, const Radius.circular(1.5)));
    c.drawPath(barrel, Paint()..color = _steel);
    c.drawLine(const Offset(-4, -13), const Offset(44, -13), Paint()..color = Colors.white.withValues(alpha: .5)..strokeWidth = 1);
    c.drawRRect(RRect.fromLTRBR(-18, -16, 2, 4, const Radius.circular(4)), Paint()..color = _steelDark);
    c.drawCircle(const Offset(-8, -6), 7, Paint()..color = _steel);
    for (var i = 0; i < 3; i++) {
      c.drawLine(Offset(-13.0 + i * 5, -12), Offset(-13.0 + i * 5, 0), Paint()..color = _steelDark..strokeWidth = 1);
    }
    final grip = Path()
      ..moveTo(-18, -2)
      ..cubicTo(-26, 8, -30, 22, -26, 30)
      ..lineTo(-14, 30)
      ..cubicTo(-14, 20, -10, 10, -4, 4)
      ..close();
    c.drawPath(grip, Paint()..color = const Color(0xFF4A3424));
    c.drawPath(Path()..moveTo(-4, 4)..quadraticBezierTo(2, 14, -6, 14), Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = _steelDark);
    c.restore();
  }

  void _key(Canvas c) {
    final brass = Paint()
      ..color = _brass
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    c.drawCircle(const Offset(36, 45), 12, brass);
    c.drawLine(const Offset(48, 45), const Offset(92, 45), brass);
    c.drawLine(const Offset(82, 45), const Offset(82, 56), brass);
    c.drawLine(const Offset(90, 45), const Offset(90, 54), brass);
    // Paper tag with the locker number.
    c.drawLine(const Offset(30, 36), const Offset(22, 22), Paint()..color = const Color(0xFF6B5A44)..strokeWidth = 1);
    c.save();
    c.translate(12, 10);
    c.rotate(-.25);
    c.drawRRect(RRect.fromLTRBR(0, 0, 18, 12, const Radius.circular(2)), Paint()..color = _paper);
    final tp = TextPainter(
      text: const TextSpan(text: '7', style: TextStyle(color: Color(0xFF3A2C20), fontSize: 9, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(9 - tp.width / 2, 6 - tp.height / 2));
    c.restore();
  }

  void _notebook(Canvas c) {
    c.save();
    c.translate(60, 45);
    c.rotate(.08);
    c.drawRRect(RRect.fromLTRBR(-30, -24, 30, 24, const Radius.circular(3)), Paint()..color = _leather);
    c.drawRect(const Rect.fromLTRB(26, -22, 30, 22), Paint()..color = const Color(0xFFCFC3AA));
    c.drawLine(const Offset(-30, 8), const Offset(30, 8), Paint()..color = const Color(0xFF1A120D)..strokeWidth = 2.5);
    c.drawRect(const Rect.fromLTRB(-22, -16, 10, -8), Paint()..color = _brass.withValues(alpha: .5));
    c.restore();
  }

  void _page(Canvas c) {
    final page = Path()
      ..moveTo(34, 14)
      ..lineTo(86, 12)
      ..lineTo(88, 50)
      ..cubicTo(80, 58, 74, 52, 68, 62)
      ..cubicTo(60, 70, 50, 60, 40, 72)
      ..lineTo(32, 70)
      ..close();
    c.drawPath(page, Paint()..color = _paper);
    final type = Paint()
      ..color = const Color(0xFF4A4038)
      ..strokeWidth = 1.4;
    for (var i = 0; i < 6; i++) {
      c.drawLine(Offset(40, 22.0 + i * 6), Offset(i.isEven ? 80 : 72, 22.0 + i * 6), type);
    }
    // Scorched edge.
    c.drawPath(
        Path()
          ..moveTo(88, 50)
          ..cubicTo(80, 58, 74, 52, 68, 62)
          ..cubicTo(60, 70, 50, 60, 40, 72),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = const Color(0xCC1A0E08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  }

  void _tag(Canvas c) {
    c.drawRRect(RRect.fromLTRBR(36, 26, 84, 64, const Radius.circular(4)), Paint()..color = _paper);
    c.drawCircle(const Offset(44, 34), 3, Paint()..color = const Color(0xFF1A140F));
  }

  @override
  bool shouldRepaint(EvidenceIconPainter old) => old.id != id;
}
