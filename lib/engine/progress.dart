import '../models/story.dart';

/// The player's saved state for one story.
class Progress {
  Progress({
    required this.node,
    required this.checkpoint,
    List<String>? reached,
    Map<String, Clue>? clues,
    Map<String, Item>? items,
    Set<String>? flags,
    this.done = false,
    this.sessions = 0,
  })  : reached = reached ?? [],
        clues = clues ?? {},
        items = items ?? {},
        flags = flags ?? {};

  factory Progress.fresh(Story story) => Progress(node: story.start, checkpoint: story.start);

  String node;

  /// Node id of the last checkpoint reached (where a failure rewinds to).
  String checkpoint;

  /// Checkpoint names reached, in order.
  final List<String> reached;
  final Map<String, Clue> clues;
  final Map<String, Item> items;
  final Set<String> flags;
  bool done;
  int sessions;

  bool get started => reached.length > 1 || sessions > 0;

  bool has(String key) => flags.contains(key) || items.containsKey(key);

  /// Resolves `{key?a:b}` templates in narration.
  String fill(String text) => text.replaceAllMapped(
        RegExp(r'\{(\w+)\?([^:}]*):([^}]*)\}'),
        (m) => has(m[1]!) ? m[2]! : m[3]!,
      );

  Map<String, dynamic> toJson() => {
        'node': node,
        'checkpoint': checkpoint,
        'reached': reached,
        'clues': clues.values.map((c) => c.toJson()).toList(),
        'items': items.values.map((i) => i.toJson()).toList(),
        'flags': flags.toList(),
        'done': done,
        'sessions': sessions,
      };

  factory Progress.fromJson(Map<String, dynamic> j) => Progress(
        node: j['node'] as String,
        checkpoint: j['checkpoint'] as String,
        reached: ((j['reached'] ?? const []) as List).cast<String>(),
        clues: {
          for (final c in (j['clues'] ?? const []) as List)
            (c as Map<String, dynamic>)['id'] as String: Clue.fromJson(c),
        },
        items: {
          for (final i in (j['items'] ?? const []) as List)
            (i as Map<String, dynamic>)['id'] as String: Item.fromJson(i),
        },
        flags: ((j['flags'] ?? const []) as List).cast<String>().toSet(),
        done: j['done'] == true,
        sessions: (j['sessions'] ?? 0) as int,
      );
}
