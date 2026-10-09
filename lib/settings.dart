/// Game settings + persistence for Chess.
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum Difficulty { easy, medium, hard }

extension DifficultyLabel on Difficulty {
  String get label => switch (this) {
        Difficulty.easy => 'Casual',
        Difficulty.medium => 'Club Player',
        Difficulty.hard => 'Grandmaster',
      };
  String get blurb => switch (this) {
        Difficulty.easy => 'Relaxed — the bot plays friendly, human moves.',
        Difficulty.medium => 'A proper fight. Thinks a few moves deep.',
        Difficulty.hard => 'No mercy. Deep search, sharp tactics.',
      };
}

enum GameMode { vsBot, twoPlayer }

class GameSettings {
  Difficulty difficulty;
  GameMode mode;
  bool botPlaysWhite; // false = human is White (default)

  GameSettings({
    this.difficulty = Difficulty.medium,
    this.mode = GameMode.vsBot,
    this.botPlaysWhite = false,
  });

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('difficulty', difficulty.index);
    await p.setInt('mode', mode.index);
    await p.setBool('botPlaysWhite', botPlaysWhite);
  }

  static Future<GameSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return GameSettings(
      difficulty: Difficulty.values[p.getInt('difficulty') ?? 1],
      mode: GameMode.values[p.getInt('mode') ?? 0],
      botPlaysWhite: p.getBool('botPlaysWhite') ?? false,
    );
  }
}

/// Persists an in-progress game so backgrounding/resume restores exactly.
class GameStore {
  static const _key = 'savedGame';

  static Future<void> save(Map<String, dynamic> state) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(state));
  }

  static Future<Map<String, dynamic>?> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }

  static Future<void> saveScore(int wins, int losses, int draws) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('w', wins);
    await p.setInt('l', losses);
    await p.setInt('d', draws);
  }

  static Future<(int, int, int)> loadScore() async {
    final p = await SharedPreferences.getInstance();
    return (p.getInt('w') ?? 0, p.getInt('l') ?? 0, p.getInt('d') ?? 0);
  }
}
