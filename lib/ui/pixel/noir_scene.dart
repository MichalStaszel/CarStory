import 'dart:math' as math;
import 'dart:typed_data';

/// Pixel-art scene for "Room 312": the protagonist under a streetlamp in
/// the rain outside the Hotel Victoria, a 1930s sedan at the curb, the
/// street receding into the night. Pure Dart software renderer: it paints
/// a small frame buffer, reflects it in the wet street, dithers it to a
/// limited palette and animates rain, neon flicker, puddle ripples, the
/// cigarette ember and the taillights. Original art.
///
/// [render] returns RGBA bytes for one frame of a seamless loop.
class NoirScene {
  NoirScene({this.dawn = false, this.width = 160, this.height = 224, this.frames = 48}) {
    _buildStatic();
  }

  /// The case is closed: the rain thins, the lamps fade, dawn comes up.
  final bool dawn;
  final int width;
  final int height;

  /// Frames per loop (12 fps → 4 s).
  final int frames;

  static const horizon = 138; // where the street meets the buildings
  static const figFeet = 186;
  static const carGround = 176;
  static const lampX = 122;
  static const lampY = 46;

  late final Float32List _base; // static background, rgb
  late final Uint8List _wet; // 0..255 wetness / puddle map
  late final List<_Drop> _drops;
  late final List<_Ripple> _ripples;
  late final Uint8List _figMask;
  late final Uint8List _carMask;
  late final Float32List _carRgb;

  int get _n => width * height;

  // ---------------------------------------------------------------- palette
  late final List<int> _palette = dawn ? _dawnPalette : _nightPalette;

  static const _nightPalette = [
    0x020306, 0x05070D, 0x090D16, 0x0E1420, 0x141C2B, 0x1B2638, 0x243248, 0x2F405A, 0x3E5370, 0x52698A, //
    0x6B84A3, 0x8DA3BD, 0xB4C4D6, 0xDDE6EE, //
    0x120A10, 0x2A0D14, 0x4D1019, 0x7E1420, 0xB71C25, 0xEE3B3B, 0xFF7A6B, //
    0x2A1E12, 0x55391C, 0x8F6128, 0xC99541, 0xF0C674, 0xFFE9B0, //
    0x1A1428, 0x2D2140, 0x46305A, //
    0x0B1412, 0x14231F,
  ];
  static const _dawnPalette = [
    0x05040A, 0x0C0A16, 0x161226, 0x221A36, 0x302246, 0x432C56, 0x5A3864, 0x744570, 0x925477, 0xB4667A, //
    0xD4807C, 0xEEA483, 0xF7C79A, 0xFDE6C4, //
    0x120A10, 0x2A0D14, 0x4D1019, 0x7E1420, 0xB71C25, 0xEE3B3B, 0xFF7A6B, //
    0x2A1E12, 0x55391C, 0x8F6128, 0xC99541, 0xF0C674, 0xFFE9B0, //
    0x1B2638, 0x2F405A, 0x52698A, //
    0x0E1420, 0x243248,
  ];

  // ------------------------------------------------------------- helpers
  static double _r(int c) => ((c >> 16) & 255) / 255;
  static double _g(int c) => ((c >> 8) & 255) / 255;
  static double _b(int c) => (c & 255) / 255;

  void _set(Float32List buf, int x, int y, int c, [double a = 1]) {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    final i = (y * width + x) * 3;
    buf[i] += (_r(c) - buf[i]) * a;
    buf[i + 1] += (_g(c) - buf[i + 1]) * a;
    buf[i + 2] += (_b(c) - buf[i + 2]) * a;
  }

  void _add(Float32List buf, int x, int y, int c, double a) {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    final i = (y * width + x) * 3;
    buf[i] += _r(c) * a;
    buf[i + 1] += _g(c) * a;
    buf[i + 2] += _b(c) * a;
  }

  void _rect(Float32List buf, int x0, int y0, int x1, int y1, int c, [double a = 1]) {
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        _set(buf, x, y, c, a);
      }
    }
  }

  void _glow(Float32List buf, double cx, double cy, double rad, int c, double strength, {double squashY = 1}) {
    final x0 = (cx - rad).floor(), x1 = (cx + rad).ceil();
    final y0 = (cy - rad * squashY).floor(), y1 = (cy + rad * squashY).ceil();
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final dx = (x - cx) / rad, dy = (y - cy) / (rad * squashY);
        final d = math.sqrt(dx * dx + dy * dy);
        if (d >= 1) continue;
        final f = (1 - d) * (1 - d);
        _add(buf, x, y, c, f * strength);
      }
    }
  }

  bool _inPoly(List<double> p, double x, double y) {
    var inside = false;
    for (var i = 0, j = p.length - 2; i < p.length; j = i, i += 2) {
      final xi = p[i], yi = p[i + 1], xj = p[j], yj = p[j + 1];
      if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) inside = !inside;
    }
    return inside;
  }

  void _poly(Float32List buf, List<double> p, int c, {Uint8List? mask, double a = 1}) {
    var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
    for (var i = 0; i < p.length; i += 2) {
      minX = math.min(minX, p[i]);
      maxX = math.max(maxX, p[i]);
      minY = math.min(minY, p[i + 1]);
      maxY = math.max(maxY, p[i + 1]);
    }
    for (var y = minY.floor(); y <= maxY.ceil(); y++) {
      for (var x = minX.floor(); x <= maxX.ceil(); x++) {
        if (x < 0 || y < 0 || x >= width || y >= height) continue;
        if (!_inPoly(p, x + .5, y + .5)) continue;
        _set(buf, x, y, c, a);
        if (mask != null) mask[y * width + x] = 1;
      }
    }
  }

  // Tiny 3x5 font for the neon sign.
  static const _font = {
    'H': [0x5, 0x5, 0x7, 0x5, 0x5],
    'O': [0x7, 0x5, 0x5, 0x5, 0x7],
    'T': [0x7, 0x2, 0x2, 0x2, 0x2],
    'E': [0x7, 0x4, 0x6, 0x4, 0x7],
    'L': [0x4, 0x4, 0x4, 0x4, 0x7],
  };

  // ------------------------------------------------------------ static
  void _buildStatic() {
    final rnd = math.Random(312);
    final buf = Float32List(_n * 3);

    // Sky.
    for (var y = 0; y < horizon; y++) {
      final t = y / horizon;
      final top = dawn ? 0x161226 : 0x04060B;
      final mid = dawn ? 0x5A3864 : 0x0E1522;
      final low = dawn ? 0xD4807C : 0x2A2240;
      final c0 = t < .6 ? top : mid, c1 = t < .6 ? mid : low;
      final k = t < .6 ? t / .6 : (t - .6) / .4;
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 3;
        buf[i] = _r(c0) + (_r(c1) - _r(c0)) * k;
        buf[i + 1] = _g(c0) + (_g(c1) - _g(c0)) * k;
        buf[i + 2] = _b(c0) + (_b(c1) - _b(c0)) * k;
      }
    }
    // Low cloud bands.
    for (var band = 0; band < 5; band++) {
      final by = 10 + band * 14 + rnd.nextInt(6);
      for (var x = 0; x < width; x++) {
        final h = 2 + (math.sin(x * .07 + band) * 2).round();
        for (var y = by; y < by + h; y++) {
          _set(buf, x, y, dawn ? 0x744570 : 0x141C2B, .35);
        }
      }
    }

    // Distant skyline toward the vanishing point.
    var x = 58;
    while (x < width) {
      final w = 6 + rnd.nextInt(12);
      final top = horizon - 18 - rnd.nextInt(50);
      _rect(buf, x, top, x + w, horizon, dawn ? 0x221A36 : 0x090D16);
      for (var wy = top + 3; wy < horizon - 3; wy += 4) {
        for (var wx = x + 2; wx < x + w - 1; wx += 3) {
          if (rnd.nextDouble() < .12) _set(buf, wx, wy, rnd.nextBool() ? 0xC99541 : 0x52698A, .7);
        }
      }
      x += w + rnd.nextInt(3);
    }
    // Haze where the city glows.
    for (var y = horizon - 40; y < horizon; y++) {
      final t = (y - (horizon - 40)) / 40;
      for (var x = 0; x < width; x++) {
        _set(buf, x, y, dawn ? 0xEEA483 : 0x2D2140, t * .35);
      }
    }

    // Hotel Victoria facade, left.
    _rect(buf, 0, 6, 56, horizon + 10, dawn ? 0x161226 : 0x0B0F18);
    for (var y = 6; y < horizon + 10; y += 3) {
      for (var x = 0; x < 56; x++) {
        if ((x + (y ~/ 3) * 2) % 6 == 0) _set(buf, x, y, 0x000000, .25); // brick hint
      }
    }
    for (var wy = 14; wy < 112; wy += 14) {
      for (var wx = 4; wx < 50; wx += 11) {
        final lit = rnd.nextDouble() < .3;
        _rect(buf, wx, wy, wx + 6, wy + 9, lit ? 0x8F6128 : 0x05070D);
        if (lit) {
          _rect(buf, wx + 1, wy + 1, wx + 5, wy + 8, 0xC99541, .8);
          _rect(buf, wx + 3, wy + 1, wx + 4, wy + 8, 0x55391C); // curtain gap
        }
        _rect(buf, wx - 1, wy + 9, wx + 7, wy + 10, 0x1B2638); // sill
      }
    }
    // Canopy and the warm doorway.
    _rect(buf, 14, 116, 58, 121, 0x4D1019);
    _rect(buf, 14, 121, 58, 122, 0x120A10);
    _rect(buf, 26, 122, 44, horizon + 6, 0x55391C);
    _rect(buf, 28, 124, 42, horizon + 6, 0xC99541, .7);
    _glow(buf, 35, horizon + 2, 26, 0xC99541, .35, squashY: .5);

    // Street lamps receding on the right (the near one is drawn per frame
    // too, for its flicker).
    for (var k = 0; k < 5; k++) {
      final t = k / 5;
      final lx = (lampX + (96 - lampX) * (t + .2)).round();
      final top = (lampY + (horizon - 26 - lampY) * (t + .2)).round();
      final base = (figFeet + (horizon - figFeet) * (t + .2)).round();
      if (k == 0) continue;
      _rect(buf, lx, top, lx + 1, base, 0x05070D);
      _set(buf, lx - 1, top, dawn ? 0x925477 : 0xF0C674);
      _set(buf, lx, top, dawn ? 0x925477 : 0xFFE9B0);
      _glow(buf, lx + .5, top + .5, 10 - k * 1.2, dawn ? 0x744570 : 0xC99541, dawn ? .15 : .45);
    }

    // Ground: sidewalk on the left, street toward the vanishing point.
    for (var y = horizon; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final t = (y - horizon) / (height - horizon);
        final curb = 56 - (t * 60); // curb line runs out of frame
        final c = x < curb ? (dawn ? 0x221A36 : 0x0E1420) : (dawn ? 0x161226 : 0x090D16);
        _set(buf, x, y, c);
      }
    }
    // Centre line dashes in perspective.
    for (var y = horizon + 2; y < height; y += 1) {
      final t = (y - horizon) / (height - horizon);
      if (((t * t) * 30).floor().isEven) continue;
      final cx = (96 + (150 - 96) * t).round();
      _set(buf, cx, y, 0x52698A, .25);
    }

    _base = buf;

    // Wet map: puddles reflect strongly, the rest a little.
    _wet = Uint8List(_n);
    final puddles = [for (var i = 0; i < 9; i++) (rnd.nextDouble() * width, horizon + 6 + rnd.nextDouble() * (height - horizon - 6), 8 + rnd.nextDouble() * 22)];
    for (var y = horizon; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var w = .35;
        for (final (px, py, pr) in puddles) {
          final dx = (x - px) / pr, dy = (y - py) / (pr * .35);
          final d = dx * dx + dy * dy;
          if (d < 1) w = math.max(w, .95 - d * .2);
        }
        _wet[y * width + x] = (w * 255).round();
      }
    }

    // The figure: centred, trench coat and fedora, face lost in shadow.
    _figMask = Uint8List(_n);
    final fig = Float32List(_n * 3);
    const fx = 80.0;
    // Coat: sloped shoulders, belted waist, hem flaring in the wind.
    _poly(fig, [fx - 4, 121, fx - 9, 125, fx - 10, 132, fx - 9, 150, fx - 12, 177, fx - 6, 179, fx + 7, 179, fx + 13, 176, fx + 9, 150, fx + 10, 132, fx + 9, 125, fx + 4, 121], 0x070A10, mask: _figMask);
    // Arms hanging, a sliver of night between arm and coat on the lamp side.
    _poly(fig, [fx + 9, 126, fx + 12, 134, fx + 12, 152, fx + 10, 154, fx + 9, 136], 0x070A10, mask: _figMask);
    _poly(fig, [fx - 9, 126, fx - 12, 134, fx - 12, 152, fx - 10, 154, fx - 9, 136], 0x070A10, mask: _figMask);
    // Legs and shoes.
    _poly(fig, [fx - 5, 178, fx - 5, figFeet + 0.0, fx - 1, figFeet + 0.0, fx - 1, 178], 0x040507, mask: _figMask);
    _poly(fig, [fx + 1, 178, fx + 1, figFeet + 0.0, fx + 5, figFeet + 0.0, fx + 5, 178], 0x040507, mask: _figMask);
    // Head in full shadow, turned up collar.
    _poly(fig, [fx - 4, 122, fx - 4, 113, fx - 3, 110, fx + 3, 110, fx + 4, 113, fx + 4, 122], 0x030305, mask: _figMask);
    _poly(fig, [fx - 6, 124, fx - 5, 117, fx - 3, 121, fx + 3, 121, fx + 5, 117, fx + 6, 124], 0x070A10, mask: _figMask);
    // Fedora with a wide brim.
    _poly(fig, [fx - 10, 112.5, fx - 4, 110, fx - 4, 104.5, fx - 2, 103, fx + 3, 103, fx + 4.5, 104.5, fx + 4.5, 110, fx + 10, 112, fx + 8, 113.5, fx - 8, 113.5], 0x040507, mask: _figMask);
    // Lamp-side fabric catches a little light (dithered later).
    for (var y = 124; y < 179; y++) {
      for (var x = (fx + 4).round(); x < fx + 14; x++) {
        if (_figMask[y * width + x] == 1 && (x + y) % 2 == 0) _set(fig, x, y, 0x1B2638, .5);
      }
    }
    // Belt.
    for (var x = (fx - 9).round(); x <= fx + 9; x++) {
      _set(fig, x, 150, 0x020203);
    }
    _figRgb = fig;

    // The car: a long-hooded 1930s sedan seen from the rear three-quarter.
    _carMask = Uint8List(_n);
    final car = Float32List(_n * 3);
    const cx0 = 98.0, gy = carGround * 1.0;
    _poly(car, [cx0, gy - 4, cx0 + 2, gy - 14, cx0 + 8, gy - 17, cx0 + 50, gy - 15, cx0 + 60, gy - 8, cx0 + 61, gy - 3, cx0 + 58, gy - 2, cx0 + 4, gy - 2], 0x0E1420, mask: _carMask); // body
    _poly(car, [cx0 + 8, gy - 17, cx0 + 12, gy - 27, cx0 + 34, gy - 28, cx0 + 40, gy - 17], 0x0B1018, mask: _carMask); // cabin
    _poly(car, [cx0 + 13, gy - 25, cx0 + 15, gy - 18, cx0 + 24, gy - 18, cx0 + 24, gy - 26], 0x1B2638, mask: _carMask); // rear window
    _poly(car, [cx0 + 26, gy - 26, cx0 + 26, gy - 18, cx0 + 37, gy - 18, cx0 + 33, gy - 26], 0x243248, mask: _carMask); // side window
    _poly(car, [cx0 - 2, gy - 12, cx0 + 3, gy - 16, cx0 + 6, gy - 12, cx0 + 5, gy - 4, cx0 - 1, gy - 4], 0x090D16, mask: _carMask); // spare wheel
    // Wheels.
    for (final wx in [cx0 + 12, cx0 + 50]) {
      for (var y = -6; y <= 0; y++) {
        for (var x = -5; x <= 5; x++) {
          if (x * x + (y + 3) * (y + 3) * 2.5 <= 26) {
            final px = (wx + x).round(), py = (gy + y).round();
            _set(car, px, py, 0x020306);
            if (px >= 0 && py >= 0 && px < width && py < height) _carMask[py * width + px] = 1;
          }
        }
      }
    }
    // Chrome and lamp-lit edges on the roof and fenders.
    for (var x = (cx0 + 12).round(); x < cx0 + 34; x++) {
      _set(car, x, (gy - 28).round(), 0x6B84A3, .8);
    }
    for (var x = (cx0 + 40).round(); x < cx0 + 58; x++) {
      _set(car, x, (gy - 15 + (x - cx0 - 40) * .35).round(), 0x52698A, .7);
    }
    _rect(car, (cx0 + 4).round(), (gy - 7).round(), (cx0 + 56).round(), (gy - 6).round(), 0x3E5370, .6); // running board
    _carRgb = car;

    // Rain: a seamless loop, every drop travels whole screens per loop.
    _drops = [
      for (var i = 0; i < (dawn ? 90 : 190); i++)
        _Drop(
          x: rnd.nextDouble() * (width + 20) - 10,
          y: rnd.nextDouble() * height,
          speed: (rnd.nextBool() ? 2 : 3) * height / frames,
          len: 2 + rnd.nextInt(4),
          near: rnd.nextDouble() < .2,
        ),
    ];
    _ripples = [
      for (var i = 0; i < 26; i++)
        _Ripple(
          x: rnd.nextDouble() * width,
          y: horizon + 4 + rnd.nextDouble() * (height - horizon - 4),
          phase: rnd.nextInt(frames),
        ),
    ];
  }

  late final Float32List _figRgb;

  // ------------------------------------------------------------- frame
  Uint8List render(int frame) {
    final f = frame % frames;
    final tau = f / frames * 2 * math.pi;
    final buf = Float32List.fromList(_base);

    // Neon sign: mostly steady, with a stutter twice per loop.
    final neonOn = !dawn && !{7, 9, 30, 31, 33}.contains(f);
    final neonC = neonOn ? 0xFF3B3B : 0x4D1019;
    _rect(buf, 49, 30, 57, 98, 0x05070D);
    var ly = 33;
    for (final ch in 'HOTEL'.split('')) {
      final rows = _font[ch]!;
      for (var r = 0; r < 5; r++) {
        for (var b = 0; b < 3; b++) {
          if (rows[r] & (4 >> b) != 0) {
            _set(buf, 51 + b * 2, ly + r * 2, neonC);
            _set(buf, 51 + b * 2, ly + r * 2 + 1, neonC, .8);
          }
        }
      }
      ly += 13;
    }
    if (neonOn) _glow(buf, 53, 64, 30, 0xB71C25, .55, squashY: 1.6);

    // Near street lamp with its pool of light, a soft flicker.
    final lampK = dawn ? .15 : (.85 + .15 * math.sin(tau * 3).abs());
    _rect(buf, lampX, lampY, lampX + 2, figFeet + 6, 0x020306);
    _rect(buf, lampX - 6, lampY - 2, lampX + 2, lampY, 0x05070D);
    _rect(buf, lampX - 7, lampY, lampX - 2, lampY + 2, dawn ? 0x925477 : 0xFFE9B0, lampK);
    _glow(buf, lampX - 4.5, lampY + 1, 26, dawn ? 0x744570 : 0xF0C674, .7 * lampK);
    // Cone of light falling on the figure and the street.
    for (var y = lampY + 2; y < height; y++) {
      final t = (y - lampY) / (height - lampY);
      final half = 3 + t * 46;
      final cxl = lampX - 4.5 - t * 34;
      for (var x = (cxl - half).floor(); x <= (cxl + half).ceil(); x++) {
        final e = 1 - ((x - cxl).abs() / half);
        if (e <= 0) continue;
        _add(buf, x, y, dawn ? 0x744570 : 0xC99541, e * .09 * lampK * (1 - t * .5));
      }
    }

    // Pool of lamplight on the pavement behind the figure.
    _glow(buf, lampX - 34.0, figFeet + 1.0, 50, dawn ? 0x744570 : 0xF0C674, 1.1 * lampK, squashY: .25);

    // Reflections in the wet street: the scene above, mirrored about the
    // horizon, rippled and darkened; puddles mirror more.
    final ref = Float32List.fromList(buf);
    for (var y = horizon; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final w = _wet[y * width + x] / 255;
        final wob = (math.sin(y * .9 + tau * 2) * 1.2 * w).round();
        final sy = horizon - ((y - horizon) * 1.6).round() - 1;
        final sx = (x + wob).clamp(0, width - 1);
        if (sy < 0) continue;
        final si = (sy * width + sx) * 3, di = (y * width + x) * 3;
        final k = w * .55;
        buf[di] += ref[si] * k;
        buf[di + 1] += ref[si + 1] * k;
        buf[di + 2] += ref[si + 2] * k;
      }
    }

    // Long vertical streaks of the lights on wet asphalt.
    void streak(double x, int y0, int y1, int c, double a) {
      for (var y = y0; y < y1 && y < height; y++) {
        final fade = 1 - (y - y0) / (y1 - y0);
        final wob = (math.sin(y * .7 + tau * 2) * .9).round();
        _add(buf, x.round() + wob, y, c, a * fade);
        _add(buf, x.round() + wob + 1, y, c, a * fade * .5);
      }
    }
    streak(lampX - 4.5, figFeet - 6, height, dawn ? 0x925477 : 0xF0C674, 1.0 * lampK);
    if (neonOn) streak(53, horizon + 4, horizon + 60, 0xEE3B3B, .45);
    streak(35, horizon + 7, horizon + 40, 0xC99541, .35);

    // Car and figure reflections, then the objects themselves.
    _reflectLayer(buf, _carRgb, _carMask, carGround, tau, .7);
    _reflectLayer(buf, _figRgb, _figMask, figFeet, tau, .8);
    _drawLayer(buf, _carRgb, _carMask);
    // Taillights and their streaks on the wet asphalt.
    final tail = .8 + .2 * math.sin(tau);
    for (final (tx, ty) in [(99, carGround - 11), (103, carGround - 11)]) {
      _set(buf, tx, ty, 0xFF3B3B, tail);
      _set(buf, tx, ty + 1, 0xB71C25, tail);
      _glow(buf, tx + .5, ty + .5, 7, 0xEE3B3B, .5 * tail);
      for (var y = carGround + 1; y < math.min(height, carGround + 34); y++) {
        final fade = 1 - (y - carGround) / 34;
        _add(buf, tx + (math.sin(y * .8 + tau * 2) * 1).round(), y, 0xB71C25, .55 * fade * tail);
      }
    }
    _drawLayer(buf, _figRgb, _figMask);
    _rimLight(buf, _figMask, dawn ? 0x925477 : 0xF0C674, .75 * lampK);
    _rimLight(buf, _carMask, dawn ? 0x925477 : 0x8DA3BD, .5 * lampK);

    // Cigarette ember: a slow drag every loop.
    final drag = math.max(0.0, math.sin(tau));
    _set(buf, 84, 116, drag > .5 ? 0xFF7A6B : 0xB71C25, .6 + .4 * drag);
    _glow(buf, 84.5, 116.5, 3 + 2 * drag, 0xEE3B3B, .25 + .35 * drag);
    // Smoke drifting up.
    for (var k = 0; k < 14; k++) {
      final p = ((f / frames) + k / 14) % 1;
      final sx = 85 + math.sin(p * 9 + k) * 2.5 + p * 6;
      final sy = 115 - p * 28;
      _set(buf, sx.round(), sy.round(), 0x8DA3BD, .25 * (1 - p));
    }

    // Puddle ripples.
    for (final rp in _ripples) {
      final age = ((f - rp.phase) % frames) / 8;
      if (age > 1) continue;
      final rad = 1 + age * 4;
      for (var a = 0.0; a < 2 * math.pi; a += .35) {
        _add(buf, (rp.x + math.cos(a) * rad).round(), (rp.y + math.sin(a) * rad * .35).round(), 0x6B84A3, .35 * (1 - age));
      }
    }

    // Rain streaks: brighter inside the lamp's light.
    for (final d in _drops) {
      final y0 = (d.y + d.speed * f) % (height + 10) - 5;
      final x0 = d.x - (y0 * .12);
      final len = d.near ? d.len + 3 : d.len;
      for (var k = 0; k < len; k++) {
        final px = (x0 - k * .12).round(), py = (y0 - k).round();
        if (px < 0 || py < 0 || px >= width || py >= height) continue;
        final ct = (py - lampY) / (height - lampY);
        final inCone = py > lampY && (px - (lampX - 4.5 - ct * 34)).abs() < 3 + ct * 40;
        final lit = inCone ? .3 * (1 - ct * .6) : 0.0;
        _add(buf, px, py, lit > 0 && !dawn ? 0xF0C674 : 0x8DA3BD, (d.near ? .35 : .18) + lit);
      }
    }

    // Vignette.
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final dx = (x - width / 2) / (width * .66), dy = (y - height * .5) / (height * .75);
        final v = math.max(0.0, 1 - (dx * dx + dy * dy) * .9);
        final i = (y * width + x) * 3;
        buf[i] *= .35 + .65 * v;
        buf[i + 1] *= .35 + .65 * v;
        buf[i + 2] *= .35 + .65 * v;
      }
    }

    return _dither(buf);
  }

  void _drawLayer(Float32List buf, Float32List layer, Uint8List mask) {
    for (var i = 0; i < _n; i++) {
      if (mask[i] == 0) continue;
      buf[i * 3] = layer[i * 3];
      buf[i * 3 + 1] = layer[i * 3 + 1];
      buf[i * 3 + 2] = layer[i * 3 + 2];
    }
  }

  void _reflectLayer(Float32List buf, Float32List layer, Uint8List mask, int ground, double tau, double strength) {
    for (var y = 0; y < ground; y++) {
      for (var x = 0; x < width; x++) {
        if (mask[y * width + x] == 0) continue;
        final ry = ground + ((ground - y) * 1.1).round();
        if (ry >= height) continue;
        final rx = (x + math.sin(ry * .9 + tau * 2) * 1.1).round();
        if (rx < 0 || rx >= width) continue;
        final di = (ry * width + rx) * 3;
        final w = .5 + _wet[ry * width + rx] / 255 * .5;
        buf[di] *= 1 - strength * w;
        buf[di + 1] *= 1 - strength * w;
        buf[di + 2] *= 1 - strength * w;
      }
    }
  }

  /// Light the edge of a silhouette that faces the lamp (up and right).
  void _rimLight(Float32List buf, Uint8List mask, int c, double a) {
    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        if (mask[y * width + x] == 0) continue;
        final right = mask[y * width + x + 1] == 0;
        final up = mask[(y - 1) * width + x] == 0;
        if (!(right || up)) continue;
        // Only the side facing the lamp (right) and the tops of shoulders/hat.
        if (!right && (x < 80 || !up)) continue;
        _set(buf, x, y, c, a * (right ? 1 : .6));
      }
    }
  }

  // 4x4 Bayer ordered dither to the palette.
  static const _bayer = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];

  Uint8List _dither(Float32List buf) {
    final out = Uint8List(_n * 4);
    final pr = [for (final c in _palette) _r(c)];
    final pg = [for (final c in _palette) _g(c)];
    final pb = [for (final c in _palette) _b(c)];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = y * width + x;
        final t = (_bayer[(y & 3) * 4 + (x & 3)] / 16 - .5) * .09;
        final r = buf[i * 3] + t, g = buf[i * 3 + 1] + t, b = buf[i * 3 + 2] + t;
        var best = 0;
        var bd = 1e9;
        for (var k = 0; k < pr.length; k++) {
          final dr = r - pr[k], dg = g - pg[k], db = b - pb[k];
          final d = dr * dr * .3 + dg * dg * .59 + db * db * .11;
          if (d < bd) {
            bd = d;
            best = k;
          }
        }
        final c = _palette[best];
        out[i * 4] = (c >> 16) & 255;
        out[i * 4 + 1] = (c >> 8) & 255;
        out[i * 4 + 2] = c & 255;
        out[i * 4 + 3] = 255;
      }
    }
    return out;
  }
}

class _Drop {
  _Drop({required this.x, required this.y, required this.speed, required this.len, required this.near});
  final double x, y, speed;
  final int len;
  final bool near;
}

class _Ripple {
  _Ripple({required this.x, required this.y, required this.phase});
  final double x, y;
  final int phase;
}
