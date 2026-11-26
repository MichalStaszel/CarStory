import '../models/story.dart';
import 'phrases.dart';

/// What the player meant.
sealed class Interpretation {
  const Interpretation();
}

class PickedChoice extends Interpretation {
  const PickedChoice(this.key, {this.bridge = ''});
  final String key;

  /// Optional line spoken before the next scene, echoing the player's words.
  final String bridge;
}

class SpokenCommand extends Interpretation {
  const SpokenCommand(this.command);
  final VoiceCommand command;
}

class NotUnderstood extends Interpretation {
  const NotUnderstood({this.reply = ''});

  /// An in-world reaction for free-form actions that fit no option.
  final String reply;
}

/// Optional online helper for free-form answers (e.g. an LLM behind a small
/// server). It must map the player's words to a choice or return a short
/// in-world reply that keeps the authored plot. Return null on failure.
abstract interface class FreeformResolver {
  Future<Interpretation?> resolve({
    required String said,
    required String sceneText,
    required List<Choice> choices,
    required String lang,
  });
}

/// Normalizes speech for matching: lowercase, no accents, no punctuation.
String normalize(String s) {
  const from = 'ąćęłńóśźżäöüéèàáíúçñ';
  const to = 'acelnoszzaoueeaaiucn';
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b
      .toString()
      .replaceAll(RegExp(r"[^a-z0-9' ]+"), ' ')
      .replaceAll("'", '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class Interpreter {
  Interpreter(this.phrases, {this.freeform});

  final Phrases phrases;
  final FreeformResolver? freeform;

  /// Instant match on a short answer: a letter ("bee", "option c") or an
  /// ordinal ("second"). Used on partial speech results so the game reacts
  /// as soon as the letter is heard. Returns the choice key or null.
  String? quickChoice(List<String> alternatives, StoryNode node) {
    final keys = node.choices.map((c) => c.key).toSet();
    for (final v in alternatives.map(normalize)) {
      if (v.isEmpty) continue;
      final k = _letterOrOrdinal(v);
      if (k != null && keys.contains(k)) return k;
    }
    return null;
  }

  /// Phrases to bias the recognizer toward for this scene.
  List<String> hintsFor(StoryNode node) => [
        for (final c in node.choices) ...[c.key, c.label],
        for (final words in phrases.letters.values) ...words.take(2),
      ];

  /// [alternatives] are the recognizer's transcriptions, best first.
  Future<Interpretation> interpret(List<String> alternatives, StoryNode node, {String sceneText = ''}) async {
    final variants = alternatives.map(normalize).where((v) => v.isNotEmpty).toList();
    if (variants.isEmpty) return const NotUnderstood();

    for (final v in variants) {
      for (final e in phrases.commands.entries) {
        if (e.value.hasMatch(v)) return SpokenCommand(e.key);
      }
    }

    final keys = node.choices.map((c) => c.key).toSet();
    for (final v in variants) {
      final k = _letterOrOrdinal(v);
      if (k != null && keys.contains(k)) return PickedChoice(k);
    }

    final byKeyword = _keywordMatch(variants.first, node.choices);
    if (byKeyword != null) return PickedChoice(byKeyword);

    final ff = freeform;
    if (ff != null) {
      try {
        final r = await ff
            .resolve(said: alternatives.first, sceneText: sceneText, choices: node.choices, lang: phrases.lang)
            .timeout(const Duration(seconds: 8));
        if (r is PickedChoice && keys.contains(r.key)) return r;
        if (r is NotUnderstood) return r;
      } catch (_) {
        // Offline or slow: fall through to the authored prompt.
      }
    }
    return const NotUnderstood();
  }

  String? _letterOrOrdinal(String v) {
    final m = phrases.choicePattern.firstMatch(v);
    if (m != null) {
      final k = _letter(m[1]!);
      if (k != null) return k;
    }
    final tokens = v.split(' ');
    if (tokens.length <= 3) {
      for (final t in tokens) {
        final k = _letter(t);
        if (k != null) return k;
      }
    }
    if (tokens.length <= 4) {
      for (final e in phrases.ordinals.entries) {
        if (tokens.any(e.value.hasMatch)) return e.key;
      }
    }
    return null;
  }

  String? _letter(String token) {
    for (final e in phrases.letters.entries) {
      if (e.value.contains(token)) return e.key;
    }
    return null;
  }

  /// Scores each choice by how many of its keywords appear. Only a unique
  /// best score counts, so an ambiguous answer is asked again.
  String? _keywordMatch(String v, List<Choice> choices) {
    // Keywords match at the start of a word, so stems like "search" also
    // catch "searching", while "man" does not fire inside "romance".
    final scores = [
      for (final c in choices) c.keywords.where((k) => RegExp('(^| )${RegExp.escape(k)}').hasMatch(v)).length,
    ];
    if (scores.isEmpty) return null;
    final best = scores.reduce((a, b) => a > b ? a : b);
    if (best == 0 || scores.where((s) => s == best).length != 1) return null;
    return choices[scores.indexOf(best)].key;
  }
}
