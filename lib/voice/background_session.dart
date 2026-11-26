import 'dart:io' show Platform;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Keeps a story session alive with the screen off or another app (e.g.
/// navigation) in front.
///
/// Android: a foreground service of type microphone + mediaPlayback, with an
/// ongoing notification. Without it Android cuts microphone access as soon
/// as the app leaves the screen.
/// iOS: nothing to start here. The `audio` background mode in Info.plist plus
/// the active playAndRecord audio session keep narration and listening
/// running while the session is in progress.
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
  static Future<void> start({required String title, required String text}) async {
    if (!Platform.isAndroid) return;
    _init();
    try {
      if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(notificationTitle: title, notificationText: text);
      } else {
        await FlutterForegroundTask.startService(
          serviceTypes: [ForegroundServiceTypes.microphone, ForegroundServiceTypes.mediaPlayback],
          notificationTitle: title,
          notificationText: text,
        );
      }
    } catch (_) {
      // Playing still works in the foreground; only screen-off play is lost.
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) await FlutterForegroundTask.stopService();
    } catch (_) {}
  }
}
