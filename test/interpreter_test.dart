import 'package:car_story/engine/interpreter.dart';
import 'package:car_story/engine/phrases.dart';
import 'package:car_story/models/story.dart';
import 'package:flutter_test/flutter_test.dart';

import 'story_test.dart' show loadStory;

void main() {
  group('English', () {
    final node = loadStory('room-312.en.json').nodes['intro']!;
    final i = Interpreter(Phrases.english);
    Future<String?> pick(String said) async => switch (await i.interpret([said], node)) {
          PickedChoice(:final key) => key,
          SpokenCommand(:final command) => 'cmd:${command.name}',
          NotUnderstood() => null,
        };

    test('letters as speech recognizers write them', () async {
      expect(await pick('A'), 'A');
      expect(await pick('bee'), 'B');
      expect(await pick('See.'), 'C');
      expect(await pick('option b'), 'B');
      expect(await pick("I'll go with c"), 'C');
    });

    test('ordinals', () async {
      expect(await pick('the first one'), 'A');
      expect(await pick('third'), 'C');
    });

    test('own words map through keywords', () async {
      expect(await pick('I check if the guy is alive'), 'A');
      expect(await pick('call the cops'), 'B');
      expect(await pick('grab my clothes and get out of here'), 'C');
    });

    test('keywords match word starts only', () async {
      expect(await pick('romance'), isNull);
    });

    test('voice commands', () async {
      expect(await pick('repeat that'), 'cmd:repeat');
      expect(await pick('what clues do I have'), 'cmd:clues');
      expect(await pick('inventory'), 'cmd:items');
      expect(await pick('pause'), 'cmd:pause');
      expect(await pick('end the game'), 'cmd:quit');
    });

    test('unrelated speech is not understood', () async {
      expect(await pick('what a lovely day for a drive'), isNull);
    });

    test('a later alternative transcription can still match', () async {
      final r = await i.interpret(['bead', 'b'], node);
      expect(r, isA<PickedChoice>().having((p) => p.key, 'key', 'B'));
    });
  });

  group('Polish', () {
    final node = loadStory('pokoj-312.pl.json').nodes['intro']!;
    final i = Interpreter(Phrases.polish);
    Future<String?> pick(String said) async => switch (await i.interpret([said], node)) {
          PickedChoice(:final key) => key,
          SpokenCommand(:final command) => 'cmd:${command.name}',
          NotUnderstood() => null,
        };

    test('letters, ordinals and own words', () async {
      expect(await pick('be'), 'B');
      expect(await pick('opcja ce'), 'C');
      expect(await pick('pierwsza'), 'A');
      expect(await pick('sprawdzam tego faceta'), 'A');
      expect(await pick('dzwonię na policję'), 'B');
      expect(await pick('szybko się ubieram i wychodzę'), 'C');
    });

    test('commands', () async {
      expect(await pick('powtórz'), 'cmd:repeat');
      expect(await pick('jakie mam wskazówki'), 'cmd:clues');
      expect(await pick('zakończ'), 'cmd:quit');
    });
  });

  test('normalize strips accents and punctuation', () {
    expect(normalize('Dzwonię na policję!'), 'dzwonie na policje');
    expect(normalize("Let's GO, now."), 'lets go now');
  });

  test('a free-form helper is consulted only when nothing else matches', () async {
    final node = loadStory('room-312.en.json').nodes['intro']!;
    final helper = _FakeResolver();
    final i = Interpreter(Phrases.english, freeform: helper);
    expect(await i.interpret(['b'], node), isA<PickedChoice>());
    expect(helper.calls, 0);
    final r = await i.interpret(['I jump out the window'], node);
    expect(r, isA<NotUnderstood>().having((n) => n.reply, 'reply', 'The window is painted shut.'));
    expect(helper.calls, 1);
  });
}

class _FakeResolver implements FreeformResolver {
  int calls = 0;
  @override
  Future<Interpretation?> resolve(
      {required String said, required String sceneText, required List<Choice> choices, required String lang}) async {
    calls++;
    return const NotUnderstood(reply: 'The window is painted shut.');
  }
}
