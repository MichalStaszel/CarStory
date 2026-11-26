/// The narrator's mouth and ears. The game engine only talks to this
/// interface, so it runs the same with device speech, a cloud voice, or a
/// scripted fake in tests.
abstract interface class VoiceIO {
  Future<void> init(String speechLocale);

  /// Speaks [text] and completes when it has been spoken or was stopped.
  Future<void> speak(String text);

  /// Stops narration early (the player tapped to answer).
  Future<void> stopSpeaking();

  /// Narration speed, 1.0 = normal. Applies to clips and device voice.
  Future<void> setRate(double rate);

  /// Listens for one answer. Returns the transcriptions, best first, or null
  /// when nothing was said before [timeout].
  ///
  /// [acceptEarly] is checked on every partial result; when it returns true
  /// the answer is taken at once instead of waiting for the speaker to
  /// finish, which makes "A", "B", "C" feel instant. [hints] are phrases the
  /// recognizer should expect (letters and option labels).
  Future<List<String>?> listen({
    Duration timeout,
    bool Function(List<String> alternatives)? acceptEarly,
    List<String> hints,
  });

  Future<void> cancelListening();
}
