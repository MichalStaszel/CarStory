import 'package:flutter/foundation.dart';

/// A short rolling log of what the voice layer is doing (recognizer errors,
/// background service state). Shown in the driving screen's test panel so a
/// tester can say exactly what went wrong on their phone.
class VoiceLog {
  VoiceLog._();
  static final ValueNotifier<List<String>> entries = ValueNotifier(const []);

  static void add(String line) {
    final t = DateTime.now();
    final stamp = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
    final next = ['$stamp $line', ...entries.value];
    entries.value = next.length > 30 ? next.sublist(0, 30) : next;
    debugPrint('[voice] $line');
  }
}
