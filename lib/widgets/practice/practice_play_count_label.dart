/// 练习页面共享的遍数 + 模式标签
///
/// 自动模式：显示 "自动 · 第 1/3 遍"，弱化样式。
/// 手动模式：显示 "手动"，高亮样式。
/// 用于所有学习页面（精听、跟读、难句补练、收藏复习、复述、盲听）。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// 遍数 + 模式标签
class PracticePlayCountLabel extends StatelessWidget {
  /// 是否为手动模式
  final bool isManualMode;

  /// 预格式化的遍数文本（如 "第 1/3 遍"）
  final String playCountText;

  /// 本地化
  final AppLocalizations l10n;

  /// 主题
  final ThemeData theme;

  const PracticePlayCountLabel({
    super.key,
    required this.isManualMode,
    required this.playCountText,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: isManualMode ? _buildManualLabel() : _buildAutoLabel(),
    );
  }

  /// 手动模式：高亮 "手动"
  Widget _buildManualLabel() {
    return Text(
      l10n.practiceControlModeManual,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// 自动模式：弱化 "自动 · 第 1/3 遍"
  Widget _buildAutoLabel() {
    return Text(
      '${l10n.practiceControlModeAuto} · $playCountText',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }
}
