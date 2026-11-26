import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Stable file name for a pre-recorded narrator line. The generator and the
/// app both use this, so a line finds its clip as long as the text matches.
String clipKey(String lang, String text) =>
    sha1.convert(utf8.encode('$lang\n${text.trim()}')).toString().substring(0, 16);

String clipAsset(String lang, String text) => 'assets/audio/$lang/${clipKey(lang, text)}.mp3';
