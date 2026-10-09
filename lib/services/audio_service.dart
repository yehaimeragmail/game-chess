/// ChessAudio — the chess-club soundscape, synthesized in code.
///
/// Reliability design (mirrors the Ludo exemplar):
/// - Music/SFX clips are synthesized ONCE and cached; starting music never
///   blocks the UI thread after the first build.
/// - A [_musicBusy] guard serializes play/stop so rapid calls (menu in/out,
///   pause/resume, toggles) can never leave the player half-started.
/// - Lifecycle uses pause()/resume() so an interruption resumes exactly
///   where it left off instead of restarting or dying.
/// - Every public method catches player errors; audio can never crash the app.
/// - Call [prewarm] on the splash screen so the first note is instant.
library;

import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class ChessAudio {
  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  final Map<String, Uint8List> _cache = {};

  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  ChessAudio() {
    _music.setReleaseMode(ReleaseMode.loop);
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    volume = volume.clamp(0.0, 1.0);
    this.volume = volume;
    _music.setVolume(musicOn ? volume * 0.55 : 0.0);
    _sfx.setVolume(sfxOn ? volume : 0.0);
    if (!musicOn) stopMusic();
  }

  /// Pre-build music clips off the critical path. Safe to call any time.
  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0);
    final d = pow(1 - t, 2.2).toDouble();
    return a * d;
  }

  List<double> _tone(double freq, double secs,
      {double freqEnd = 0, double attack = 0.02, double harmonics = 0.25}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: attack) *
          (sin(ph) + harmonics * sin(2 * ph) + harmonics * 0.5 * sin(3 * ph));
    }
    return out;
  }

  /// Wooden piece knock: low thump + short click.
  List<double> _knock({double base = 210}) {
    final n = (_rate * 0.13).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.004) *
          (0.9 * sin(2 * pi * base * t) * exp(-t * 32) +
              0.45 * sin(2 * pi * base * 2 * t) * exp(-t * 60) +
              0.22 * (_rand.nextDouble() * 2 - 1) * exp(-t * 130));
    }
    return out;
  }

  List<double> _arp(List<double> freqs, double noteSecs, double gapSecs,
      {double harmonics = 0.3}) {
    final out = <double>[];
    for (final f in freqs) {
      out.addAll(_tone(f, noteSecs, harmonics: harmonics));
      out.addAll(List<double>.filled((_rate * gapSecs).round(), 0));
    }
    return out;
  }

  List<double> _padChord(List<double> freqs, double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      double v = 0;
      for (final f in freqs) {
        final t = i / _rate;
        v += sin(2 * pi * f * t) + 0.3 * sin(2 * pi * f * 2 * t);
      }
      v /= freqs.length * 1.3;
      final t = i / n;
      final swell = sin(pi * t.clamp(0.0, 1.0));
      out[i] = v * (0.35 + 0.65 * swell);
    }
    return out;
  }

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  Uint8List _menuBytes() => _clip('music_menu', () {
        // Warm low parlor pad: Dm – Bb – F – C, 16s loop.
        final seq = [
          [146.83, 174.61, 220.0], // Dm
          [116.54, 146.83, 174.61], // Bb
          [174.61, 220.0, 261.63], // F
          [130.81, 164.81, 196.0], // C
        ];
        final out = <double>[];
        for (final chord in seq) {
          out.addAll(_padChord(chord, 4.0));
        }
        return out;
      });

  Uint8List _gameBytes() => _clip('music_game', () {
        // Soft felted plucks over a low drone, 14s loop — quiet under play.
        final drone = _padChord([98.0, 146.83], 14.0);
        final plucks = [293.66, 349.23, 392.0, 440.0, 392.0, 349.23, 293.66, 261.63];
        final n = (_rate * 14).round();
        final out = List<double>.from(drone);
        for (int k = 0; k < plucks.length; k++) {
          final start = (n * k / plucks.length).round();
          final tone = _tone(plucks[k], 0.55, harmonics: 0.3);
          for (int i = 0; i < tone.length && start + i < n; i++) {
            out[start + i] += tone[i] * 0.28;
          }
        }
        return out;
      });

  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  /// Soft brass tick for UI.
  Future<void> click() => _play(_clip('click', () => _tone(1250, 0.05)));
  Future<void> select() => _play(_clip('select', () => _tone(880, 0.06)));
  Future<void> invalid() =>
      _play(_clip('invalid', () => _tone(150, 0.16, harmonics: 0.5)));
  Future<void> move() => _play(_clip('move', () => _knock(base: 210)));
  Future<void> capture() => _play(_clip('capture', () {
        final a = _knock(base: 190);
        final b = _tone(320, 0.2, freqEnd: 140);
        final out = List<double>.from(a);
        final off = (_rate * 0.05).round();
        for (int i = 0; i < b.length && off + i < out.length + 400; i++) {
          if (off + i >= out.length) {
            out.add(b[i] * 0.5);
          } else {
            out[off + i] += b[i] * 0.5;
          }
        }
        return out;
      }));
  Future<void> check() =>
      _play(_clip('check', () => _tone(880, 0.3, freqEnd: 1320)));
  Future<void> castle() => _play(_clip('castle', () {
        final a = _knock(base: 210);
        final b = _knock(base: 240);
        final out = List<double>.from(a);
        final off = (_rate * 0.11).round();
        for (int i = 0; i < b.length; i++) {
          if (off + i >= out.length) {
            out.add(b[i]);
          } else {
            out[off + i] += b[i];
          }
        }
        return out;
      }));
  Future<void> promote() => _play(_clip(
      'promote', () => _arp([523.25, 659.25, 783.99, 1046.5], 0.14, 0.02)));
  Future<void> gameStart() =>
      _play(_clip('start', () => _tone(330, 0.4, freqEnd: 660)));
  Future<void> win() => _play(_clip(
      'win', () => _arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.16, 0.03)));
  Future<void> lose() => _play(_clip(
      'lose', () => _arp([392.0, 329.63, 261.63, 196.0], 0.22, 0.04)));
  Future<void> draw() =>
      _play(_clip('draw', () => _arp([440.0, 440.0], 0.25, 0.08)));

  // ----------------------------------------------------------------- music
  /// Start (or keep) a music track. Serialized: overlapping calls collapse
  /// into one, and re-requesting the current track is a no-op that ensures
  /// it is actually audible.
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (!musicOn || _disposed) return;
    if (_musicBusy) return;
    if (_currentTrack == track) {
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    _musicBusy = true;
    try {
      await _music.stop();
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  Future<void> stopMusic() async {
    if (_disposed) return;
    for (int i = 0; i < 20 && _musicBusy; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  /// App went to background / interruption: pause (not stop) so we resume
  /// exactly where we left off.
  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  /// App came back: resume only if we paused it and music is still wanted.
  Future<void> onAppResumed() async {
    if (_disposed || !musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
    } catch (_) {}
  }
}
