import 'package:flutter/material.dart';

import '../main.dart';

/// 显示带撤销按钮的 SnackBar
///
/// 用于取消收藏等可逆操作，给用户 3 秒撤销窗口。
/// [message] 提示文案，[undoLabel] 撤销按钮文案，[onUndo] 撤销回调。
///
/// 始终使用全局 [rootScaffoldMessengerKey] 显示，不依赖 context，
/// 避免嵌套 Scaffold 或 Dismissible 销毁 widget 后 context 失效的问题。
///
/// Flutter 3.38+ 起带 action 的 SnackBar 默认不自动消失（persist 默认值变更），
/// 需显式设置 `persist: false` 恢复按 duration 自动消失的行为。
void showUndoSnackBar({
  required String message,
  required String undoLabel,
  required VoidCallback onUndo,
}) {
  final sm = rootScaffoldMessengerKey.currentState;
  if (sm == null) return;
  sm.clearSnackBars();
  sm.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 3),
      persist: false,
      action: SnackBarAction(label: undoLabel, onPressed: onUndo),
    ),
  );
}
