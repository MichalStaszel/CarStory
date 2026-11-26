/// The narrator's mouth and ears. The game engine only talks to this
/// interface, so it runs the same with device speech, a cloud voice, or a
/// scripted fake in tests.
abstract interface class VoiceIO {
  Future<void> init(String speechLocale);

  /// Speaks [text] and completes when it has been spoken or was stopped.
  Future<void> speak(String text);

  /// Stops narration early (the player tapped to answer).
  Future<void> stopSpeaking();

  /// Listens for one answer. Returns the transcriptions, best first, or null
  /// on silence.
  Future<List<String>?> listen({Duration timeout});

  Future<void> cancelListening();
}
