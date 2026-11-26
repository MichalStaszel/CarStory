import 'package:car_story/engine/progress.dart';
import 'package:car_story/ui/evidence.dart';
import 'package:car_story/ui/portrait_painter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'story_test.dart' show loadStory;

void main() {
  final story = loadStory('room-312.en.json');

  testWidgets('portrait and evidence render without errors', (tester) async {
    final p = Progress.fresh(story)
      ..items['revolver'] = story.nodes['dress']!.effects!.item!
      ..items['key7'] = story.nodes['pockets']!.effects!.item!
      ..items['notebook'] = story.nodes['locker']!.effects!.item!
      ..items['page'] = story.nodes['burned_papers']!.effects!.item!;
    await tester.binding.setSurfaceSize(const Size(600, 1000));
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF0E0C0B),
        child: Column(children: [
          RepaintBoundary(
            key: const Key('portrait'),
            child: SizedBox(width: 600, height: 800, child: CustomPaint(painter: PortraitPainter(p))),
          ),
          RepaintBoundary(
            key: const Key('evidence'),
            child: SizedBox(
              height: 200,
              width: 600,
              child: Wrap(spacing: 0, children: [for (final i in p.items.values) EvidenceTile(item: i)]),
            ),
          ),
        ]),
      ),
    ));
    // Pixel-exact goldens differ between machines, so this only checks that
    // painting succeeds. To look at the art, temporarily add
    // `matchesGoldenFile` and run with --update-goldens (see docs/).
    expect(tester.takeException(), isNull);
    expect(find.byType(EvidenceTile), findsNWidgets(4));
  });
}
