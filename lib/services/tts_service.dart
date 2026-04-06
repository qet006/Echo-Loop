/// TTS 发音服务
///
/// 封装 flutter_tts，提供单词发音功能。
/// 单例模式，Flashcard 和词典弹窗共用。
///
/// 不依赖 flutter_tts 的 awaitSpeakCompletion（在快速 stop→speak
/// 场景下会失效），改用自管理的 Completer + start/completion handler
/// 保证 [speak] 返回的 Future 在 TTS 真正朗读完成后才 complete。
///
/// 关键：用 [_started] 标志过滤 stop 产生的 stale cancel 回调。
/// method channel 消息是 FIFO 的，顺序保证：
/// 旧 stop 的 cancel → 新 speak 的 start → 新 speak 的 completion。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// TTS 发音服务单例
class TtsService {
  TtsService._() {
    _init();
  }

  /// 测试用构造器，允许注入 mock FlutterTts
  @visibleForTesting
  TtsService.withTts(FlutterTts tts) : _tts = tts {
    _setupHandlers();
  }

  static TtsService _instance = TtsService._();

  /// 全局单例
  static TtsService get instance => _instance;

  /// 测试用：替换全局单例，返回旧实例以便恢复
  @visibleForTesting
  static TtsService replaceInstance(TtsService service) {
    final old = _instance;
    _instance = service;
    return old;
  }

  late final FlutterTts _tts;

  /// 当前 speak 的完成信号
  Completer<void>? _speakCompleter;

  /// 标记当前 speak 是否已被平台确认开始
  ///
  /// stop 的 cancel handler 会在新 speak 的 start handler 之前到达，
  /// 利用此标志过滤掉 stale 回调。
  bool _started = false;

  /// 初始化 TTS 引擎
  void _init() {
    _tts = FlutterTts();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.45);
    _tts.setVolume(1.0);
    _tts.setPitch(1.0);
    // 不使用 awaitSpeakCompletion — 快速 stop→speak 场景下会失效
    _tts.awaitSpeakCompletion(false);
    _setupHandlers();
  }

  /// 注册平台回调
  void _setupHandlers() {
    _tts.setStartHandler(() => _started = true);
    _tts.setCompletionHandler(_onTtsDone);
    _tts.setCancelHandler(_onTtsDone);
    _tts.setErrorHandler((_) => _onTtsDone());
  }

  /// TTS 完成/取消/出错时统一回调
  void _onTtsDone() {
    if (!_started) return; // stale callback（来自旧 stop），忽略
    _started = false;
    final c = _speakCompleter;
    _speakCompleter = null;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
  }

  /// 朗读文本
  ///
  /// 如果正在播放则先停止再播放新内容。
  /// 返回的 Future 在 TTS 真正朗读完成后才 complete。
  Future<void> speak(String text) async {
    // 停止旧播放并等待平台确认
    await stop();
    _started = false;
    _speakCompleter = Completer<void>();
    await _tts.speak(text);
    // 等待 start handler → completion handler 通知真正完成
    await _speakCompleter?.future;
  }

  /// 停止播放
  Future<void> stop() async {
    _started = false;
    // 立即解除正在等待的 speak，防止调用方永远挂起
    final c = _speakCompleter;
    _speakCompleter = null;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
    await _tts.stop();
  }

  /// 释放资源
  void dispose() {
    _started = false;
    final c = _speakCompleter;
    _speakCompleter = null;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
    _tts.stop();
  }
}
