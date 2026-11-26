import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_session/audio_session.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'voice_io.dart';
import 'voice_log.dart';

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
  bool _restartAtNewRate = false;
  int _spokenOffset = 0;
  bool _preferOnDevice = true;
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
    // Word positions while speaking, so a speed change can resume from the
    // current word instead of waiting for the next line.
    _tts.setProgressHandler((text, start, end, word) => _spokenOffset = start);
    _tts.setCompletionHandler(_doneSpeaking);
    _tts.setCancelHandler(_doneSpeaking);
    _tts.setErrorHandler((_) => _doneSpeaking());

    _sttReady = await _stt.initialize(
      // Use the phone's microphone. Routing the mic through the car's
      // Bluetooth hands-free profile switches the car into "phone call" mode
      // on every turn, which takes 1-2 s and swallows the first words.
      options: [SpeechToText.androidNoBluetooth, SpeechToText.iosNoBluetooth],
      // After the speaker stops, wait at most this long for the final text.
      finalTimeout: const Duration(milliseconds: 600),
      // "No match", "speech timeout" and similar end only this attempt;
      // [listen] immediately starts another one until its time is up.
      onError: (e) {
        VoiceLog.add('recognizer: ${e.errorMsg}');
        if (e.errorMsg.contains('language') && _preferOnDevice) {
          _preferOnDevice = false; // no offline model for this language
          VoiceLog.add('on-device recognition unavailable, using online');
        }
        _endAttempt(_partial.isEmpty ? null : [_partial]);
      },
      onStatus: (s) {
        if (s == SpeechToText.doneStatus) _endAttempt(_partial.isEmpty ? null : [_partial]);
      },
    );
    VoiceLog.add(_sttReady ? 'speech recognition ready ($speechLocale)' : 'speech recognition NOT available');
  }

  bool get canListen => _sttReady;

  double _rate = 1.0;

  @override
  Future<void> setRate(double rate) async {
    _rate = rate;
    await _tts.setSpeechRate(_engineRate(rate));
    // Apply right away: if a line is being read, stop and resume it from
    // the current word at the new speed.
    final speaking = _speaking;
    if (speaking != null && !speaking.isCompleted) {
      _restartAtNewRate = true;
      await _tts.stop();
      _doneSpeaking();
    }
  }

  // flutter_tts scales differently per platform: on Android 0.5 is the
  // engine's normal speed (it doubles the value), on iOS 0.5 is
  // AVSpeechUtteranceDefaultSpeechRate and the curve is steeper.
  double _engineRate(double rate) =>
      (Platform.isIOS ? (0.5 + (rate - 1) * 0.25).clamp(0.3, 0.75) : (0.5 * rate).clamp(0.25, 1.5)).toDouble();

  @override
  Future<void> speak(String text) async {
    var remaining = text;
    while (true) {
      _restartAtNewRate = false;
      _spokenOffset = 0;
      final done = _speaking = Completer<void>();
      await _tts.setSpeechRate(_engineRate(_rate));
      await _tts.speak(remaining);
      // Safety net in case the platform never reports completion.
      final words = remaining.split(' ').length;
      await done.future.timeout(Duration(seconds: 5 + (words * 0.6 / _rate).round()), onTimeout: () {});
      if (!_restartAtNewRate) return;
      remaining = remaining.substring(_spokenOffset.clamp(0, remaining.length));
      if (remaining.trim().isEmpty) return;
    }
  }

  void _doneSpeaking() {
    final c = _speaking;
    if (c != null && !c.isCompleted) c.complete();
  }

  @override
  Future<void> stopSpeaking() async {
    _restartAtNewRate = false;
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
      await Future<void>.delayed(const Duration(milliseconds: 60));
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
          // On-device models answer faster and work without signal; fall
          // back to online when the language isn't installed.
          onDevice: _preferOnDevice,
        ),
      );
    } catch (e) {
      VoiceLog.add('listen failed: $e');
      if (_preferOnDevice) {
        // iOS throws when the phone has no offline model; retry online.
        _preferOnDevice = false;
        VoiceLog.add('switching to online recognition');
      }
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
