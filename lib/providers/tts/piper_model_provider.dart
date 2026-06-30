/// Piper VITS（Echo Loop TTS 平衡档）模型下载状态机 Provider（多音色）。
///
/// 管理 9 个 Piper 音色各自的下载/重试/取消/删除与就绪状态——与 Kokoro 不同，
/// Piper 每音色是一个独立模型，故下载单元是「音色」（key=voiceId）。每个音色一个
/// [PiperModelManager]（`piperModelManagerProvider` 的 family），互不干扰、可独立
/// 下载与删除。引擎当前用哪个音色由 [ttsSettingsProvider] 的 `activePiperVoice`
/// 决定，[piperReadyProvider] 即「当前口音下选中的音色是否就绪」。
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/app_logger.dart';
import '../../services/download/download_failure.dart';
import '../../services/tts/piper_model_manager.dart';
import '../../services/tts/piper_voices.dart';
import 'tts_settings_provider.dart';

/// 每音色「已下载」持久化标记 key。
String _downloadedKey(String voiceId) => 'piper_model_downloaded_$voiceId';

/// 由持久化标记 + 本地体积派生下载状态。
AsrModelDownloadStatus _deriveStatus({
  required bool fullyDownloaded,
  required int localSizeBytes,
}) {
  if (fullyDownloaded) return AsrModelDownloadStatus.downloaded;
  if (localSizeBytes > 0) return AsrModelDownloadStatus.failed;
  return AsrModelDownloadStatus.notDownloaded;
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// 单个 Piper 音色模型的 UI 状态。
class PiperModelState {
  final AsrModelDownloadStatus downloadStatus;
  final double downloadProgress;
  final int localSizeBytes;

  /// 失败时的归类原因（供 UI 显本地化文案）；非失败态为 null。
  final DownloadFailureKind? downloadError;

  const PiperModelState({
    this.downloadStatus = AsrModelDownloadStatus.notDownloaded,
    this.downloadProgress = 0,
    this.localSizeBytes = 0,
    this.downloadError,
  });

  /// 模型是否已就绪（可被引擎使用）。
  bool get isReady => downloadStatus == AsrModelDownloadStatus.downloaded;

  /// 是否正在下载。
  bool get isDownloading => downloadStatus == AsrModelDownloadStatus.downloading;

  PiperModelState copyWith({
    AsrModelDownloadStatus? downloadStatus,
    double? downloadProgress,
    int? localSizeBytes,
    DownloadFailureKind? downloadError,
    bool clearError = false,
  }) {
    return PiperModelState(
      downloadStatus: downloadStatus ?? this.downloadStatus,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      localSizeBytes: localSizeBytes ?? this.localSizeBytes,
      downloadError: clearError ? null : (downloadError ?? this.downloadError),
    );
  }
}

/// 全部音色合并的状态容器。
class PiperModelsState {
  final Map<String, PiperModelState> byVoiceId;

  const PiperModelsState(this.byVoiceId);

  /// 全部未下载的初始态。
  factory PiperModelsState.initial() => const PiperModelsState({});

  /// 取某音色状态（缺省为未下载）。
  PiperModelState of(String voiceId) =>
      byVoiceId[voiceId] ?? const PiperModelState();

  /// 返回替换了某音色状态的新容器。
  PiperModelsState withVoice(String voiceId, PiperModelState s) {
    return PiperModelsState({...byVoiceId, voiceId: s});
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Piper 模型管理器（按音色 id 的 family，各自绑定音色）。
final piperModelManagerProvider =
    Provider.family<PiperModelManager, String>((ref, voiceId) {
      final voice = piperVoiceById(voiceId) ?? piperVoices.first;
      final manager = PiperModelManager(voice: voice);
      ref.onDispose(manager.dispose);
      return manager;
    });

/// 启动期注入的初始状态（main() override；缺省为全未下载）。
final initialPiperModelStateProvider = Provider<PiperModelsState>(
  (ref) => PiperModelsState.initial(),
);

/// Piper 模型状态 Provider（全局单例）。
final piperModelProvider =
    NotifierProvider<PiperModelNotifier, PiperModelsState>(
      PiperModelNotifier.new,
    );

/// 当前口音下**选中音色**是否就绪（供控制器决定有效引擎）。
final piperReadyProvider = Provider<bool>((ref) {
  final voiceId = ref.watch(
    ttsSettingsProvider.select((s) => s.activePiperVoice),
  );
  return ref.watch(piperModelProvider).of(voiceId).isReady;
});

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class PiperModelNotifier extends Notifier<PiperModelsState> {
  final Map<String, CancelToken> _cancelTokens = {};

  @override
  PiperModelsState build() {
    ref.onDispose(() {
      for (final t in _cancelTokens.values) {
        t.cancel();
      }
    });
    return ref.read(initialPiperModelStateProvider);
  }

  void _set(String voiceId, PiperModelState s) {
    state = state.withVoice(voiceId, s);
  }

  /// 确保某音色就绪：未就绪且未在下载则触发下载。
  Future<void> ensureDownloaded(String voiceId) async {
    final s = state.of(voiceId);
    if (s.isReady || s.isDownloading) return;
    await _download(voiceId);
  }

  /// 重试下载（清除错误后重新下载）。
  Future<void> retryDownload(String voiceId) async {
    _set(voiceId, state.of(voiceId).copyWith(clearError: true));
    await _download(voiceId);
  }

  /// 取消某音色正在进行的下载。
  Future<void> cancelDownload(String voiceId) async {
    _cancelTokens.remove(voiceId)?.cancel();
    final manager = ref.read(piperModelManagerProvider(voiceId));
    final localSize = await manager.modelLocalSize();
    _set(
      voiceId,
      state
          .of(voiceId)
          .copyWith(
            downloadStatus: _deriveStatus(
              fullyDownloaded: false,
              localSizeBytes: localSize,
            ),
            downloadProgress: 0,
            localSizeBytes: localSize,
          ),
    );
    await _persistDownloaded(voiceId, false);
  }

  /// 删除某音色本地模型。
  Future<void> deleteModel(String voiceId) async {
    final manager = ref.read(piperModelManagerProvider(voiceId));
    await manager.deleteModel();
    _set(
      voiceId,
      const PiperModelState(downloadStatus: AsrModelDownloadStatus.notDownloaded),
    );
    await _persistDownloaded(voiceId, false);
  }

  Future<void> _download(String voiceId) async {
    // 先**同步**置为下载中，再做任何 await（同 Kokoro：避免 ensureDownloaded 的
    // 「未在下载」判定与状态翻转之间的 await 窗口被第二次调用漏过、起两路下载）。
    _set(
      voiceId,
      state
          .of(voiceId)
          .copyWith(
            downloadStatus: AsrModelDownloadStatus.downloading,
            downloadProgress: 0,
            clearError: true,
          ),
    );
    await _persistDownloaded(voiceId, false);

    final cancelToken = CancelToken();
    _cancelTokens[voiceId] = cancelToken;
    final manager = ref.read(piperModelManagerProvider(voiceId));
    try {
      await manager.downloadModel(
        cancelToken: cancelToken,
        onProgress: (p) {
          if (cancelToken.isCancelled) return;
          _set(voiceId, state.of(voiceId).copyWith(downloadProgress: p.progress));
        },
      );
      _cancelTokens.remove(voiceId);
      final localSize = await manager.modelLocalSize();
      _set(
        voiceId,
        state
            .of(voiceId)
            .copyWith(
              downloadStatus: AsrModelDownloadStatus.downloaded,
              downloadProgress: 1.0,
              localSizeBytes: localSize,
            ),
      );
      await _persistDownloaded(voiceId, true);
    } catch (e) {
      _cancelTokens.remove(voiceId);
      // 取消不是失败：恢复未下载态，不显错误。
      if (e is DioException && e.type == DioExceptionType.cancel) {
        _set(
          voiceId,
          state
              .of(voiceId)
              .copyWith(
                downloadStatus: AsrModelDownloadStatus.notDownloaded,
                downloadProgress: 0,
              ),
        );
      } else {
        AppLogger.log('PiperModel', '✗ download failed ($voiceId): $e');
        _set(
          voiceId,
          state
              .of(voiceId)
              .copyWith(
                downloadStatus: AsrModelDownloadStatus.failed,
                downloadError: classifyDownloadFailure(e),
              ),
        );
      }
      await _persistDownloaded(voiceId, false);
    }
  }

  Future<void> _persistDownloaded(String voiceId, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_downloadedKey(voiceId), value);
    } catch (e) {
      AppLogger.log('PiperModel', '写 SP 失败: $e');
    }
  }
}

/// 启动期从持久化 + 文件系统构建全部音色的初始状态。
///
/// [managerOf] 按音色 id 返回对应管理器（main() 注入真实实现，测试注入 fake）。
Future<PiperModelsState> loadInitialPiperModelState({
  required SharedPreferences prefs,
  required PiperModelManager Function(String voiceId) managerOf,
}) async {
  final map = <String, PiperModelState>{};
  for (final voice in piperVoices) {
    final manager = managerOf(voice.id);
    final persisted = prefs.getBool(_downloadedKey(voice.id)) ?? false;
    final localSize = await manager.modelLocalSize();
    // 以文件系统校验为准：标记为真但关键文件缺失则降级。
    final fullyDownloaded = persisted && await manager.isModelDownloaded();
    map[voice.id] = PiperModelState(
      downloadStatus: _deriveStatus(
        fullyDownloaded: fullyDownloaded,
        localSizeBytes: localSize,
      ),
      localSizeBytes: localSize,
    );
  }
  return PiperModelsState(map);
}
