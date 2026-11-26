import 'dart:async';

import '../models/story.dart';
import '../voice/voice_io.dart';
import 'interpreter.dart';
import 'phrases.dart';
import 'progress.dart';

enum EngineStatus { idle, speaking, listening, thinking, paused, finished }

/// Runs one story session: narrates a node, listens for an answer, applies
/// effects and moves on. UI-independent and fully testable with a fake voice.
class GameEngine {
  GameEngine({
    required this.story,
    required this.progress,
    required this.voice,
    required this.interpreter,
    this.onChanged,
    this.onSave,
    this.onFinished,
    this.chime,
    this.onRateChanged,
  });

  /// Narration speeds offered, like an audiobook player.
  static const speeds = [1.0, 1.1, 1.2, 1.3, 1.5, 1.75, 2.0];

  /// Called when the player changes speed by voice, to remember it.
  final void Function(double rate)? onRateChanged;

  final Story story;
  final Progress progress;
  final VoiceIO voice;
  final Interpreter interpreter;

  /// Called whenever [status], [caption], [options] or [heard] change.
  final void Function()? onChanged;
  final void Function(Progress)? onSave;

  /// Called when the session ends; `completed` is true at the story's end.
  final void Function(bool completed)? onFinished;

  /// Short sound when a clue or item is found.
  final Future<void> Function()? chime;

  Phrases get phrases => interpreter.phrases;

  EngineStatus status = EngineStatus.idle;
  String caption = '';
  List<Choice> options = const [];
  String heard = '';

  /// Each start, pause or quit bumps the run id; stale async work checks it
  /// and stops, so a paused session never keeps talking.
  int _run = 0;
  Completer<List<String>?>? _manual;
  int _silentTurns = 0;

  /// Starts or resumes the session from the saved node.
  Future<void> start() async {
    final run = ++_run;
    progress.sessions++;
    _save();
    if (progress.node != story.start && progress.reached.isNotEmpty) {
      final intro = phrases.resumeIntro.replaceAll('{title}', story.title);
      if (!await _say(intro, run, extra: ['${progress.reached.last}.'])) return;
    }
    await _play(progress.node, run);
  }

  /// Resumes after a pause without counting a new session.
  Future<void> resume() async {
    final run = ++_run;
    await _play(progress.node, run);
  }

  Future<void> pause() async {
    _run++;
    _cancelInput();
    await voice.stopSpeaking();
    await voice.cancelListening();
    _set(EngineStatus.paused);
  }

  Future<void> quit() async {
    _run++;
    _cancelInput();
    await voice.stopSpeaking();
    await voice.cancelListening();
    _set(EngineStatus.finished);
    onFinished?.call(false);
  }

  /// Narration speed (1.0 = normal), like an audiobook player.
  double get rate => _rate;
  double _rate = 1.0;
  Future<void> setRate(double r) async {
    _rate = r;
    await voice.setRate(r);
    onChanged?.call();
  }

  /// The player tapped while the narrator talks: skip ahead to answering.
  Future<void> skipNarration() => voice.stopSpeaking();

  /// Typed or tapped answer (test panel, accessibility, phone-in-hand mode).
  void submit(String text) {
    final m = _manual;
    if (m != null && !m.isCompleted) m.complete([text]);
  }

  Future<void> _play(String id, int run, {String bridge = ''}) async {
    if (id == StoryNode.backToCheckpoint) id = progress.checkpoint;
    final node = story.node(id);
    progress.node = id;
    if (node.checkpoint != null && !node.isFail) {
      progress.checkpoint = id;
      if (!progress.reached.contains(node.checkpoint)) progress.reached.add(node.checkpoint!);
    }
    final gained = <String>[];
    final ef = node.effects;
    if (ef != null) {
      final clue = ef.clue;
      if (clue != null && !progress.clues.containsKey(clue.id)) {
        progress.clues[clue.id] = clue;
        gained.addAll([phrases.newClue, '${clue.title}.']);
      }
      final item = ef.item;
      if (item != null && !progress.items.containsKey(item.id)) {
        progress.items[item.id] = item;
        gained.addAll([phrases.youGet, '${item.name}.']);
      }
      if (ef.flag != null) progress.flags.add(ef.flag!);
    }
    if (node.isEnd) progress.done = true;
    _save();

    final text = progress.fill(node.text);
    final spoken = bridge.isEmpty
        ? await _say(text, run, choices: node.choices)
        : await _say(bridge, run, extra: [text], choices: node.choices);
    if (!spoken) return;
    if (gained.isNotEmpty) {
      await chime?.call();
      if (!await _say(gained.first, run, keepCaption: true, extra: gained.sublist(1))) return;
    }

    if (node.isEnd) {
      if (!await _say(phrases.endOutro, run)) return;
      _set(EngineStatus.finished);
      onFinished?.call(true);
      return;
    }
    if (node.isFail) return _play(StoryNode.backToCheckpoint, run);
    if (node.next != null) return _play(node.next!, run);
    return _ask(node, run, text);
  }

  Future<void> _ask(StoryNode node, int run, String sceneText) async {
    _silentTurns = 0;
    while (run == _run) {
      final alts = await _listen(run, node);
      if (run != _run) return;
      if (alts == null || alts.isEmpty) {
        _silentTurns++;
        if (_silentTurns == 1) {
          if (!await _say(phrases.listeningNudge, run, keepCaption: true)) return;
        } else if (_silentTurns == 2) {
          if (!await _say(phrases.repeatOptions, run, choices: node.choices)) return;
        } else {
          await _say(phrases.pausedForSilence, run);
          if (run == _run) _set(EngineStatus.paused);
          _run++;
          return;
        }
        continue;
      }
      _silentTurns = 0;
      heard = alts.first;
      _set(EngineStatus.thinking);
      final r = await interpreter.interpret(alts, node, sceneText: sceneText);
      if (run != _run) return;
      switch (r) {
        case PickedChoice(:final key, :final bridge):
          final choice = node.choices.firstWhere((c) => c.key == key);
          return _play(choice.next, run, bridge: bridge);
        case SpokenCommand(:final command):
          if (!await _command(command, node, run)) return;
        case NotUnderstood(:final reply):
          final ok = reply.isNotEmpty
              ? await _say(reply, run, keepCaption: true, extra: [phrases.whatDoYouDo])
              : await _say(phrases.notUnderstood, run, choices: node.choices);
          if (!ok) return;
      }
    }
  }

  /// Returns false when the session should stop listening.
  Future<bool> _command(VoiceCommand c, StoryNode node, int run) async {
    switch (c) {
      case VoiceCommand.repeat:
        return _say(progress.fill(node.text), run, choices: node.choices);
      case VoiceCommand.clues:
        final clues = progress.clues.values;
        final ok = clues.isEmpty
            ? await _say(phrases.noClues, run)
            : await _say(phrases.cluesIntro, run, extra: [for (final c in clues) ...['${c.title}.', c.text]]);
        return ok && await _say(phrases.backToStory, run, choices: node.choices);
      case VoiceCommand.items:
        final items = progress.items.values;
        final ok = items.isEmpty
            ? await _say(phrases.noItems, run)
            : await _say(phrases.itemsIntro, run, extra: [for (final i in items) '${i.name}.']);
        return ok && await _say(phrases.backToStory, run, choices: node.choices);
      case VoiceCommand.pause:
        await _say(phrases.paused, run);
        await pause();
        return false;
      case VoiceCommand.faster || VoiceCommand.slower:
        final i = speeds.indexWhere((v) => v >= _rate - 0.001);
        final next = c == VoiceCommand.faster
            ? speeds[(i + 1).clamp(0, speeds.length - 1)]
            : speeds[(i - 1).clamp(0, speeds.length - 1)];
        await setRate(next);
        onRateChanged?.call(next);
        return _say(c == VoiceCommand.faster ? phrases.fasterAck : phrases.slowerAck, run, keepCaption: true);
      case VoiceCommand.quit:
        await _say(phrases.quitOutro, run);
        await quit();
        return false;
    }
  }

  /// Speaks a line, then [extra] lines, then the options. Every line is a
  /// separate segment so each can be a pre-recorded narrator clip (see
  /// [narrationSegments]). Returns false if the session was paused or quit.
  Future<bool> _say(String text, int run,
      {List<Choice>? choices, bool keepCaption = false, List<String> extra = const []}) async {
    if (run != _run) return false;
    if (!keepCaption) {
      caption = [text, ...extra].join(' ');
      options = choices ?? const [];
    }
    heard = '';
    _set(EngineStatus.speaking);
    final segments = [text, ...extra, ...optionSegments(phrases, choices ?? const [])];
    for (final seg in segments) {
      if (run != _run) return false;
      await voice.speak(seg);
    }
    return run == _run;
  }

  Future<List<String>?> _listen(int run, StoryNode node) async {
    _set(EngineStatus.listening);
    final manual = _manual = Completer<List<String>?>();
    final heardByVoice = voice.listen(
      timeout: const Duration(seconds: 12),
      acceptEarly: (alts) => interpreter.quickChoice(alts, node) != null,
      hints: interpreter.hintsFor(node),
    );
    final result = await Future.any([manual.future, heardByVoice]);
    if (manual.isCompleted) {
      await voice.cancelListening();
    } else {
      manual.complete(null);
    }
    _manual = null;
    return run == _run ? result : null;
  }

  void _cancelInput() {
    final m = _manual;
    if (m != null && !m.isCompleted) m.complete(null);
  }

  void _save() => onSave?.call(progress);

  void _set(EngineStatus s) {
    status = s;
    onChanged?.call();
  }
}

/// The spoken prompt after a scene: "What do you do?" and one line per option.
List<String> optionSegments(Phrases p, List<Choice> choices) =>
    choices.isEmpty ? const [] : [p.whatDoYouDo, for (final c in choices) '${c.key}: ${c.label}.'];

/// Every line the narrator can say in [story], with all template variants.
/// The audio generator renders one clip per line; at runtime the engine
/// speaks exactly these strings, so each finds its clip.
List<String> narrationSegments(Story story, Phrases p) {
  final out = <String>{};
  final tpl = RegExp(r'\{(\w+)\?([^:}]*):([^}]*)\}');
  for (final n in story.nodes.values) {
    final keys = tpl.allMatches(n.text).map((m) => m[1]!).toSet().toList();
    for (var mask = 0; mask < (1 << keys.length); mask++) {
      final set = {for (var i = 0; i < keys.length; i++) if (mask & (1 << i) != 0) keys[i]};
      out.add(n.text.replaceAllMapped(tpl, (m) => set.contains(m[1]) ? m[2]! : m[3]!));
    }
    out.addAll(optionSegments(p, n.choices));
    final ef = n.effects;
    if (ef?.clue != null) out.addAll(['${ef!.clue!.title}.', ef.clue!.text]);
    if (ef?.item != null) out.add('${ef!.item!.name}.');
    if (n.checkpoint != null) out.add('${n.checkpoint}.');
  }
  out.addAll([
    p.listeningNudge, p.repeatOptions, p.pausedForSilence, p.paused, p.notUnderstood, p.newClue, p.youGet,
    p.cluesIntro, p.noClues, p.itemsIntro, p.noItems, p.backToStory, p.endOutro, p.quitOutro,
    p.resumeIntro.replaceAll('{title}', story.title), p.fasterAck, p.slowerAck,
  ]);
  return out.toList();
}
