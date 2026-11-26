import 'package:material_ui/material_ui.dart';

/// Noir palette: lamp-lit amber on near-black, brick red for action.
class Noir {
  static const ink = Color(0xFF0E0C0B);
  static const panel = Color(0xFF1E1A17);
  static const line = Color(0xFF352E28);
  static const paper = Color(0xFFEFE5D6);
  static const dim = Color(0xFFA3968A);
  static const brick = Color(0xFFD0603F);
  static const amber = Color(0xFFD6A640);

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brick,
      brightness: Brightness.dark,
      surface: ink,
      primary: brick,
      secondary: amber,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: ink,
      fontFamily: 'Georgia',
      appBarTheme: const AppBarTheme(backgroundColor: ink, foregroundColor: paper, elevation: 0),
      cardTheme: CardThemeData(
        color: panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: line)),
        margin: const EdgeInsets.only(bottom: 12),
      ),
    );
  }
}
