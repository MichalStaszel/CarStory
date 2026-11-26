import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_services.dart';
import '../engine/game_engine.dart';
import '../engine/interpreter.dart';
import '../engine/phrases.dart';
import '../engine/progress.dart';
import '../models/story.dart';
import 'journal_screen.dart';
import 'strings.dart';
import 'theme.dart';

/// Driving mode: one big button and the narrator's voice. Nothing to read
/// unless captions are turned on; the whole screen is a tap target.
class DriveScreen extends StatefulWidget {
  const DriveScreen({super.key, required this.services, required this.story, this.restart = false});
  final AppServices services;
  final Story story;
  final bool restart;

  @override
  State<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends State<DriveScreen> {
  GameEngine? _engine;
  late Progress _progress;
  bool _started = false;
  bool _captions = false;
  final _typed = TextEditingController();

  UiStrings get t => UiStrings.of(widget.story.lang);

  @override
  void initState() {
    super.initState();
    final s = widget.services;
    _progress = widget.restart ? Progress.fresh(widget.story) : s.store.load(widget.story);
    if (_progress.done) _progress = Progress.fresh(widget.story);
    WakelockPlus.enable();
    s.voiceFor(widget.story.lang).then((voice) {
      if (!mounted) return;
      setState(() {
        _engine = GameEngine(
          story: widget.story,
          progress: _progress,
          voice: voice,
          interpreter: Interpreter(Phrases.forLang(widget.story.lang)),
          onChanged: () => mounted ? setState(() {}) : null,
          onSave: (p) => s.store.save(widget.story, p),
          chime: () => SystemSound.play(SystemSoundType.click),
          onFinished: _finished,
        );
      });
    });
  }

  void _finished(bool completed) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => JournalScreen(
        services: widget.services,
        story: widget.story,
        onPlay: (restart) => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => DriveScreen(services: widget.services, story: widget.story, restart: restart),
        )),
      ),
    ));
  }

  @override
  void dispose() {
    _engine?.pause();
    WakelockPlus.disable();
    _typed.dispose();
    super.dispose();
  }

  void _tap() {
    final e = _engine;
    if (e == null) return;
    HapticFeedback.lightImpact();
    if (!_started) {
      _started = true;
      e.start();
      return;
    }
    switch (e.status) {
      case EngineStatus.speaking:
        e.skipNarration();
      case EngineStatus.paused:
        e.resume();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _engine;
    final status = e?.status ?? EngineStatus.idle;
    final (icon, label, hint) = switch (status) {
      _ when !_started => (Icons.play_arrow_rounded, t['start'], t['tapToStart']),
      EngineStatus.speaking => (Icons.volume_up_rounded, t['narrator'], t['tapToAnswer']),
      EngineStatus.listening => (Icons.mic_rounded, t['listening'], t['sayOption']),
      EngineStatus.thinking => (Icons.more_horiz_rounded, t['thinking'], ''),
      EngineStatus.paused => (Icons.play_arrow_rounded, t['paused'], t['tapToResume']),
      _ => (Icons.play_arrow_rounded, t['start'], ''),
    };
    final listening = status == EngineStatus.listening;

    return Scaffold(
      backgroundColor: Noir.ink,
      appBar: AppBar(
        title: Text(widget.story.title, style: const TextStyle(fontSize: 16, color: Noir.dim)),
        actions: [
          IconButton(
            tooltip: t['captions'],
            icon: Icon(_captions ? Icons.closed_caption : Icons.closed_caption_off_outlined),
            onPressed: () => setState(() => _captions = !_captions),
          ),
          if (_started)
            TextButton(
              onPressed: status == EngineStatus.paused ? e?.resume : e?.pause,
              child: Text(status == EngineStatus.paused ? t['continue'] : t['pause']),
            ),
          TextButton(onPressed: () => _started ? e?.quit() : Navigator.pop(context), child: Text(t['end'])),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _tap,
          child: Column(children: [
            Expanded(
              child: Center(
                child: Semantics(
                  button: true,
                  label: '$label. $hint',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: listening
                            ? const [Color(0xFF6B2A18), Color(0xFF2A120A)]
                            : const [Color(0xFF3A2A20), Color(0xFF1B1410)],
                      ),
                      border: Border.all(
                        color: listening ? Noir.brick : (status == EngineStatus.speaking ? Noir.amber : Noir.line),
                        width: listening ? 4 : 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (listening ? Noir.brick : Noir.amber).withValues(alpha: listening ? .45 : .15),
                          blurRadius: 80,
                        ),
                      ],
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(icon, size: 64, color: Noir.paper),
                      const SizedBox(height: 8),
                      Text(label, style: const TextStyle(color: Noir.paper, fontSize: 20, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 190,
                        child: Text(hint, textAlign: TextAlign.center, style: const TextStyle(color: Noir.dim, fontSize: 13)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            if (_captions && e != null) _captionBox(e),
            if (_started && e != null) _typePanel(e),
          ]),
        ),
      ),
    );
  }

  Widget _captionBox(GameEngine e) => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.caption, style: const TextStyle(color: Color(0xFFD9CCB8), fontSize: 17, height: 1.5)),
            for (final o in e.options)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${o.key} · ${o.label}', style: const TextStyle(color: Noir.paper, fontSize: 16)),
              ),
            if (e.heard.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${t['heard']}: ${e.heard}', style: const TextStyle(color: Noir.amber, fontSize: 14)),
              ),
          ]),
        ),
      );

  /// For a parked car or a passenger: answer by tapping or typing.
  Widget _typePanel(GameEngine e) => Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(t['typeInstead'], style: const TextStyle(color: Noir.dim, fontSize: 13)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final o in e.options)
                OutlinedButton(onPressed: () => e.submit(o.key), child: Text('${o.key}: ${o.label}')),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _typed,
                  onSubmitted: (_) => _send(e),
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: () => _send(e), child: Text(t['send'])),
            ]),
          ],
        ),
      );

  void _send(GameEngine e) {
    final v = _typed.text.trim();
    if (v.isEmpty) return;
    _typed.clear();
    e.submit(v);
  }
}
