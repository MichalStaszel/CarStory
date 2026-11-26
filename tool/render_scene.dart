// Renders the pixel scene to PPM frames for previewing outside the app:
//   dart run tool/render_scene.dart out_dir [--dawn]
import 'dart:io';
import 'dart:typed_data';

import 'package:car_story/ui/pixel/noir_scene.dart';

void main(List<String> args) {
  final dir = Directory(args.isEmpty ? 'build/scene' : args.first)..createSync(recursive: true);
  final scene = NoirScene(dawn: args.contains('--dawn'));
  for (var f = 0; f < scene.frames; f++) {
    final rgba = scene.render(f);
    final out = BytesBuilder()..add('P6\n${scene.width} ${scene.height}\n255\n'.codeUnits);
    for (var i = 0; i < rgba.length; i += 4) {
      out.add([rgba[i], rgba[i + 1], rgba[i + 2]]);
    }
    File('${dir.path}/f${f.toString().padLeft(3, '0')}.ppm').writeAsBytesSync(out.takeBytes());
  }
  stdout.writeln('Wrote ${scene.frames} frames to ${dir.path}');
}
