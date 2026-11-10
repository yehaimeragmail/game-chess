/// Persisted settings + club record for Chess. Survives app restarts.
///
/// Stores: audio toggles, renameable player names (White/Black slots),
/// board theme + piece style, game-mode setup (mode, bot difficulty, side,
/// chess clock), and the lifetime vs-computer tally.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/chess_themes.dart';

class ChessSettings extends ChangeNotifier {
  static const _kMusic = 'chess_music_on';
  static const _kSfx = 'chess_sfx_on';
  static const _kVolume = 'chess_volume';
  static const _kDifficulty = 'chess_bot_difficulty'; // 0 easy, 1 medium, 2 hard
  static const _kMode = 'chess_mode'; // 0 vs bot, 1 two players
  static const _kBotWhite = 'chess_bot_plays_white';
  static const _kClock = 'chess_clock_seconds'; // 0 off, else 60/180/300/600
  static const _kNames =
      'chess_player_names_json'; // JSON string [white, black].
  // NOTE: player names used to be stored with setStringList, but on Android
  // SharedPreferences string lists are backed by an UNORDERED StringSet —
  // White/Black names came back scrambled across slots after a restart.
  // Names are now persisted as an order-preserving JSON string.
  static const _kTheme = 'chess_theme_id';
  static const _kPieceStyle = 'chess_piece_style'; // 0 classic, 1 modern, 2 ornate
  static const _kWins = 'chess_wins';
  static const _kLosses = 'chess_losses';
  static const _kDraws = 'chess_draws';
  static const _kIsPro = 'chess_is_pro';

  static const defaultNames = ['White', 'Black'];

  static const difficultyLabels = ['Casual', 'Club Player', 'Grandmaster'];
  static const difficultyBlurbs = [
    'Relaxed — the bot plays friendly, human moves.',
    'A proper fight. Thinks a few moves deep.',
    'No mercy. Deep search, sharp tactics.',
  ];
  static const clockOptions = [0, 60, 180, 300, 600];
  static const clockLabels = ['No clock', '1 min', '3 min', '5 min', '10 min'];

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  int difficulty = 1;
  int mode = 0;
  bool botPlaysWhite = false;
  int clockSeconds = 0;
  List<String> playerNames = List.of(defaultNames);
  String themeId = 'heritage';
  int pieceStyle = 0;
  int wins = 0;
  int losses = 0;
  int draws = 0;
  bool isPro = false;

  SharedPreferences? _prefs;

  /// Loads persisted settings. If storage is unavailable (or a stored
  /// value is unreadable), keeps the in-memory defaults and launches
  /// anyway — the game must never crash on startup. Stays in-memory-only
  /// for the session (no persistence) so partial defaults never overwrite
  /// good stored data.
  Future<void> load() async {
    try {
      await _loadUnsafe();
    } catch (_) {
      _prefs = null;
    }
  }

  Future<void> _loadUnsafe() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    difficulty = (p.getInt(_kDifficulty) ?? 1).clamp(0, 2);
    mode = (p.getInt(_kMode) ?? 0).clamp(0, 1);
    botPlaysWhite = p.getBool(_kBotWhite) ?? false;
    clockSeconds = p.getInt(_kClock) ?? 0;
    if (!clockOptions.contains(clockSeconds)) clockSeconds = 0;
    final rawNames = p.getString(_kNames);
    if (rawNames != null) {
      try {
        final names = (jsonDecode(rawNames) as List)
            .map((e) => e.toString())
            .toList();
        if (names.length == 2) {
          playerNames = [
            for (int i = 0; i < 2; i++)
              names[i].trim().isEmpty ? defaultNames[i] : names[i].trim()
          ];
        }
      } catch (_) {
        // Corrupt entry — keep defaults.
      }
    } else {
      // One-time migration from the old unordered StringList storage.
      final legacy = p.getStringList('chess_player_names');
      if (legacy != null && legacy.length == 2) {
        playerNames = [
          for (int i = 0; i < 2; i++)
            legacy[i].trim().isEmpty ? defaultNames[i] : legacy[i].trim()
        ];
        await p.remove('chess_player_names');
        await p.setString(_kNames, jsonEncode(playerNames));
      }
    }
    themeId = p.getString(_kTheme) ?? 'heritage';
    pieceStyle = (p.getInt(_kPieceStyle) ?? 0).clamp(0, 2);
    wins = p.getInt(_kWins) ?? 0;
    losses = p.getInt(_kLosses) ?? 0;
    draws = p.getInt(_kDraws) ?? 0;
    isPro = p.getBool(_kIsPro) ?? false;
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setInt(_kDifficulty, difficulty);
    await p.setInt(_kMode, mode);
    await p.setBool(_kBotWhite, botPlaysWhite);
    await p.setInt(_kClock, clockSeconds);
    await p.setString(_kNames, jsonEncode(playerNames));
    await p.setString(_kTheme, themeId);
    await p.setInt(_kPieceStyle, pieceStyle);
    await p.setInt(_kWins, wins);
    await p.setInt(_kLosses, losses);
    await p.setInt(_kDraws, draws);
    await p.setBool(_kIsPro, isPro);
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  /// Called after load and whenever Pro status could have changed.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (ChessThemes.isProTheme(themeId)) {
      themeId = 'heritage';
      changed = true;
    }
    if (pieceStyle > 0) {
      pieceStyle = 0;
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (changed) {
      if (!silent) notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setDifficulty(int v) async {
    v = v.clamp(0, 2);
    // Grandmaster (2) is a PRO difficulty; the UI routes free users to the
    // PRO screen, this clamp is the backstop.
    if (!isPro && v > 1) v = 1;
    difficulty = v;
    notifyListeners();
    await _save();
  }

  Future<void> setMode(int v) async {
    mode = v.clamp(0, 1);
    notifyListeners();
    await _save();
  }

  Future<void> setBotPlaysWhite(bool v) async {
    botPlaysWhite = v;
    notifyListeners();
    await _save();
  }

  Future<void> setClockSeconds(int v) async {
    clockSeconds = clockOptions.contains(v) ? v : 0;
    notifyListeners();
    await _save();
  }

  /// Renameable players: slot 0 = White, 1 = Black. Persisted.
  Future<void> setPlayerName(int slot, String name) async {
    if (slot < 0 || slot > 1) return;
    final clean = name.trim();
    playerNames[slot] =
        clean.isEmpty ? defaultNames[slot] : clean.substring(0, 18);
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    // Pro-only themes require Pro; silently ignore otherwise (UI shows lock).
    if (!isPro && ChessThemes.isProTheme(id)) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setPieceStyle(int v) async {
    v = v.clamp(0, 2);
    // Styles 1-2 (Modern Minimal, Ornate Royal) are PRO; UI shows the lock.
    if (!isPro && v > 0) return;
    pieceStyle = v;
    notifyListeners();
    await _save();
  }

  /// Record a finished vs-computer game. In two-player games both sides are
  /// human, so only draws are tallied there.
  Future<void> recordGame(
      {required bool humanWon, required bool draw}) async {
    if (draw) {
      draws++;
    } else if (humanWon) {
      wins++;
    } else {
      losses++;
    }
    notifyListeners();
    await _save();
  }
}

/// Persists an in-progress game so backgrounding / app kill restores exactly
/// (RULES.md §12 edge cases).
class GameStore {
  static const _key = 'chess_saved_game';

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
}
