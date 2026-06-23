import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart' as ja;

/// Echo Loop 全局后台播放控制器。
///
/// 设计约束：
/// 1. 系统媒体会话、锁屏/通知栏状态只认这一层；
/// 2. Flutter 业务层通过 facade 调它，不直接持有 `AudioPlayer`；
/// 3. 未来若要加上一句/下一句、循环切换、睡眠定时等锁屏控制，只扩这里。
class EchoLoopAudioHandler extends BaseAudioHandler with SeekHandler {
  EchoLoopAudioHandler({ja.AudioPlayer? player}) : _player = player ?? ja.AudioPlayer() {
    _playbackEventSub = _player.playbackEventStream.listen((_) => _broadcastState());
    _durationSub = _player.durationStream.listen((duration) {
      final item = mediaItem.value;
      if (item == null || duration == null) return;
      mediaItem.add(item.copyWith(duration: duration));
      _broadcastState();
    });
  }

  final ja.AudioPlayer _player;
  StreamSubscription<ja.PlaybackEvent>? _playbackEventSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _becomingNoisySub;

  List<MediaControl> _controls = const [
    MediaControl.play,
    MediaControl.stop,
  ];
  List<int> _compactActionIndices = const [0];

  ja.AudioPlayer get player => _player;

  Future<void> configureSession() async {
    if (kIsWeb) return;
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.speech());
    await _interruptionSub?.cancel();
    _interruptionSub = session.interruptionEventStream.listen((event) async {
      if (event.begin) {
        if (_player.playing) {
          await pause();
        }
        return;
      }
      if (event.type == AudioInterruptionType.pause && event.begin == false) {
        _broadcastState();
      }
    });
    await _becomingNoisySub?.cancel();
    _becomingNoisySub = session.becomingNoisyEventStream.listen((_) async {
      if (_player.playing) {
        await pause();
      }
    });
  }

  /// 未来锁屏控制扩展统一改这里，不让页面直接拼系统 controls。
  void setMediaControls({
    required bool playing,
    bool canStop = true,
  }) {
    final controls = <MediaControl>[
      playing ? MediaControl.pause : MediaControl.play,
      if (canStop) MediaControl.stop,
    ];
    _controls = controls;
    _compactActionIndices = controls.length >= 2 ? const [0, 1] : const [0];
  }

  Future<Duration?> loadFile({
    required String id,
    required String filePath,
    required String title,
    required double speed,
  }) async {
    mediaItem.add(
      MediaItem(
        id: id,
        title: title,
        album: 'Echo Loop',
        artist: 'Echo Loop',
      ),
    );
    final duration = await _player.setFilePath(filePath);
    await _player.setSpeed(speed);
    _broadcastState();
    return duration;
  }

  Future<void> setClip({
    required Duration? start,
    required Duration? end,
  }) async {
    await _player.setClip(start: start, end: end);
    _broadcastState();
  }

  @override
  Future<void> play() async {
    await _player.play();
    setMediaControls(playing: true);
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    setMediaControls(playing: false);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    setMediaControls(playing: false);
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _broadcastState();
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    _broadcastState();
  }

  Future<void> disposePlayer() async {
    await _playbackEventSub?.cancel();
    await _durationSub?.cancel();
    await _interruptionSub?.cancel();
    await _becomingNoisySub?.cancel();
    await _player.dispose();
  }

  void _broadcastState() {
    setMediaControls(playing: _player.playing);
    playbackState.add(
      PlaybackState(
        controls: _controls,
        systemActions: const {
          MediaAction.play,
          MediaAction.pause,
          MediaAction.seek,
          MediaAction.stop,
        },
        androidCompactActionIndices: _compactActionIndices,
        processingState: _mapProcessingState(_player.processingState),
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }

  AudioProcessingState _mapProcessingState(ja.ProcessingState state) {
    return switch (state) {
      ja.ProcessingState.idle => AudioProcessingState.idle,
      ja.ProcessingState.loading => AudioProcessingState.loading,
      ja.ProcessingState.buffering => AudioProcessingState.buffering,
      ja.ProcessingState.ready => AudioProcessingState.ready,
      ja.ProcessingState.completed => AudioProcessingState.completed,
    };
  }
}

EchoLoopAudioHandler? _globalAudioHandler;

/// 初始化全局后台播放 handler。
Future<EchoLoopAudioHandler> initEchoLoopAudioHandler() async {
  if (_globalAudioHandler != null) return _globalAudioHandler!;
  final handler = EchoLoopAudioHandler();
  await handler.configureSession();
  if (!kIsWeb) {
    await AudioService.init(
      builder: () => handler,
      config: AudioServiceConfig(
        androidNotificationChannelId: 'app.echoloop.audio',
        androidNotificationChannelName: 'Echo Loop Playback',
        androidStopForegroundOnPause: false,
      ),
    );
  }
  _globalAudioHandler = handler;
  return handler;
}

EchoLoopAudioHandler get echoLoopAudioHandler {
  final handler = _globalAudioHandler;
  if (handler == null) {
    throw StateError('EchoLoopAudioHandler has not been initialized');
  }
  return handler;
}
