import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import 'noir_scene.dart';

/// Plays the animated pixel-art scene, scaled up with hard pixel edges.
/// Frames are rendered once in a background isolate and cached per variant.
class PixelSceneView extends StatefulWidget {
  const PixelSceneView({super.key, this.dawn = false, this.fps = 12});
  final bool dawn;
  final int fps;

  @override
  State<PixelSceneView> createState() => _PixelSceneViewState();
}

class _PixelSceneViewState extends State<PixelSceneView> with SingleTickerProviderStateMixin {
  static final Map<bool, Future<List<ui.Image>>> _cache = {};

  List<ui.Image>? _frames;
  int _frame = 0;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _load();
  }

  @override
  void didUpdateWidget(PixelSceneView old) {
    super.didUpdateWidget(old);
    if (old.dawn != widget.dawn) _load();
  }

  Future<void> _load() async {
    final frames = await (_cache[widget.dawn] ??= _renderAll(widget.dawn));
    if (!mounted) return;
    setState(() => _frames = frames);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!reduceMotion && !_ticker.isActive) _ticker.start();
  }

  static Future<List<ui.Image>> _renderAll(bool dawn) async {
    final scene = NoirScene(dawn: dawn);
    final raw = await compute(_renderFrames, dawn);
    return Future.wait([
      for (final px in raw)
        () {
          final c = Completer<ui.Image>();
          ui.decodeImageFromPixels(px, scene.width, scene.height, ui.PixelFormat.rgba8888, c.complete);
          return c.future;
        }(),
    ]);
  }

  void _tick(Duration elapsed) {
    final f = _frames;
    if (f == null) return;
    if (elapsed - _last < Duration(milliseconds: 1000 ~/ widget.fps)) return;
    _last = elapsed;
    setState(() => _frame = (_frame + 1) % f.length);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = _frames;
    return AspectRatio(
      aspectRatio: 160 / 224,
      child: f == null
          ? const ColoredBox(color: Color(0xFF05070D))
          : RawImage(image: f[_frame], fit: BoxFit.cover, filterQuality: FilterQuality.none),
    );
  }
}

List<Uint8List> _renderFrames(bool dawn) {
  final scene = NoirScene(dawn: dawn);
  return [for (var i = 0; i < scene.frames; i++) scene.render(i)];
}
