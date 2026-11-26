# Road Stories

Interactive audiobooks for the drive. A narrator tells a story, asks
"What do you do?", and you answer out loud with A, B, C or your own words.
Hands-free while driving; after the session, a case file shows your progress,
checkpoints, clues, items and a painted portrait of your character.

Flutter app for iOS and Android. English and Polish.

## Run

```sh
flutter pub get
flutter run            # on a phone; speech needs a real device
flutter test           # engine, interpreter and story checks
```

## How it fits together

| Path | What it is |
| --- | --- |
| `assets/stories/*.json` | Authored stories (one file per language). Shared format with the browser prototype. |
| `lib/models/story.dart` | Story model and `validate()` (broken links, dead ends, unreachable scenes). |
| `lib/engine/game_engine.dart` | The session loop: narrate, listen, interpret, apply clues/items/flags, checkpoints, soft-fail rewind. Pure Dart, tested with a scripted voice. |
| `lib/engine/interpreter.dart` | Turns speech into a choice: letters ("bee", "option c"), ordinals, keywords, voice commands. `FreeformResolver` is the hook for AI free-form mode later. |
| `lib/engine/phrases.dart` | Everything the narrator says outside the story, plus recognized words, per language. |
| `lib/voice/premium_voice.dart` | Plays the bundled narrator clip for each line; falls back to the phone's own voice. |
| `lib/voice/device_voice.dart` | On-device TTS and speech recognition, car-audio session (Bluetooth / CarPlay, ducking, background). |
| `lib/ui/` | Library, driving mode (one big button), case file with `PortraitPainter`. |
| `tool/generate_audio.dart` | Renders every narrator line to an MP3 with a premium voice (ElevenLabs). |

### Story format

Each node has `text` (second person, present tense, so it never needs the
player's gender), optional `checkpoint`, `effects` (`clue`, `item`, `flag`),
and either `choices` (A/B/C with `kw` keyword stems) or `next`. `fail: true`
narrates and rewinds to the last checkpoint. Text can branch on what the
player has with `{flag?if set:otherwise}`.

### Premium narration

Clips are generated ahead of time and shipped inside the app, so narration
works with no signal. Each line's file name is a hash of its text
(`lib/voice/clips.dart`), so editing a line only re-renders that line.

```sh
dart run tool/generate_audio.dart --dry-run          # count characters
ELEVENLABS_API_KEY=... ELEVENLABS_VOICE_EN=<voice id> ELEVENLABS_VOICE_PL=<voice id> \
  dart run tool/generate_audio.dart --prune
```

Room 312 is about 12,800 characters per language (236 lines for both).
Lines without a clip are read by the phone's voice, so the app works before
any clips exist.
