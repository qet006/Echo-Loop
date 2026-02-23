/// 跟读简报底部弹窗
///
/// 进入跟读前显示，告知用户难句数量、每句遍数和操作提示。
/// 参照 intensive_listen_briefing_sheet.dart 实现。
library;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// 显示跟读简报底部弹窗
Future<void> showListenAndRepeatBriefingSheet({
  required BuildContext context,
  required int difficultCount,
  required int playCount,
  required VoidCallback onStartPractice,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => ListenAndRepeatBriefingSheet(
      difficultCount: difficultCount,
      playCount: playCount,
      onStartPractice: onStartPractice,
    ),
  );
}

/// 跟读简报弹窗内容
class ListenAndRepeatBriefingSheet extends StatelessWidget {
  /// 难句总数
  final int difficultCount;

  /// 每句播放遍数
  final int playCount;

  /// 开始练习回调
  final VoidCallback onStartPractice;

  const ListenAndRepeatBriefingSheet({
    super.key,
    required this.difficultCount,
    required this.playCount,
    required this.onStartPractice,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示条
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 图标
          Icon(
            Icons.record_voice_over,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.m),

          // 标题
          Text(
            l10n.listenAndRepeatBriefingTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // 副标题
          Text(
            l10n.listenAndRepeatBriefingSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 练习提示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    l10n.listenAndRepeatBriefingTip,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.m),

          // 难句数量 + 遍数信息
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.listenAndRepeatBriefingDifficultCount(difficultCount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Text(
                '·',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Text(
                l10n.listenAndRepeatBriefingPlayCount(playCount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),

          // 开始练习按钮
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onStartPractice();
              },
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.startPractice),
            ),
          ),
        ],
      ),
    );
  }
}
