import 'dart:async';

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
  Completer<List<String>?>? _listening;
  String _partial = '';

  @override
  Future<void> init(String speechLocale) async {
    _locale = speechLocale;

    // Spoken-audio session: plays through Bluetooth / CarPlay car audio,
    // ducks other apps, and keeps running with the screen off
    // (UIBackgroundModes=audio on iOS).
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
        usage: AndroidAudioUsage.assistanceNavigationGuidance,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
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
    await _tts.setSpeechRate(0.48);
    _tts.setCompletionHandler(_doneSpeaking);
    _tts.setCancelHandler(_doneSpeaking);
    _tts.setErrorHandler((_) => _doneSpeaking());

    _sttReady = await _stt.initialize(
      onError: (_) => _finishListening(_partial.isEmpty ? null : [_partial]),
      onStatus: (s) {
        if (s == SpeechToText.doneStatus || s == SpeechToText.notListeningStatus) {
          // Give a final result a moment to arrive before giving up.
          Future.delayed(const Duration(milliseconds: 400),
              () => _finishListening(_partial.isEmpty ? null : [_partial]));
        }
      },
    );
  }

  bool get canListen => _sttReady;

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
  Future<List<String>?> listen({Duration timeout = const Duration(seconds: 9)}) async {
    if (!_sttReady) return null;
    final result = _listening = Completer<List<String>?>();
    _partial = '';
    await _stt.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        localeId: _locale.replaceAll('-', '_'),
        listenFor: timeout,
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      ),
    );
    return result.future.timeout(timeout + const Duration(seconds: 3), onTimeout: () => null);
  }

  void _onResult(SpeechRecognitionResult r) {
    _partial = r.recognizedWords;
    if (r.finalResult) {
      _finishListening([for (final a in r.alternates) a.recognizedWords]);
    }
  }

  void _finishListening(List<String>? alts) {
    final c = _listening;
    if (c != null && !c.isCompleted) c.complete(alts);
  }

  @override
  Future<void> cancelListening() async {
    if (_stt.isListening) await _stt.cancel();
    _finishListening(null);
  }
}
