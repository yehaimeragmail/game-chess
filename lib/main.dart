/// Chess — Grand Chess Heritage edition.
/// Stitch visual source of truth: stitch-batch1/chess/DESIGN.md
/// Rules: stitch-batch1/chess/RULES.md
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'audio.dart';
import 'screens/menu.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await AudioService.I.init();
  runApp(const ChessApp());
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: ChessPalette.walnutDeep,
        colorScheme: const ColorScheme.dark(
          primary: ChessPalette.brass,
          onPrimary: ChessPalette.onBrass,
          surface: ChessPalette.walnutDark,
          onSurface: ChessPalette.ivory,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: ChessPalette.walnutDark,
          foregroundColor: ChessPalette.ivory,
          elevation: 0,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const MenuScreen(),
    );
  }
}
