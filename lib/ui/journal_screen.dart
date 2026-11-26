import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../models/story.dart';
import 'portrait_painter.dart';
import 'strings.dart';
import 'theme.dart';

/// The case file shown after a session: portrait, progress, checkpoints,
/// clues and items. Meant for when the car is parked.
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key, required this.services, required this.story, required this.onPlay});
  final AppServices services;
  final Story story;
  final void Function(bool restart) onPlay;

  @override
  Widget build(BuildContext context) {
    final t = UiStrings.of(story.lang);
    final p = services.store.load(story);
    final cps = story.checkpoints;
    final pct = p.done ? 1.0 : (cps.isEmpty ? 0.0 : p.reached.length / cps.length);
    final current = story.nodes[p.checkpoint]?.checkpoint;
    const label = TextStyle(color: Noir.dim, fontSize: 11, letterSpacing: .8, fontFamily: 'sans-serif');
    const h2 = TextStyle(color: Noir.paper, fontSize: 19, fontWeight: FontWeight.w600);

    final portrait = AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF5A3C22), width: 6),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(painter: PortraitPainter(p, stamp: t['caseClosed'])),
      ),
    );

    final progressCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t['progress'].toUpperCase(), style: label),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: pct, minHeight: 10, color: Noir.amber, backgroundColor: Noir.line),
          ),
          const SizedBox(height: 6),
          Text(p.done ? t['finished'] : '${(pct * 100).round()}% · ${p.reached.length}/${cps.length}',
              style: const TextStyle(color: Noir.dim, fontSize: 13)),
          const SizedBox(height: 14),
          Text(t['checkpoints'], style: h2),
          const SizedBox(height: 8),
          for (final c in cps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Icon(Icons.circle,
                    size: 12,
                    color: !p.reached.contains(c) ? Noir.line : (c == current && !p.done ? Noir.brick : Noir.amber)),
                const SizedBox(width: 12),
                Text(p.reached.contains(c) ? c : '???',
                    style: TextStyle(color: p.reached.contains(c) ? Noir.paper : Noir.dim, fontSize: 15)),
              ]),
            ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(onPressed: () => onPlay(p.done), child: Text(p.done ? t['replay'] : t['continue'])),
            OutlinedButton(onPressed: () => onPlay(true), child: Text(t['restart'])),
          ]),
        ]),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(t['caseFile'])),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
          Text('${story.genre.toUpperCase()} · ${p.sessions} ${t['sessions']}', style: label),
          const SizedBox(height: 4),
          Text(story.title, style: const TextStyle(color: Noir.paper, fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(p.done ? story.ending : story.blurb, style: const TextStyle(color: Noir.dim, fontSize: 15)),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) => c.maxWidth >= 600
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 280, child: portrait),
                    const SizedBox(width: 16),
                    Expanded(child: progressCard),
                  ])
                : Column(children: [portrait, const SizedBox(height: 8), progressCard]),
          ),
          Text(t['portraitNote'], style: const TextStyle(color: Noir.dim, fontSize: 13)),
          const SizedBox(height: 20),
          Text(t['clues'], style: h2),
          const SizedBox(height: 10),
          if (p.clues.isEmpty) Text(t['noCluesYet'], style: const TextStyle(color: Noir.dim, fontStyle: FontStyle.italic)),
          for (final c in p.clues.values)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
              decoration: const BoxDecoration(border: Border(left: BorderSide(color: Noir.amber, width: 3))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.title, style: const TextStyle(color: Noir.paper, fontSize: 15, fontWeight: FontWeight.w600)),
                Text(c.text, style: const TextStyle(color: Noir.dim, fontSize: 14)),
              ]),
            ),
          const SizedBox(height: 20),
          Text(t['items'], style: h2),
          const SizedBox(height: 10),
          if (p.items.isEmpty) Text(t['emptyPockets'], style: const TextStyle(color: Noir.dim, fontStyle: FontStyle.italic)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final i in p.items.values)
              Container(
                width: 160,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(border: Border.all(color: Noir.line), borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.name, style: const TextStyle(color: Noir.paper, fontWeight: FontWeight.w600)),
                  Text(i.desc, style: const TextStyle(color: Noir.dim, fontSize: 13)),
                ]),
              ),
          ]),
        ]),
      ),
    );
  }
}
