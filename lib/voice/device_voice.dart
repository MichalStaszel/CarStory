import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_session/audio_session.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'voice_io.dart';

/// Free, on-device voice: the phone's own text-to-speech and speech
/// recognition. Narration of authored text works offline. Recognition is
/// offline where the OS has an on-device model for the language (recent
/// iOS, most Android phones with Google speech services), otherwise online.
class DeviceVoice implements VoiceIO {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  String _locale = 'en-US';
  bool _sttReady = false;

  Completer<void>? _speaking;
  Completer<List<String>?>? _attempt;
  bool _cancelled = false;
  String _partial = '';
  bool Function(List<String>)? _acceptEarly;

  @override
  Future<void> init(String speechLocale) async {
    _locale = speechLocale;

    // Spoken-audio session: plays through Bluetooth / CarPlay car audio,
    // ducks other apps (music, and shares the speaker with navigation
    // prompts), and keeps running with the screen off.
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth |
          AVAudioSessionCategoryOptions.allowBluetoothA2dp |
          AVAudioSessionCategoryOptions.defaultToSpeaker |
          AVAudioSessionCategoryOptions.duckOthers,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      androidWillPauseWhenDucked: false,
    ));
    await session.setActive(true);

    await _tts.setSharedInstance(true);
    await _tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playAndRecord,
      [
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        IosTextToSpeechAudioCategoryOptions.duckOthers,
      ],
      IosTextToSpeechAudioMode.spokenAudio,
    );
    await _tts.setLanguage(speechLocale);
    await setRate(1.0);
    _tts.setCompletionHandler(_doneSpeaking);
    _tts.setCancelHandler(_doneSpeaking);
    _tts.setErrorHandler((_) => _doneSpeaking());

    _sttReady = await _stt.initialize(
      // "No match", "speech timeout" and similar end only this attempt;
      // [listen] immediately starts another one until its time is up.
      onError: (_) => _endAttempt(_partial.isEmpty ? null : [_partial]),
      onStatus: (s) {
        if (s == SpeechToText.doneStatus) _endAttempt(_partial.isEmpty ? null : [_partial]);
      },
    );
  }

  bool get canListen => _sttReady;

  @override
  Future<void> setRate(double rate) async {
    // flutter_tts scales differently per platform: on Android 0.5 is the
    // engine's normal speed (it doubles the value), on iOS 0.5 is
    // AVSpeechUtteranceDefaultSpeechRate and the curve is steeper.
    final value = Platform.isIOS ? (0.5 + (rate - 1) * 0.25).clamp(0.3, 0.75) : (0.5 * rate).clamp(0.25, 1.5);
    await _tts.setSpeechRate(value.toDouble());
  }

  @override
  Future<void> speak(String text) async {
    final done = _speaking = Completer<void>();
    await _tts.speak(text);
    // Safety net in case the platform never reports completion.
    final words = text.split(' ').length;
    await done.future.timeout(Duration(seconds: 5 + (words * 0.6).round()), onTimeout: () {});
  }

  void _doneSpeaking() {
    final c = _speaking;
    if (c != null && !c.isCompleted) c.complete();
  }

  @override
  Future<void> stopSpeaking() async {
    await _tts.stop();
    _doneSpeaking();
  }

  @override
  Future<List<String>?> listen({
    Duration timeout = const Duration(seconds: 9),
    bool Function(List<String>)? acceptEarly,
    List<String> hints = const [],
  }) async {
    if (!_sttReady) return null;
    _cancelled = false;
    _acceptEarly = acceptEarly;
    final deadline = DateTime.now().add(timeout);
    // Keep listening in short attempts until something usable is heard or
    // time runs out. A misheard or empty attempt restarts silently, so the
    // player can simply say it again without the narrator interrupting.
    while (!_cancelled) {
      final left = deadline.difference(DateTime.now());
      if (left < const Duration(milliseconds: 800)) break;
      final heard = await _listenOnce(left, hints);
      if (_cancelled) return null;
      if (heard != null && heard.any((h) => h.trim().isNotEmpty)) return heard;
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    return null;
  }

  Future<List<String>?> _listenOnce(Duration left, List<String> hints) async {
    final attempt = _attempt = Completer<List<String>?>();
    _partial = '';
    try {
      await _stt.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          localeId: _locale.replaceAll('-', '_'),
          listenFor: left,
          pauseFor: const Duration(milliseconds: 1200),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
          contextualPhrases: hints,
        ),
      );
    } catch (_) {
      _endAttempt(null);
    }
    return attempt.future.timeout(left + const Duration(seconds: 2), onTimeout: () => null);
  }

  void _onResult(SpeechRecognitionResult r) {
    final alts = [for (final a in r.alternates) a.recognizedWords];
    _partial = r.recognizedWords;
    if (r.finalResult) {
      _endAttempt(alts);
    } else if (_acceptEarly?.call(alts) ?? false) {
      // A clear "B" is enough: take it now and stop the recognizer.
      _endAttempt(alts);
      unawaited(_stt.cancel());
    }
  }

  void _endAttempt(List<String>? alts) {
    final c = _attempt;
    if (c != null && !c.isCompleted) c.complete(alts);
  }

  @override
  Future<void> cancelListening() async {
    _cancelled = true;
    if (_stt.isListening) await _stt.cancel();
    _endAttempt(null);
  }
}
