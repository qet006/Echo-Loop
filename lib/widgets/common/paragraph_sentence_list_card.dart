/// 段落句子列表卡片
///
/// 统一渲染段落内句子列表，供全文盲听和段落复述共用。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../models/retell_settings.dart';
import '../../models/sentence.dart';
import '../../theme/app_theme.dart';
import '../guide_flow.dart';
import 'masked_sentence_tile.dart';

/// 段落句子列表卡片
class ParagraphSentenceListCard extends StatefulWidget {
  final List<Sentence> sentences;
  final RetellDisplayMode displayMode;
  final Map<int, Set<int>> keywordMap;
  final int playingSentenceIndex;
  final bool autoFocusEnabled;
  final Duration autoFocusResumeDelay;

  /// 已收藏句子索引集合（用于显示只读标记）
  final Set<int> bookmarkedSentenceIndices;

  /// 点击句子主体（文本 / 书签）回调：进入句子讲解页
  final ValueChanged<Sentence>? onSentenceTap;

  /// 点击句子编号区回调：从该句开始播放
  final ValueChanged<Sentence>? onSentencePlayFrom;

  /// 新手引导：挂引导 step 的句子本地索引（默认挂在 idx=1，回退到 idx=0）
  final int? guideTargetLocalIdx;

  /// 新手引导：编号区 step
  final GuideStep? numberAreaGuideStep;

  /// 新手引导：主体区 step
  final GuideStep? bodyAreaGuideStep;

  const ParagraphSentenceListCard({
    super.key,
    required this.sentences,
    required this.displayMode,
    required this.keywordMap,
    required this.playingSentenceIndex,
    this.autoFocusEnabled = false,
    this.autoFocusResumeDelay = const Duration(seconds: 2),
    this.bookmarkedSentenceIndices = const {},
    this.onSentenceTap,
    this.onSentencePlayFrom,
    this.guideTargetLocalIdx,
    this.numberAreaGuideStep,
    this.bodyAreaGuideStep,
  });

  @override
  State<ParagraphSentenceListCard> createState() =>
      _ParagraphSentenceListCardState();
}

class _ParagraphSentenceListCardState extends State<ParagraphSentenceListCard> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  Timer? _resumeFocusTimer;
  bool _userSuspendedFocus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusPlayingSentence();
    });
  }

  @override
  void didUpdateWidget(covariant ParagraphSentenceListCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final playingChanged =
        widget.playingSentenceIndex != oldWidget.playingSentenceIndex;
    final paragraphChanged = widget.sentences != oldWidget.sentences;
    final focusReenabled =
        !oldWidget.autoFocusEnabled && widget.autoFocusEnabled;

    if (!widget.autoFocusEnabled) {
      _resumeFocusTimer?.cancel();
      _userSuspendedFocus = false;
      return;
    }

    if (focusReenabled) {
      _userSuspendedFocus = false;
      _focusPlayingSentence();
      return;
    }

    if ((playingChanged || paragraphChanged) && !_userSuspendedFocus) {
      _focusPlayingSentence();
    }
  }

  @override
  void dispose() {
    _resumeFocusTimer?.cancel();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!widget.autoFocusEnabled || notification is! UserScrollNotification) {
      return false;
    }

    if (notification.direction == ScrollDirection.idle) {
      if (_userSuspendedFocus) {
        _resumeFocusTimer?.cancel();
        _resumeFocusTimer = Timer(widget.autoFocusResumeDelay, () {
          if (!mounted || !widget.autoFocusEnabled) return;
          _userSuspendedFocus = false;
          _focusPlayingSentence();
        });
      }
      return false;
    }

    _resumeFocusTimer?.cancel();
    _userSuspendedFocus = true;
    return false;
  }

  /// 自动跟随当前播放句，同时尊重用户手动滚动后的短暂停留。
  void _focusPlayingSentence() {
    if (!widget.autoFocusEnabled || _userSuspendedFocus) return;
    final localSentenceIndex = _playingSentenceLocalIndex();
    if (localSentenceIndex == null) return;
    final targetIndex = localSentenceIndex * 2;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.autoFocusEnabled ||
          _userSuspendedFocus ||
          !_itemScrollController.isAttached) {
        return;
      }
      if (_isTargetSentenceFullyVisible(targetIndex)) {
        return;
      }
      _itemScrollController.scrollTo(
        index: targetIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    });
  }

  bool _isTargetSentenceFullyVisible(int targetIndex) {
    final positions = _itemPositionsListener.itemPositions.value;
    return positions.any(
      (position) =>
          position.index == targetIndex &&
          position.itemLeadingEdge >= 0 &&
          position.itemTrailingEdge <= 1,
    );
  }

  int? _playingSentenceLocalIndex() {
    if (widget.sentences.isEmpty || widget.playingSentenceIndex < 0) {
      return null;
    }
    return _clampLocalSentenceIndex(widget.playingSentenceIndex);
  }

  int _clampLocalSentenceIndex(int index) {
    if (index < 0) return 0;
    final lastIndex = widget.sentences.length - 1;
    if (index > lastIndex) return lastIndex;
    return index;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: ScrollablePositionedList.builder(
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
          itemCount: widget.sentences.isEmpty
              ? 0
              : widget.sentences.length * 2 - 1,
          itemBuilder: (context, index) {
            if (index.isOdd) {
              return Divider(
                height: 1,
                indent: AppSpacing.m,
                endIndent: AppSpacing.m,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              );
            }

            final sentenceIndex = index ~/ 2;
            final sentence = widget.sentences[sentenceIndex];
            final isGuideTarget = widget.guideTargetLocalIdx == sentenceIndex;
            final onSentenceTap = widget.onSentenceTap;
            final onSentencePlayFrom = widget.onSentencePlayFrom;
            return MaskedSentenceTile(
              sentence: sentence,
              displayMode: widget.displayMode,
              keywordIndices: widget.keywordMap[sentence.index] ?? const {},
              isPlayingSentence: sentenceIndex == widget.playingSentenceIndex,
              isBookmarked: widget.bookmarkedSentenceIndices.contains(
                sentence.index,
              ),
              onDetailTap: onSentenceTap == null
                  ? null
                  : () => onSentenceTap(sentence),
              onPlayFromTap: onSentencePlayFrom == null
                  ? null
                  : () => onSentencePlayFrom(sentence),
              numberAreaGuideStep: isGuideTarget
                  ? widget.numberAreaGuideStep
                  : null,
              bodyAreaGuideStep: isGuideTarget
                  ? widget.bodyAreaGuideStep
                  : null,
            );
          },
        ),
      ),
    );
  }
}
