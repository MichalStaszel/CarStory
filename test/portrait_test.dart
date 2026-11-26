import 'package:car_story/engine/progress.dart';
import 'package:car_story/ui/evidence.dart';
import 'package:car_story/ui/pixel/noir_scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'story_test.dart' show loadStory;

void main() {
  test('pixel scene renders a seamless, animated loop in both moods', () {
    for (final dawn in [false, true]) {
      final scene = NoirScene(dawn: dawn);
      final a = scene.render(0), b = scene.render(6), loop = scene.render(scene.frames);
      expect(a.length, scene.width * scene.height * 4);
      expect(a, isNot(equals(b)), reason: 'rain and lights move between frames');
      expect(loop, equals(a), reason: 'frame N wraps to frame 0');
    }
  });

  test('night and dawn use different light', () {
    final night = NoirScene().render(0), dawn = NoirScene(dawn: true).render(0);
    int brightness(List<int> px) {
      var sum = 0;
      for (var i = 0; i < px.length; i += 4) {
        sum += px[i] + px[i + 1] + px[i + 2];
      }
      return sum;
    }

    expect(brightness(dawn), greaterThan(brightness(night)));
  });

  testWidgets('evidence tiles render', (tester) async {
    final story = loadStory('room-312.en.json');
    final p = Progress.fresh(story)
      ..items['revolver'] = story.nodes['dress']!.effects!.item!
      ..items['key7'] = story.nodes['pockets']!.effects!.item!
      ..items['notebook'] = story.nodes['locker']!.effects!.item!
      ..items['page'] = story.nodes['burned_papers']!.effects!.item!;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Wrap(children: [for (final i in p.items.values) EvidenceTile(item: i)]),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(EvidenceTile), findsNWidgets(4));
  });
}
