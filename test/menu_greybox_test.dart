// Diagnostic / regression test for the iOS menu grey box (Nov 2026).
//
// On her iPhone 12 the Chess menu paints the top (logo, title, record,
// PLAY VS COMPUTER) and then a flat light-grey rectangle covers the whole
// lower menu. That grey is Flutter's release-mode RenderErrorBox
// (background 0xF0C0C0C0, composited over the dark scaffold bg it measures
// exactly #B5B5B5, the colour sampled from her screenshot). A RenderErrorBox
// sizes itself to 100000pt tall inside a scroll view, so ONE child of the
// menu Column throwing during build greys out everything below it.
// These tests pump the REAL MenuScreen with realistic saved preferences
// (including edge values a real phone can hold) and fail if any child
// throws (ErrorWidget in the tree / tester.takeException() != null).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess/main.dart';
import 'package:chess/screens/menu_screen.dart';
import 'package:chess/services/audio_service.dart';
import 'package:chess/services/settings_service.dart';
import 'package:chess/theme.dart';
import 'package:chess/theme/chess_themes.dart';

void _mockAudioChannels() {
  const player = MethodChannel('xyz.luan/audioplayers');
  const global = MethodChannel('xyz.luan/audioplayers.global');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(player, (call) async => null);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(global, (call) async => null);
}

void _unmockAudioChannels() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'),
        null,
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'),
        null,
      );
}

Future<(ChessSettings, ChessAudio)> _loadSettings(
  Map<String, Object> prefs,
) async {
  SharedPreferences.setMockInitialValues(prefs);
  final settings = ChessSettings();
  await settings.load();
  final audio = ChessAudio();
  return (settings, audio);
}

Widget _menuApp(ChessSettings settings, ChessAudio audio) => MaterialApp(
  theme: ChessType.themeData(ChessThemes.byId(settings.themeId)),
  home: MenuScreen(audio: audio, settings: settings),
);

void _expectMenuClean(WidgetTester tester, {bool pro = false}) {
  expect(tester.takeException(), isNull);
  expect(find.byType(ErrorWidget), findsNothing);
  expect(find.text('PLAY VS COMPUTER'), findsOneWidget);
  expect(find.text('TWO PLAYERS'), findsOneWidget);
  expect(find.text('SETTINGS'), findsOneWidget);
  expect(find.text(pro ? 'CHESS PRO ✓' : 'CHESS PRO'), findsOneWidget);
  expect(find.text('Share'), findsOneWidget);
  expect(find.text('Rate'), findsOneWidget);
}

void main() {
  setUp(_mockAudioChannels);
  tearDown(_unmockAudioChannels);

  testWidgets('menu builds clean with fresh defaults (iPhone 12 size)',
      (tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final (settings, audio) = await _loadSettings({});
        await tester.pumpWidget(_menuApp(settings, audio));
        await tester.pumpAndSettle();
        _expectMenuClean(tester);
        expect(find.text('Club Player bot'), findsOneWidget);
        expect(find.text('You play White'), findsOneWidget);
        expect(find.text('no clock'), findsOneWidget);
        expect(find.text('Free forever'), findsOneWidget);
      });

  testWidgets('menu builds clean with edge saved values', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Values a real phone can hold: out-of-range difficulty, a clock value
    // not in clockOptions, an unknown theme id, pro theme while not pro,
    // pro user with pro theme, wins/losses/draws, bot plays white.
    final (settings, audio) = await _loadSettings({
      'chess_bot_difficulty': 5,
      'chess_clock_seconds': 120,
      'chess_theme_id': 'bogus_theme',
      'chess_piece_style': 9,
      'chess_wins': 12,
      'chess_losses': 3,
      'chess_draws': 1,
      'chess_bot_plays_white': true,
    });
    await tester.pumpWidget(_menuApp(settings, audio));
    await tester.pumpAndSettle();
    _expectMenuClean(tester);
  });

  testWidgets('menu builds clean for a Pro user on a Pro theme',
      (tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final (settings, audio) = await _loadSettings({
          'chess_is_pro': true,
          'chess_theme_id': 'emerald',
          'chess_bot_difficulty': 2,
          'chess_clock_seconds': 300,
          'chess_piece_style': 2,
        });
        await tester.pumpWidget(_menuApp(settings, audio));
        await tester.pumpAndSettle();
        _expectMenuClean(tester, pro: true);
        expect(find.text('Grandmaster bot'), findsOneWidget);
        expect(find.text('5 min'), findsOneWidget);
        expect(find.text('CHESS PRO ✓'), findsOneWidget);
        expect(find.text('✦ PRO'), findsOneWidget);
      });

  testWidgets('menu with an unfinished saved game shows the resume dialog',
      (tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final (settings, audio) = await _loadSettings({
          'chess_saved_game': jsonEncode({
            'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
            'moves': <String>[],
          }),
        });
        await tester.pumpWidget(_menuApp(settings, audio));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
        expect(find.text('Resume game?'), findsOneWidget);
        expect(find.text('RESUME'), findsOneWidget);
        expect(find.text('Discard'), findsOneWidget);
      });

  testWidgets('menu with a corrupt saved game shows no dialog, no error',
      (tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final (settings, audio) = await _loadSettings({
          'chess_saved_game': '{not json',
        });
        await tester.pumpWidget(_menuApp(settings, audio));
        await tester.pumpAndSettle();
        _expectMenuClean(tester);
        expect(find.text('Resume game?'), findsNothing);
      });

  testWidgets('pressing a BrassButton does not throw (pressed gradient)',
      (tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final (settings, audio) = await _loadSettings({});
        await tester.pumpWidget(_menuApp(settings, audio));
        await tester.pumpAndSettle();
        // Press-and-hold the Settings button: this builds the pressed
        // (2-colour) brass gradient while the finger is down.
        final center = tester.getCenter(find.text('SETTINGS'));
        final gesture = await tester.startGesture(center);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
      });

  testWidgets('full app: splash navigates to a clean menu', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (settings, audio) = await _loadSettings({});
    await tester.pumpWidget(ChessApp(settings: settings, audio: audio));
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pumpAndSettle();
    expect(find.byType(MenuScreen), findsOneWidget);
    _expectMenuClean(tester);
  });
}
