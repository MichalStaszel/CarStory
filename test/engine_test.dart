import 'dart:async';
import 'dart:collection';

import 'package:car_story/engine/game_engine.dart';
import 'package:car_story/engine/interpreter.dart';
import 'package:car_story/engine/phrases.dart';
import 'package:car_story/engine/progress.dart';
import 'package:car_story/models/story.dart';
import 'package:car_story/voice/voice_io.dart';
import 'package:flutter_test/flutter_test.dart';

import 'story_test.dart' show loadStory;

/// Records what the narrator says and answers from a script.
class ScriptedVoice implements VoiceIO {
  ScriptedVoice(List<String?> answers) : _answers = Queue.of(answers);
  final Queue<String?> _answers;
  final spoken = <String>[];

  @override
  Future<void> init(String speechLocale) async {}
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stopSpeaking() async {}
  double rate = 1.0;
  final hintsSeen = <List<String>>[];
  bool Function(List<String>)? lastAcceptEarly;

  @override
  Future<void> setRate(double r) async => rate = r;

  @override
  Future<List<String>?> listen({
    Duration timeout = const Duration(seconds: 9),
    bool Function(List<String>)? acceptEarly,
    List<String> hints = const [],
  }) async {
    hintsSeen.add(hints);
    lastAcceptEarly = acceptEarly;
    if (_answers.isEmpty) return Completer<List<String>?>().future; // wait forever
    final a = _answers.removeFirst();
    return a == null ? null : [a];
  }

  @override
  Future<void> cancelListening() async {}
}

class Session {
  Session(this.story, List<String?> answers, {Progress? progress, Phrases? phrases})
      : voice = ScriptedVoice(answers),
        progress = progress ?? Progress.fresh(story) {
    engine = GameEngine(
      story: story,
      progress: this.progress,
      voice: voice,
      interpreter: Interpreter(phrases ?? Phrases.english),
      onFinished: (c) => finished.complete(c),
    );
  }
  final Story story;
  final ScriptedVoice voice;
  final Progress progress;
  late final GameEngine engine;
  final finished = Completer<bool>();

  Future<void> run() async {
    unawaited(engine.start());
    await pumpEventQueue(times: 2000);
  }
}

void main() {
  final en = loadStory('room-312.en.json');

  test('a full playthrough reaches the authored ending with clues and items', () async {
    final s = Session(en, ['C', 'check on him', 'a', 'a', 'b', 'confront wren', 'union station', 'a', 'b']);
    await s.run();
    expect(s.finished.isCompleted, isTrue);
    expect(await s.finished.future, isTrue);
    expect(s.progress.done, isTrue);
    expect(s.progress.items.keys, containsAll(['revolver', 'key7', 'notebook']));
    expect(s.progress.clues.keys, containsAll(['revolver', 'badge', 'matches', 'confession', 'notebook']));
    expect(s.progress.reached.last, 'Finale');
    // Templated finale used the revolver and the proof branches.
    expect(s.voice.spoken.any((l) => l.startsWith('You draw the nickel-plated revolver')), isTrue);
    expect(s.voice.spoken.any((l) => l.contains('You hand him his notebook')), isTrue);
    expect(s.engine.status, EngineStatus.finished);
  });

  test('a soft failure rewinds to the last checkpoint', () async {
    final s = Session(en, ['b', 'c', 'a', 'tell the police the truth']);
    await s.run();
    expect(s.voice.spoken.any((l) => l.startsWith('The lieutenant listens')), isTrue);
    expect(s.progress.node, 'hallway');
    expect(s.engine.status, EngineStatus.listening);
  });

  test('silence nudges, repeats the options, then pauses', () async {
    final s = Session(en, [null, null, null]);
    await s.run();
    final p = Phrases.english;
    expect(s.voice.spoken, containsAllInOrder([p.listeningNudge, p.repeatOptions, p.pausedForSilence]));
    expect(s.engine.status, EngineStatus.paused);
  });

  test('voice commands answer and return to the same scene', () async {
    final s = Session(en, ['a', 'clues', 'items', 'repeat']);
    await s.run();
    final p = Phrases.english;
    expect(s.voice.spoken, contains(p.cluesIntro));
    expect(s.voice.spoken, contains("Detective Kane's badge."));
    expect(s.voice.spoken, contains(p.noItems));
    expect(s.progress.node, 'check_man');
    expect(s.engine.status, EngineStatus.listening);
  });

  test('quit by voice saves progress and ends the session', () async {
    final s = Session(en, ['a', 'quit']);
    await s.run();
    expect(await s.finished.future, isFalse);
    expect(s.progress.node, 'check_man');
    expect(s.voice.spoken.last, Phrases.english.quitOutro);
  });

  test('resuming a saved story says where you left off', () async {
    final saved = Progress.fresh(en)
      ..node = 'hallway'
      ..checkpoint = 'hallway'
      ..reached.addAll(['Waking Up', 'Hotel Victoria']);
    final s = Session(en, [], progress: saved);
    await s.run();
    expect(s.voice.spoken.take(2), ['Back to Room 312. Last time:', 'Hotel Victoria.']);
    expect(s.progress.sessions, 1);
  });

  test('typed answers work alongside listening', () async {
    final s = Session(en, []);
    await s.run();
    s.engine.submit('B');
    await pumpEventQueue(times: 500);
    expect(s.progress.clues.keys, contains('cable'));
  });

  for (final (file, phrases, answers) in [
    ('room-312.en.json', Phrases.english, ['c', 'a', 'a', 'clues', 'b', 'c', 'b', 'a', 'items', 'a', 'c']),
    ('pokoj-312.pl.json', Phrases.polish, ['c', 'a', 'a', 'wskazówki', 'b', 'c', 'b', 'a', 'przedmioty', 'a', 'c']),
  ]) {
    test('every spoken line in $file has a narration clip slot', () async {
      final story = loadStory(file);
      final s = Session(story, [...answers, null, null, null], phrases: phrases);
      await s.run();
      final clips = narrationSegments(story, phrases).toSet();
      final missing = s.voice.spoken.where((l) => !clips.contains(l)).toList();
      expect(missing, isEmpty);
    });
  }

  test('listening hints the options and accepts a heard letter early', () async {
    final s = Session(en, []);
    await s.run();
    expect(s.voice.hintsSeen.last, containsAll(['A', 'Check on the man', 'C']));
    final early = s.voice.lastAcceptEarly!;
    expect(early(['bee']), isTrue);
    expect(early(['option c']), isTrue);
    expect(early(['check']), isFalse, reason: 'own words wait for the final result');
    expect(early(['call the police and']), isFalse);
  });

  test('narration speed is passed to the voice', () async {
    final s = Session(en, []);
    await s.engine.setRate(1.3);
    expect(s.voice.rate, 1.3);
    expect(s.engine.rate, 1.3);
  });

  test('"faster" and "slower" by voice step the speed and keep listening', () async {
    final s = Session(en, ['faster', 'faster', 'slower']);
    await s.run();
    expect(s.engine.rate, 1.1);
    expect(s.voice.spoken, containsAllInOrder(['Faster.', 'Faster.', 'Slower.']));
    expect(s.engine.status, EngineStatus.listening);
  });
}
