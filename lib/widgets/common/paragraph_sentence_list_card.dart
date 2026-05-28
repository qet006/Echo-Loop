/// 段落句子列表卡片
///
/// 统一渲染段落内句子列表，供全文盲听和段落复述共用。
library;

import 'package:flutter/material.dart';

import '../../models/retell_settings.dart';
import '../../models/sentence.dart';
import '../../theme/app_theme.dart';
import '../guide_flow.dart';
import 'masked_sentence_tile.dart';

/// 段落句子列表卡片
class ParagraphSentenceListCard extends StatelessWidget {
  final List<Sentence> sentences;
  final RetellDisplayMode displayMode;
  final Map<int, Set<int>> keywordMap;
  final int playingSentenceIndex;

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
    this.bookmarkedSentenceIndices = const {},
    this.onSentenceTap,
    this.onSentencePlayFrom,
    this.guideTargetLocalIdx,
    this.numberAreaGuideStep,
    this.bodyAreaGuideStep,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        itemCount: sentences.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: AppSpacing.m,
          endIndent: AppSpacing.m,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        itemBuilder: (context, index) {
          final sentence = sentences[index];
          final isGuideTarget = guideTargetLocalIdx == index;
          return MaskedSentenceTile(
            sentence: sentence,
            displayMode: displayMode,
            keywordIndices: keywordMap[sentence.index] ?? const {},
            isPlayingSentence: index == playingSentenceIndex,
            isBookmarked: bookmarkedSentenceIndices.contains(sentence.index),
            onDetailTap: onSentenceTap == null
                ? null
                : () => onSentenceTap!(sentence),
            onPlayFromTap: onSentencePlayFrom == null
                ? null
                : () => onSentencePlayFrom!(sentence),
            numberAreaGuideStep: isGuideTarget ? numberAreaGuideStep : null,
            bodyAreaGuideStep: isGuideTarget ? bodyAreaGuideStep : null,
          );
        },
      ),
    );
  }
}
