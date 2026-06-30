/// [TtsPlayer] 单测：用注入的 fake [ja.AudioPlayer] 覆盖播放健壮性。
///
/// 重点回归两类「静默无声」：
/// 1. 复用同一 player 时，订阅瞬间残留的 `completed`（position 0）不得让
///    `playFileToEnd` 立即返回（§7.6 同类陷阱——否则瞬间返回、根本没出声）；
/// 2. 播放途中被新 session 抢占（stop/新发音）时返回 false。
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:mocktail/mocktail.dart';

import 'package:echo_loop/services/tts/tts_player.dart';

class MockAudioPlayer extends Mock implements ja.AudioPlayer {}

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  late MockAudioPlayer player;
  late StreamController<ja.PlayerState> stateCtrl;
  Duration position = Duration.zero;

  setUp(() {
    player = MockAudioPlayer();
    stateCtrl = StreamController<ja.PlayerState>.broadcast();
    position = Duration.zero;

    when(
      () => player.setFilePath(any()),
    ).thenAnswer((_) async => const Duration(seconds: 2));
    when(() => player.seek(any())).thenAnswer((_) async {});
    when(() => player.play()).thenAnswer((_) async {});
    when(() => player.pause()).thenAnswer((_) async {});
    when(() => player.stop()).thenAnswer((_) async {});
    when(() => player.dispose()).thenAnswer((_) async {});
    when(() => player.position).thenAnswer((_) => position);
    when(() => player.playerStateStream).thenAnswer((_) => stateCtrl.stream);
  });

  tearDown(() async {
    await stateCtrl.close();
  });

  TtsPlayer build() => TtsPlayer(playerFactory: () => player);

  test('stale completed（position 0）不立即返回，等真正播完才返回 true', () async {
    final p = build();
    var done = false;
    final future = p.playFileToEnd('/nonexistent.wav').then((v) {
      done = true;
      return v;
    });

    // 等订阅就绪后，发一个「残留」completed（位置仍在 0）——模拟复用 player。
    await Future<void>.delayed(const Duration(milliseconds: 20));
    position = Duration.zero;
    stateCtrl.add(ja.PlayerState(false, ja.ProcessingState.completed));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(done, isFalse, reason: 'stale completed 不应使 playFileToEnd 返回');

    // 真正播到末尾（position 推进到尾）+ completed → 应正常返回 true。
    position = const Duration(seconds: 2);
    stateCtrl.add(ja.PlayerState(false, ja.ProcessingState.completed));
    final ok = await future;
    expect(ok, isTrue);
  });

  test('播放途中被 stop 抢占 → 返回 false', () async {
    final p = build();
    final future = p.playFileToEnd('/nonexistent.wav');

    await Future<void>.delayed(const Duration(milliseconds: 20));
    await p.stop(); // 递增 sessionId，使在途 await 失效
    // 任一后续事件触发 firstWhere 重新求值，命中 sid != _sessionId 分支。
    stateCtrl.add(ja.PlayerState(true, ja.ProcessingState.ready));

    final ok = await future;
    expect(ok, isFalse);
  });

  test('正常播完返回 true', () async {
    final p = build();
    final future = p.playFileToEnd('/nonexistent.wav');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    position = const Duration(seconds: 2);
    stateCtrl.add(ja.PlayerState(false, ja.ProcessingState.completed));
    expect(await future, isTrue);
  });
}
