import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/progress.dart';
import '../models/story.dart';

/// Bundled stories. They ship inside the app, so playing never needs a
/// network connection.
class StoryRepository {
  static const files = [
    'assets/stories/room-312.en.json',
    'assets/stories/pokoj-312.pl.json',
  ];

  Future<List<Story>> loadAll() async => [
        for (final f in files) Story.fromJson(jsonDecode(await rootBundle.loadString(f)) as Map<String, dynamic>),
      ];
}

/// Saves each story's progress on the device.
class ProgressStore {
  ProgressStore(this._prefs);
  final SharedPreferences _prefs;

  static Future<ProgressStore> open() async => ProgressStore(await SharedPreferences.getInstance());

  String _key(Story s) => 'progress.${s.id}';

  Progress load(Story s) {
    final raw = _prefs.getString(_key(s));
    if (raw == null) return Progress.fresh(s);
    try {
      return Progress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return Progress.fresh(s);
    }
  }

  bool hasSave(Story s) => _prefs.containsKey(_key(s));

  Future<void> save(Story s, Progress p) => _prefs.setString(_key(s), jsonEncode(p.toJson()));

  Future<void> reset(Story s) => _prefs.remove(_key(s));

  String? get language => _prefs.getString('language');
  Future<void> setLanguage(String lang) => _prefs.setString('language', lang);
}
