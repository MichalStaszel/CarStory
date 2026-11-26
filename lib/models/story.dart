/// Story data model. Stories are authored JSON files in `assets/stories/`,
/// shared with the browser prototype. Narration is second person, present
/// tense, so it never needs the player's gender.
class Clue {
  const Clue({required this.id, required this.title, required this.text});
  final String id;
  final String title;
  final String text;

  factory Clue.fromJson(Map<String, dynamic> j) =>
      Clue(id: j['id'] as String, title: j['title'] as String, text: j['text'] as String);
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'text': text};
}

class Item {
  const Item({required this.id, required this.name, required this.desc});
  final String id;
  final String name;
  final String desc;

  factory Item.fromJson(Map<String, dynamic> j) =>
      Item(id: j['id'] as String, name: j['name'] as String, desc: (j['desc'] ?? '') as String);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'desc': desc};
}

class Effects {
  const Effects({this.clue, this.item, this.flag});
  final Clue? clue;
  final Item? item;
  final String? flag;

  factory Effects.fromJson(Map<String, dynamic> j) => Effects(
        clue: j['clue'] == null ? null : Clue.fromJson(j['clue'] as Map<String, dynamic>),
        item: j['item'] == null ? null : Item.fromJson(j['item'] as Map<String, dynamic>),
        flag: j['flag'] as String?,
      );
}

class Choice {
  const Choice({required this.key, required this.label, required this.keywords, required this.next});

  /// "A", "B" or "C".
  final String key;
  final String label;

  /// Lowercase, accent-free fragments matched against what the player said.
  final List<String> keywords;
  final String next;

  factory Choice.fromJson(Map<String, dynamic> j) => Choice(
        key: j['key'] as String,
        label: j['label'] as String,
        keywords: ((j['kw'] ?? const []) as List).cast<String>(),
        next: j['next'] as String,
      );
}

class StoryNode {
  const StoryNode({
    required this.id,
    required this.text,
    this.checkpoint,
    this.choices = const [],
    this.next,
    this.effects,
    this.isEnd = false,
    this.isFail = false,
  });

  final String id;

  /// Narration. May contain `{flagOrItem?shown if set:shown otherwise}`.
  final String text;
  final String? checkpoint;
  final List<Choice> choices;

  /// Automatic continuation when there are no choices.
  /// `@checkpoint` jumps back to the last reached checkpoint.
  final String? next;
  final Effects? effects;
  final bool isEnd;

  /// A soft failure: narrated, then the player returns to the last checkpoint.
  final bool isFail;

  static const backToCheckpoint = '@checkpoint';

  factory StoryNode.fromJson(String id, Map<String, dynamic> j) => StoryNode(
        id: id,
        text: j['text'] as String,
        checkpoint: j['checkpoint'] as String?,
        choices: ((j['choices'] ?? const []) as List)
            .map((c) => Choice.fromJson(c as Map<String, dynamic>))
            .toList(),
        next: j['next'] as String?,
        effects: j['effects'] == null ? null : Effects.fromJson(j['effects'] as Map<String, dynamic>),
        isEnd: j['end'] == true,
        isFail: j['fail'] == true,
      );
}

class Story {
  const Story({
    required this.id,
    required this.lang,
    required this.title,
    required this.genre,
    required this.blurb,
    required this.ending,
    required this.minutes,
    required this.start,
    required this.nodes,
  });

  final String id;

  /// Language code, e.g. `en` or `pl`.
  final String lang;
  final String title;
  final String genre;
  final String blurb;
  final String ending;
  final int minutes;
  final String start;
  final Map<String, StoryNode> nodes;

  factory Story.fromJson(Map<String, dynamic> j) {
    final raw = j['nodes'] as Map<String, dynamic>;
    return Story(
      id: j['id'] as String,
      lang: (j['lang'] ?? 'en') as String,
      title: j['title'] as String,
      genre: j['genre'] as String,
      blurb: j['blurb'] as String,
      ending: (j['ending'] ?? '') as String,
      minutes: (j['minutes'] ?? 20) as int,
      start: j['start'] as String,
      nodes: raw.map((k, v) => MapEntry(k, StoryNode.fromJson(k, v as Map<String, dynamic>))),
    );
  }

  StoryNode node(String id) {
    final n = nodes[id];
    if (n == null) throw StateError('Story $id has no node "$id"');
    return n;
  }

  /// Checkpoint names in authoring order, used for the progress timeline.
  List<String> get checkpoints {
    final seen = <String>{};
    return [
      for (final n in nodes.values)
        if (n.checkpoint != null && !n.isFail && seen.add(n.checkpoint!)) n.checkpoint!,
    ];
  }

  /// Returns a list of authoring problems (broken links, dead ends,
  /// unreachable nodes). Empty means the story is playable.
  List<String> validate() {
    final problems = <String>[];
    for (final n in nodes.values) {
      final targets = [if (n.next != null) n.next!, ...n.choices.map((c) => c.next)];
      for (final t in targets) {
        if (t != StoryNode.backToCheckpoint && !nodes.containsKey(t)) problems.add('${n.id} -> missing "$t"');
      }
      if (!n.isEnd && n.next == null && n.choices.isEmpty) problems.add('${n.id} is a dead end');
    }
    final seen = <String>{};
    final queue = [start];
    while (queue.isNotEmpty) {
      final id = queue.removeLast();
      if (id == StoryNode.backToCheckpoint || !seen.add(id) || !nodes.containsKey(id)) continue;
      final n = nodes[id]!;
      if (n.next != null) queue.add(n.next!);
      queue.addAll(n.choices.map((c) => c.next));
    }
    for (final id in nodes.keys) {
      if (!seen.contains(id)) problems.add('$id is unreachable');
    }
    return problems;
  }
}
