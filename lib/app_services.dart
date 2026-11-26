import 'dart:ui' show PlatformDispatcher;

import 'data/stores.dart';
import 'engine/phrases.dart';
import 'models/story.dart';
import 'voice/device_voice.dart';
import 'voice/premium_voice.dart';
import 'voice/voice_io.dart';

/// App-wide objects, created once at startup.
class AppServices {
  AppServices._(this.stories, this.store, this.lang);

  final List<Story> stories;
  final ProgressStore store;
  String lang;
  final Map<String, Future<VoiceIO>> _voices = {};

  static Future<AppServices> load() async {
    final stories = await StoryRepository().loadAll();
    final store = await ProgressStore.open();
    final device = PlatformDispatcher.instance.locale.languageCode;
    return AppServices._(stories, store, store.language ?? (device == 'pl' ? 'pl' : 'en'));
  }

  Phrases get phrases => Phrases.forLang(lang);

  Future<void> setLanguage(String l) async {
    lang = l;
    await store.setLanguage(l);
  }

  /// One voice per language, initialized on first use.
  Future<VoiceIO> voiceFor(String l) => _voices[l] ??= () async {
        final v = PremiumVoice(l, DeviceVoice());
        await v.init(Phrases.forLang(l).speechLocale);
        return v;
      }();
}
