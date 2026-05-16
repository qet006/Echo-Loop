/// 自动跳过复述全局开关集成测试
///
/// 端到端验证设置入口可达 + 开关切换写入 Provider。
/// 深层行为（autoSkip 扫描 / 三态渲染 / 进度计算）已被 unit + widget 测试覆盖。
library;

import 'package:echo_loop/main.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_notifiers.dart';

/// 自动跳过复述开关集成测试
void retellToggleTests() {
  group('流程 X：自动跳过复述开关', () {
    testWidgets('设置 → 学习 → 学习设置：开关切换可达且 state 翻转', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Learning settings'));
      await tester.pumpAndSettle();

      expect(find.text('Auto-skip speaking practice'), findsOneWidget);

      // 默认 autoSkipRetell=false
      final context = tester.element(find.byType(EchoLoopApp));
      final container = ProviderScope.containerOf(context);
      expect(
        container.read(learningSettingsProvider).autoSkipRetell,
        isFalse,
      );

      // 切换开关（false → true）
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        container.read(learningSettingsProvider).autoSkipRetell,
        isTrue,
      );

      // 再切回（true → false）
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        container.read(learningSettingsProvider).autoSkipRetell,
        isFalse,
      );
    });
  });
}
