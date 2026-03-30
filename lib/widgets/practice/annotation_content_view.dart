/// 标注模式内容视图（共享组件）
///
/// 将工具栏固定在顶部不随内容滚动，句子文本和翻译/解析在下方可滚动区域。
/// 内部管理意群全部逻辑：词级时间戳加载、AI 拆分请求、时间范围计算、播放。
///
/// 用于精听、难句补练、难句跟读和收藏复习页面。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../models/sense_group_result.dart';
import '../../models/speech_practice_models.dart';
import '../../models/word_timestamp.dart';
import '../../providers/audio_engine/audio_engine_provider.dart';
import '../../providers/sentence_ai_provider.dart';
import '../../services/app_logger.dart';
import '../../services/transcription_api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/sense_group_service.dart';
import '../../utils/sense_group_timing.dart';
import '../intensive_listen/sentence_annotation_card.dart';

/// 标注模式内容视图
///
/// 工具栏固定在顶部不随内容滚动，句子文本和解析内容在下方可滚动。
/// 内部管理意群数据和播放。
class AnnotationContentView extends ConsumerStatefulWidget {
  /// 句子文本
  final String text;

  /// AI 翻译/解析服务
  final SentenceAiNotifier? aiNotifier;

  /// 来源音频 ID（用于加载词级时间戳 + 词典弹窗）
  final String? audioItemId;

  /// 当前句子索引
  final int? sentenceIndex;

  /// 当前句子起始时间（毫秒）
  final int? sentenceStartMs;

  /// 当前句子结束时间（毫秒）
  final int? sentenceEndMs;

  /// 语音评估高亮片段（逐词绿/红标色）
  final List<SpeechTranscriptSegment>? highlightedSegments;

  /// 播放意群前停止主播放回调
  final VoidCallback? onStopMainPlayer;

  /// 意群时间范围变化回调（精听播放按钮需要知道 timings）
  final void Function(List<SenseGroupTiming>? timings)? onTimingsChanged;

  const AnnotationContentView({
    super.key,
    required this.text,
    this.aiNotifier,
    this.audioItemId,
    this.sentenceIndex,
    this.sentenceStartMs,
    this.sentenceEndMs,
    this.highlightedSegments,
    this.onStopMainPlayer,
    this.onTimingsChanged,
  });

  @override
  ConsumerState<AnnotationContentView> createState() =>
      _AnnotationContentViewState();
}

class _AnnotationContentViewState extends ConsumerState<AnnotationContentView> {
  /// 用于访问卡片 State 以构建外部工具栏
  GlobalKey<SentenceAnnotationCardState> _cardKey =
      GlobalKey<SentenceAnnotationCardState>();

  /// 工具栏刷新通知器
  final _toolbarNotifier = RebuildNotifier();

  /// 意群数据服务
  final _sgService = SenseGroupService();

  // --- 意群数据状态 ---
  List<WordTimestamp>? _wordTimestamps;
  SenseGroupResult? _senseGroupResult;
  List<SenseGroupTiming>? _senseGroupTimings;

  // --- 意群播放 UI 状态 ---
  int? _playingSenseGroupIndex;
  final Set<int> _playedSenseGroupIndices = {};

  /// 意群播放 session（用于取消）
  int? _sgPlaybackSession;

  @override
  void initState() {
    super.initState();
    _fetchWordTimestamps();
  }

  @override
  void dispose() {
    _toolbarNotifier.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AnnotationContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切句时重建 GlobalKey + 重置意群数据
    if (widget.text != oldWidget.text) {
      _cardKey = GlobalKey<SentenceAnnotationCardState>();
      _resetSenseGroups();
    }
    // 音频切换时重新加载词级时间戳
    if (widget.audioItemId != oldWidget.audioItemId) {
      _resetSenseGroups();
      _wordTimestamps = null;
      _fetchWordTimestamps();
    }
  }

  /// 加载词级时间戳
  Future<void> _fetchWordTimestamps() async {
    final audioItemId = widget.audioItemId;
    if (audioItemId == null) return;

    final words = await _sgService.fetchWordTimestamps(
      audioItemId: audioItemId,
      dao: ref.read(audioItemDaoProvider),
      api: ref.read(transcriptionApiClientProvider),
    );
    if (mounted && widget.audioItemId == audioItemId) {
      setState(() => _wordTimestamps = words);
    }
  }

  /// 请求 AI 拆分意群（作为 onRequestSenseGroups 传给 card）
  Future<void> _requestSenseGroups() async {
    final startMs = widget.sentenceStartMs ?? 0;
    final endMs = widget.sentenceEndMs ?? 0;
    final ai = widget.aiNotifier;
    if (ai == null) return;

    try {
      final (result, timings) = await _sgService.requestSenseGroups(
        text: widget.text,
        ai: ai,
        sentenceStartMs: startMs,
        sentenceEndMs: endMs,
        wordTimestamps: _wordTimestamps,
      );

      if (!mounted) return;

      setState(() {
        _senseGroupResult = result;
        _senseGroupTimings = timings;
      });
      widget.onTimingsChanged?.call(timings);
    } catch (e) {
      AppLogger.log('SenseGroup', '请求意群失败: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.senseGroupLoadFailed ??
                  'Failed to load sense groups, please retry',
            ),
          ),
        );
      }
    }
  }

  /// 意群粒度切换回调
  void _handleModeChanged(List<String> chunks) {
    // 停止当前意群播放
    _stopSenseGroupPlayback();

    if (chunks.isEmpty) {
      setState(() => _senseGroupTimings = null);
      widget.onTimingsChanged?.call(null);
    } else if (_wordTimestamps != null) {
      final timings = _sgService.computeTimings(
        chunks: chunks,
        wordTimestamps: _wordTimestamps!,
        sentenceStartMs: widget.sentenceStartMs ?? 0,
        sentenceEndMs: widget.sentenceEndMs ?? 0,
      );
      setState(() => _senseGroupTimings = timings);
      widget.onTimingsChanged?.call(timings);
    }
  }

  /// 点击意群播放
  Future<void> _handleTapSenseGroup(int index) async {
    final timings = _senseGroupTimings;
    if (timings == null || index >= timings.length) return;

    // 停止主播放
    widget.onStopMainPlayer?.call();

    final timing = timings[index];
    final engine = ref.read(audioEngineProvider.notifier);
    final sessionId = engine.newSession();
    _sgPlaybackSession = sessionId;

    setState(() {
      _playingSenseGroupIndex = index;
      _playedSenseGroupIndices.add(index);
    });

    await engine.playRangeOnce(timing.start, timing.end, sessionId);

    if (mounted && _sgPlaybackSession == sessionId) {
      setState(() => _playingSenseGroupIndex = null);
    }
  }

  /// 停止意群播放
  void _stopSenseGroupPlayback() {
    if (_playingSenseGroupIndex != null) {
      _sgPlaybackSession = null;
      setState(() => _playingSenseGroupIndex = null);
    }
  }

  /// 重置意群数据
  void _resetSenseGroups() {
    _senseGroupResult = null;
    _senseGroupTimings = null;
    _playingSenseGroupIndex = null;
    _playedSenseGroupIndices.clear();
    _sgPlaybackSession = null;
    widget.onTimingsChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final ai = widget.aiNotifier;
    final cachedTranslation =
        ai?.getCachedTranslation(widget.text)?.translation;
    final cachedAnalysis = ai?.getCachedAnalysis(widget.text);
    final cachedAnalysisText = cachedAnalysis?.toDisplayString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 固定工具栏（监听 notifier 刷新）
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.m),
          child: ListenableBuilder(
            listenable: _toolbarNotifier,
            builder: (context, _) {
              final cardState = _cardKey.currentState;
              if (cardState == null || !cardState.hasToolbarButtons) {
                return const SizedBox.shrink();
              }
              return cardState.buildToolbar(context);
            },
          ),
        ),
        // 可滚动内容区
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AppSpacing.l),
            child: SentenceAnnotationCard(
              key: _cardKey,
              text: widget.text,
              showToolbar: false,
              onToolbarStateChanged: _toolbarNotifier.notify,
              onRequestTranslation: ai != null
                  ? () async {
                      final result = await ai.getTranslation(widget.text);
                      return result.translation;
                    }
                  : null,
              onRequestAnalysis: ai != null
                  ? () async {
                      final result = await ai.getAnalysis(widget.text);
                      return result.toDisplayString();
                    }
                  : null,
              cachedTranslation: cachedTranslation,
              cachedAnalysis: cachedAnalysisText,
              audioItemId: widget.audioItemId,
              sentenceIndex: widget.sentenceIndex,
              sentenceStartMs: widget.sentenceStartMs,
              sentenceEndMs: widget.sentenceEndMs,
              senseGroupResult: _senseGroupResult,
              senseGroupTimings: _senseGroupTimings,
              onSenseGroupModeChanged: _handleModeChanged,
              playingSenseGroupIndex: _playingSenseGroupIndex,
              playedSenseGroupIndices: _playedSenseGroupIndices,
              onTapSenseGroup: _handleTapSenseGroup,
              onRequestSenseGroups: _requestSenseGroups,
              hasWordTimestamps: _wordTimestamps != null,
              highlightedSegments: widget.highlightedSegments,
            ),
          ),
        ),
      ],
    );
  }
}

/// 简单的重建通知器，用于卡片状态变化时触发工具栏重建
class RebuildNotifier extends ChangeNotifier {
  /// 通知所有监听者重建
  void notify() => notifyListeners();
}
