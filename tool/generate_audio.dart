// Renders every narrator line of every story to an MP3 clip with a premium
// text-to-speech voice (ElevenLabs), into assets/audio/<lang>/<key>.mp3.
//
//   ELEVENLABS_API_KEY=... dart run tool/generate_audio.dart            # all stories
//   ELEVENLABS_API_KEY=... dart run tool/generate_audio.dart --dry-run  # count characters only
//
// Required: ELEVENLABS_VOICE_EN / ELEVENLABS_VOICE_PL, the voice ids picked in
// the ElevenLabs voice library. Optional: ELEVENLABS_MODEL (default
// eleven_multilingual_v2).
// Existing clips are skipped, so re-running after a text edit only renders
// the changed lines. Delete clips no longer used with --prune.
import 'dart:convert';
import 'dart:io';

import 'package:car_story/engine/game_engine.dart';
import 'package:car_story/engine/phrases.dart';
import 'package:car_story/models/story.dart';
import 'package:car_story/voice/clips.dart';

Future<void> main(List<String> args) async {
  final dry = args.contains('--dry-run');
  final prune = args.contains('--prune');
  final key = Platform.environment['ELEVENLABS_API_KEY'];
  if (!dry && (key == null || key.isEmpty)) {
    stderr.writeln('Set ELEVENLABS_API_KEY, or pass --dry-run to only count characters.');
    exit(64);
  }
  final model = Platform.environment['ELEVENLABS_MODEL'] ?? 'eleven_multilingual_v2';
  final voices = {
    'en': Platform.environment['ELEVENLABS_VOICE_EN'],
    'pl': Platform.environment['ELEVENLABS_VOICE_PL'],
  };

  final wanted = <String, Set<String>>{};
  var totalChars = 0, newChars = 0, rendered = 0;
  final client = HttpClient();

  for (final f in Directory('assets/stories').listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
    final story = Story.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    final phrases = Phrases.forLang(story.lang);
    final dir = Directory('assets/audio/${story.lang}')..createSync(recursive: true);
    for (final line in narrationSegments(story, phrases)) {
      final file = File('${dir.path}/${clipKey(story.lang, line)}.mp3');
      (wanted[story.lang] ??= {}).add(file.path);
      totalChars += line.length;
      if (file.existsSync()) continue;
      newChars += line.length;
      if (dry) continue;
      final voice = voices[story.lang];
      if (voice == null || voice.isEmpty) {
        stderr.writeln('Set ELEVENLABS_VOICE_${story.lang.toUpperCase()} to a voice id.');
        exit(64);
      }
      final req = await client.postUrl(Uri.parse(
          'https://api.elevenlabs.io/v1/text-to-speech/$voice?output_format=mp3_44100_128'));
      req.headers
        ..set('xi-api-key', key!)
        ..contentType = ContentType.json;
      req.write(jsonEncode({
        'text': line,
        'model_id': model,
        'language_code': story.lang,
        'voice_settings': {'stability': 0.45, 'similarity_boost': 0.8, 'style': 0.35},
      }));
      final res = await req.close();
      if (res.statusCode != 200) {
        stderr.writeln('Failed (${res.statusCode}) for: $line\n${await res.transform(utf8.decoder).join()}');
        exit(1);
      }
      await res.pipe(file.openWrite());
      rendered++;
      stdout.writeln('✓ ${story.lang} ${file.path.split('/').last}  ${line.length > 60 ? '${line.substring(0, 60)}…' : line}');
    }
  }
  client.close();

  if (prune) {
    for (final e in wanted.entries) {
      for (final f in Directory('assets/audio/${e.key}').listSync().whereType<File>()) {
        if (f.path.endsWith('.mp3') && !e.value.contains(f.path)) {
          f.deleteSync();
          stdout.writeln('pruned ${f.path}');
        }
      }
    }
  }
  stdout.writeln('Lines: ${wanted.values.fold<int>(0, (a, s) => a + s.length)}, characters: $totalChars, '
      'still to render: $newChars characters${dry ? ' (dry run)' : ', rendered $rendered clips'}.');
}
