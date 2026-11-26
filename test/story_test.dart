import 'dart:convert';
import 'dart:io';

import 'package:car_story/engine/progress.dart';
import 'package:car_story/models/story.dart';
import 'package:flutter_test/flutter_test.dart';

Story loadStory(String file) =>
    Story.fromJson(jsonDecode(File('assets/stories/$file').readAsStringSync()) as Map<String, dynamic>);

void main() {
  for (final file in ['room-312.en.json', 'pokoj-312.pl.json']) {
    group(file, () {
      final story = loadStory(file);

      test('has no broken links, dead ends or unreachable scenes', () {
        expect(story.validate(), isEmpty);
      });

      test('every choice node offers A, B and C', () {
        for (final n in story.nodes.values.where((n) => n.choices.isNotEmpty)) {
          expect(n.choices.map((c) => c.key), ['A', 'B', 'C'], reason: n.id);
        }
      });

      test('keywords are lowercase and accent-free', () {
        for (final n in story.nodes.values) {
          for (final c in n.choices) {
            for (final k in c.keywords) {
              expect(k, matches(RegExp(r'^[a-z0-9 ]+$')), reason: '${n.id} ${c.key}');
            }
          }
        }
      });
    });
  }

  test('English and Polish versions share the same scene graph shape', () {
    final en = loadStory('room-312.en.json'), pl = loadStory('pokoj-312.pl.json');
    expect(en.nodes.length, pl.nodes.length);
    expect(en.checkpoints.length, pl.checkpoints.length);
  });

  test('progress survives a save and load', () {
    final story = loadStory('room-312.en.json');
    final p = Progress.fresh(story)
      ..node = 'hallway'
      ..reached.addAll(['Waking Up', 'Hotel Victoria'])
      ..flags.add('checkedMan')
      ..clues['badge'] = story.nodes['check_man']!.effects!.clue!
      ..items['revolver'] = story.nodes['dress']!.effects!.item!
      ..sessions = 2;
    final back = Progress.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
    expect(back.node, 'hallway');
    expect(back.reached, ['Waking Up', 'Hotel Victoria']);
    expect(back.clues.keys, ['badge']);
    expect(back.items.keys, ['revolver']);
    expect(back.has('checkedMan'), isTrue);
    expect(back.has('revolver'), isTrue);
    expect(back.fill('{revolver?gun:no gun} {hasProof?proof:no proof}'), 'gun no proof');
  });
}
