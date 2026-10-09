/// AudioService — chess-club soundscape.
/// SFX + looping music via audioplayers, with music/SFX toggles and volume.
/// Assets are synthesized (see /tmp/gen_chess_audio.py), matching the
/// physical identity: wooden knocks, brass chimes, warm ambient pads.
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static final AudioService I = AudioService._();
  AudioService._();

  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    final p = await SharedPreferences.getInstance();
    musicOn = p.getBool('musicOn') ?? true;
    sfxOn = p.getBool('sfxOn') ?? true;
    volume = p.getDouble('volume') ?? 0.8;
    await _music.setReleaseMode(ReleaseMode.loop);
    _ready = true;
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('musicOn', musicOn);
    await p.setBool('sfxOn', sfxOn);
    await p.setDouble('volume', volume);
  }

  Future<void> setMusic(bool on) async {
    musicOn = on;
    await _persist();
    if (!on) {
      await _music.stop();
    }
  }

  Future<void> setSfx(bool on) async {
    sfxOn = on;
    await _persist();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    await _persist();
    await _music.setVolume(volume * 0.6);
    await _sfx.setVolume(volume);
  }

  Future<void> _playSfx(String file) async {
    if (!sfxOn) return;
    try {
      await _sfx.setVolume(volume);
      await _sfx.play(AssetSource('sounds/$file'));
    } catch (_) {}
  }

  // ---- SFX ----
  Future<void> click() => _playSfx('button_click.wav');
  Future<void> move() => _playSfx('piece_move.wav');
  Future<void> capture() => _playSfx('capture.wav');
  Future<void> check() => _playSfx('check_alert.wav');
  Future<void> castle() => _playSfx('castle.wav');
  Future<void> promote() => _playSfx('promotion.wav');
  Future<void> gameStart() => _playSfx('game_start.wav');
  Future<void> win() => _playSfx('win.wav');
  Future<void> lose() => _playSfx('lose.wav');
  Future<void> invalid() => _playSfx('invalid.wav');
  Future<void> draw() => _playSfx('draw.wav');

  // ---- Music ----
  Future<void> menuMusic() async {
    if (!musicOn) return;
    try {
      await _music.setVolume(volume * 0.6);
      await _music.play(AssetSource('music/menu_music.wav'));
    } catch (_) {}
  }

  Future<void> gameMusic() async {
    if (!musicOn) return;
    try {
      await _music.setVolume(volume * 0.5);
      await _music.play(AssetSource('music/game_music.wav'));
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    try {
      await _music.stop();
    } catch (_) {}
  }

  void dispose() {
    _sfx.dispose();
    _music.dispose();
  }
}
