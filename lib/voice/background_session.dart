import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:just_audio/just_audio.dart';

import 'voice_log.dart';

/// Keeps a story session alive with the screen off or another app (e.g.
/// navigation) in front.
///
/// Android: a foreground service of type microphone + mediaPlayback, with an
/// ongoing notification. Without it Android cuts microphone access as soon
/// as the app leaves the screen.
/// iOS: the `audio` background mode keeps the app running only while its
/// audio session is active. The speech recognizer deactivates the session
/// every time it stops listening, and iOS then suspends a backgrounded app
/// before the narrator can speak again. A silent loop keeps the session
/// playing for the whole story, so iOS never sees the app go quiet.
class BackgroundSession {
  static bool _initialized = false;

  static void _init() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'story_session',
        channelName: 'Story in progress',
        channelDescription: 'Shown while a story is playing so it keeps going with the screen off.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    _initialized = true;
  }

  /// Call after the microphone permission was granted (Android 14 requires it
  /// before a microphone-type service may start).
  static AudioPlayer? _keepAlive;

  static Future<void> start({required String title, required String text}) async {
    if (Platform.isIOS) return _startKeepAlive();
    if (!Platform.isAndroid) return;
    _init();
    try {
      if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      final ServiceRequestResult result;
      if (await FlutterForegroundTask.isRunningService) {
        result = await FlutterForegroundTask.updateService(notificationTitle: title, notificationText: text);
      } else {
        result = await FlutterForegroundTask.startService(
          serviceTypes: [ForegroundServiceTypes.microphone, ForegroundServiceTypes.mediaPlayback],
          notificationTitle: title,
          notificationText: text,
        );
      }
      // startService reports failure in its result instead of throwing.
      if (result is ServiceRequestFailure) {
        VoiceLog.add('background service FAILED: ${result.error}');
      } else {
        VoiceLog.add('background service running');
      }
    } catch (e) {
      // Playing still works in the foreground; only screen-off play is lost.
      VoiceLog.add('background service error: $e');
    }
  }

  static Future<void> _startKeepAlive() async {
    if (_keepAlive != null) return;
    try {
      final p = _keepAlive = AudioPlayer(handleInterruptions: false, handleAudioSessionActivation: false);
      await p.setAsset('assets/sound/silence.wav');
      await p.setLoopMode(LoopMode.one);
      unawaited(p.play());
      VoiceLog.add('background keep-alive running');
    } catch (e) {
      VoiceLog.add('background keep-alive error: $e');
    }
  }

  static Future<void> stop() async {
    final p = _keepAlive;
    _keepAlive = null;
    if (p != null) unawaited(p.dispose());
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) await FlutterForegroundTask.stopService();
    } catch (_) {}
  }
}
