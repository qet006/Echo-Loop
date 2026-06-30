/// TTS 专属音频播放器
///
/// 播放合成出的本地音频文件，**不接入 `audio_service`**（一次性短发音，不上锁屏、
/// 不要后台保活）。照搬 [ForegroundAudioEngine] 的隔离思路：自持一个裸
/// [ja.AudioPlayer]，物理上碰不到系统媒体会话（规避 CLAUDE.md §7.7–7.13 锁屏竞态）。
///
/// 用 session 守卫 + `playerStateStream.firstWhere(completed||失效)` 确定性等待
/// 自然播完（§7.6），不监听 completed 事件做反应式推进。
library;

import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart' as ja;

import '../app_logger.dart';

/// 注入工厂签名（测试可替换 AudioPlayer）。
typedef AudioPlayerFactory = ja.AudioPlayer Function();

class TtsPlayer {
  TtsPlayer({AudioPlayerFactory? playerFactory})
    : _player = (playerFactory ?? ja.AudioPlayer.new)();

  final ja.AudioPlayer _player;

  /// 当前 session id。每次新播放/停止递增，过期回调据此丢弃。
  int _sessionId = 0;

  /// 播放本地文件直到自然播完（或被新 session 抢占）。
  ///
  /// 返回 true 表示本次正常播完；被抢占/失败返回 false。
  Future<bool> playFileToEnd(String filePath) async {
    final sid = ++_sessionId;
    final sw = Stopwatch()..start();
    try {
      final exists = await File(filePath).exists();
      final size = exists ? await File(filePath).length() : 0;
      final duration = await _player.setFilePath(filePath);
      AppLogger.log(
        'TtsPlayer',
        '▶ playFileToEnd sid=$sid exists=$exists size=$size '
            'duration=${duration?.inMilliseconds}ms path=$filePath',
      );
      if (sid != _sessionId) return false;

      await _player.seek(Duration.zero);
      if (sid != _sessionId) return false;

      await _player.play();
      if (sid != _sessionId) {
        await _player.pause();
        return false;
      }

      // 等待自然播完。排除「订阅瞬间残留的 completed」——只接受 play() 之后到达的
      // completed（§7.6：just_audio 完成后 processingState 仍为 completed，复用同一
      // player 时上一文件的 completed 会在订阅首帧立即命中，导致瞬间返回、无声）。
      await _player.playerStateStream.firstWhere(
        (s) =>
            sid != _sessionId ||
            (s.processingState == ja.ProcessingState.completed &&
                _player.position > Duration.zero),
      );
      sw.stop();
      AppLogger.log(
        'TtsPlayer',
        '✓ playFileToEnd done sid=$sid elapsed=${sw.elapsedMilliseconds}ms '
            'pos=${_player.position.inMilliseconds}ms active=${sid == _sessionId}',
      );
      return sid == _sessionId;
    } catch (e, st) {
      AppLogger.log('TtsPlayer', '✗ playFileToEnd 失败 sid=$sid: $e\n$st');
      return false;
    }
  }

  /// 停止播放（递增 session，使在途 await 失效）。
  Future<void> stop() async {
    _sessionId++;
    await _player.stop();
  }

  Future<void> dispose() async {
    _sessionId++;
    await _player.dispose();
  }
}
