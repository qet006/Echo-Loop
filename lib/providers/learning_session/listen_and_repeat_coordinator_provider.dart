/// 跟读协调 Provider
///
/// 集中管理跟读页面的业务逻辑协调，替代 Screen build() 中的 ref.listen 块。
/// 职责：
/// - 句子切换 → 清除录音结果、同步控制模式
/// - 评估完成 → 启动 postEval 倒计时
/// - controlMode 切换 → 同步录音控制器
/// - 自动录音触发（phase 从 Playing → RepeatPause/AdvancePause 时）
///
/// Screen 只需 `ref.watch(listenAndRepeatCoordinatorProvider)` 激活协调器，
/// 不再包含业务逻辑。
library;

import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../services/app_logger.dart';
import '../listen_and_repeat_turn_controller_provider.dart';
import 'listen_and_repeat_player_provider.dart';

part 'listen_and_repeat_coordinator_provider.g.dart';

/// 跟读协调 Provider
///
/// keepAlive 确保在页面生命周期内始终活跃。
/// 通过 ref.listen 监听 player 和 recording 状态变化，自动触发协调逻辑。
@Riverpod(keepAlive: true)
class ListenAndRepeatCoordinator extends _$ListenAndRepeatCoordinator {
  /// 用户手动停止了录音（评估后倒计时 +2s）
  bool _manualStoppedRecording = false;

  /// 音频项 ID（用于构建 promptId）
  String? _audioItemId;

  @override
  void build() {
    // 监听 player 状态变化
    ref.listen(listenAndRepeatPlayerProvider, _onPlayerStateChanged);

    // 监听录音状态变化
    ref.listen(shadowingRecordingControllerProvider, _onRecordingStateChanged);
  }

  /// 设置音频项 ID（Screen initState 时调用）
  void setAudioItemId(String audioItemId) {
    _audioItemId = audioItemId;
  }

  /// 标记用户手动停止了录音（评估后倒计时 +2s）
  void markManualStoppedRecording() {
    _manualStoppedRecording = true;
  }

  /// 重置状态（换句时自动调用）
  void _resetPerSentenceState() {
    _manualStoppedRecording = false;
  }

  // ========== Player 状态变化处理 ==========

  void _onPlayerStateChanged(
    ListenAndRepeatPlayerState? prev,
    ListenAndRepeatPlayerState next,
  ) {
    if (prev == null) return;

    // 句子切换 → 清录音 + 重置状态
    if (prev.currentSentenceIndex != next.currentSentenceIndex) {
      _resetPerSentenceState();
      final controller = ref.read(
        shadowingRecordingControllerProvider.notifier,
      );
      controller.setManualMode(next.settings.isManualMode);
      controller.clearRecording();
    }

    // controlMode 切换 → 同步到录音控制器
    if (prev.settings.controlMode != next.settings.controlMode) {
      final controller = ref.read(
        shadowingRecordingControllerProvider.notifier,
      );
      controller.setManualMode(next.settings.isManualMode);
      // 切入手动模式时取消正在进行的自动录音
      if (next.settings.isManualMode) {
        final recState = ref.read(shadowingRecordingControllerProvider);
        if (recState.phase == ListenAndRepeatTurnPhase.awaitingSpeech ||
            recState.phase == ListenAndRepeatTurnPhase.speaking) {
          controller.cancelActiveRecording();
        }
      }
    }

    // phase 从非停顿 → 停顿（且非 postEval、非 suspended）→ 触发自动录音
    if (!_isPauseForAutoRecord(prev) && _isPauseForAutoRecord(next)) {
      _tryAutoStartRecording(next);
    }
  }

  // ========== Recording 状态变化处理 ==========

  void _onRecordingStateChanged(
    ListenAndRepeatTurnState? prev,
    ListenAndRepeatTurnState next,
  ) {
    if (prev == null) return;

    // 评估完成（processing → idle，有结果）→ 启动 postEval 倒计时
    if (prev.phase == ListenAndRepeatTurnPhase.processing &&
        next.phase == ListenAndRepeatTurnPhase.idle &&
        next.currentAttempt != null) {
      final playerState = ref.read(listenAndRepeatPlayerProvider);
      if (playerState.isPauseBetweenPlays &&
          !playerState.settings.isManualMode &&
          !playerState.isCountdownSuspended) {
        final extra = _manualStoppedRecording
            ? const Duration(seconds: 2)
            : Duration.zero;
        _manualStoppedRecording = false;
        AppLogger.log(
          'Coordinator',
          '评估完成 → 启动 review countdown (extra=${extra.inSeconds}s)',
        );
        ref
            .read(listenAndRepeatPlayerProvider.notifier)
            .startPostEvaluationPause(extraDuration: extra);
      }
    }
  }

  // ========== 自动录音 ==========

  /// 判断是否应该触发自动录音的停顿状态
  bool _isPauseForAutoRecord(ListenAndRepeatPlayerState state) {
    return state.isPauseBetweenPlays &&
        !state.isPostEvalCountdown &&
        !state.isCountdownSuspended &&
        !state.settings.isManualMode;
  }

  /// 尝试自动开始录音
  void _tryAutoStartRecording(ListenAndRepeatPlayerState playerState) {
    final recState = ref.read(shadowingRecordingControllerProvider);
    if (recState.phase != ListenAndRepeatTurnPhase.idle) return;

    final player = ref.read(listenAndRepeatPlayerProvider.notifier);
    final currentSentence = player.currentSentence;
    if (currentSentence == null) return;

    final promptId = _buildPromptId(player);
    final referenceText = currentSentence.text;

    // 暂停倒计时（录音由 ShadowingRecordingController 接管）
    if (!playerState.isCountdownPaused) {
      player.pauseCountdown();
    }

    // 设置录音阈值
    _updateRecordingThresholds(currentSentence.duration);

    AppLogger.log(
      'Coordinator',
      '自动开始录音: 句子${playerState.currentSentenceIndex + 1}',
    );
    unawaited(
      ref
          .read(shadowingRecordingControllerProvider.notifier)
          .startRecording(promptId: promptId, referenceText: referenceText),
    );
  }

  /// 构造 promptId
  String _buildPromptId(ListenAndRepeatPlayer player) {
    final sentence = player.currentSentence;
    final sentenceIndex = sentence?.index ?? player.currentIndex;
    return 'shadowing:${_audioItemId ?? ''}:$sentenceIndex';
  }

  /// 更新录音阈值
  void _updateRecordingThresholds(Duration sentenceDuration) {
    final computed = sentenceDuration * 2.5 + const Duration(seconds: 5);
    final maxRecording = computed < const Duration(seconds: 10)
        ? const Duration(seconds: 10)
        : computed;
    ref
        .read(shadowingRecordingControllerProvider.notifier)
        .setMaxRecordingDuration(maxRecording);
  }
}
