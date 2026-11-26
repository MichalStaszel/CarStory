import 'package:material_ui/material_ui.dart';

import '../app_services.dart';
import '../models/story.dart';
import 'drive_screen.dart';
import 'journal_screen.dart';
import 'strings.dart';
import 'theme.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.services});
  final AppServices services;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  AppServices get s => widget.services;

  Future<void> _play(Story story, {bool restart = false}) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => DriveScreen(services: s, story: story, restart: restart),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _journal(Story story) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => JournalScreen(services: s, story: story, onPlay: (restart) => _play(story, restart: restart)),
    ));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = UiStrings.of(s.lang);
    final stories = s.stories.where((st) => st.lang == s.lang).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(t['app']),
        actions: [
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'en', label: Text('EN')), ButtonSegment(value: 'pl', label: Text('PL'))],
            selected: {s.lang},
            showSelectedIcon: false,
            onSelectionChanged: (v) async {
              await s.setLanguage(v.first);
              setState(() {});
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Text(t['tagline'], style: const TextStyle(color: Noir.dim, fontSize: 15)),
            const SizedBox(height: 16),
            for (final story in stories) _storyCard(story, t),
            for (final (title, genre, blurb) in comingSoon[s.lang]!) _soonCard(title, genre, blurb, t),
            const SizedBox(height: 8),
            Text(t['howTo'], style: const TextStyle(color: Noir.dim, fontSize: 13, fontFamily: 'sans-serif')),
          ],
        ),
      ),
    );
  }

  Widget _storyCard(Story story, UiStrings t) {
    final p = s.store.load(story);
    final saved = s.store.hasSave(story);
    final label = p.done ? t['replay'] : (saved && p.started ? t['continue'] : t['play']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _cover(story.genre, locked: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${story.genre.toUpperCase()} · ${story.minutes} ${t['min']}${p.done ? ' · ${t['solved'].toUpperCase()}' : ''}',
                  style: const TextStyle(color: Noir.dim, fontSize: 11, letterSpacing: .8, fontFamily: 'sans-serif')),
              const SizedBox(height: 2),
              Text(story.title, style: const TextStyle(color: Noir.paper, fontSize: 19, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(story.blurb, style: const TextStyle(color: Noir.dim, fontSize: 14)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton(onPressed: () => _play(story, restart: p.done), child: Text(label)),
                if (saved) OutlinedButton(onPressed: () => _journal(story), child: Text(t['caseFile'])),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _soonCard(String title, String genre, String blurb, UiStrings t) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _cover(genre, locked: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${genre.toUpperCase()} · ${t['soon'].toUpperCase()}',
                    style: const TextStyle(color: Noir.dim, fontSize: 11, letterSpacing: .8, fontFamily: 'sans-serif')),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(color: Noir.paper, fontSize: 19, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(blurb, style: const TextStyle(color: Noir.dim, fontSize: 14)),
              ]),
            ),
          ]),
        ),
      );

  Widget _cover(String genre, {required bool locked}) => Opacity(
        opacity: locked ? .45 : 1,
        child: Container(
          width: 64,
          height: 84,
          padding: const EdgeInsets.all(6),
          alignment: Alignment.bottomLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3B2A1E), Color(0xFF7A3A20), Color(0xFFC08A3E)],
            ),
          ),
          child: Text(genre.toUpperCase(),
              style: const TextStyle(color: Color(0xFFF6E7C8), fontSize: 9, letterSpacing: .6, fontFamily: 'sans-serif')),
        ),
      );
}
