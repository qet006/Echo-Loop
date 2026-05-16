/// LearningPlan 值对象测试
///
/// plan 现在是静态结构（永远全量 allSubStages），不依赖任何 settings。
/// 「不做某类子阶段」的语义通过 LearningProgress.skippedSubStageKeys 承载，
/// 不再由 plan 过滤。
library;

import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/models/learning_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LearningPlan.standard', () {
    final plan = LearningPlan.standard();

    test('每个阶段包含 stage.allSubStages 全量', () {
      for (final stage in LearningStage.values) {
        expect(
          plan.subStagesFor(stage),
          equals(stage.allSubStages),
          reason: 'stage=$stage',
        );
      }
    });

    test('completed 阶段返回空列表（allSubStages 本身为空）', () {
      expect(plan.subStagesFor(LearningStage.completed), isEmpty);
    });
  });

  group('LearningPlan API', () {
    final plan = LearningPlan.standard();

    test('includes 判定 sub 是否在 plan 内（始终 true，除非该阶段无此 sub）', () {
      expect(
        plan.includes(LearningStage.firstLearn, SubStageType.blindListen),
        isTrue,
      );
      expect(
        plan.includes(LearningStage.firstLearn, SubStageType.retell),
        isTrue,
      );
    });

    test('indexOf 返回 plan 内位置', () {
      expect(
        plan.indexOf(LearningStage.firstLearn, SubStageType.listenAndRepeat),
        2,
      );
      expect(
        plan.indexOf(LearningStage.firstLearn, SubStageType.retell),
        3,
      );
    });

    test('totalPlannedCount 跨所有阶段求和（与 allSubStages 长度一致）', () {
      final expected = LearningStage.values.fold<int>(
        0,
        (s, stage) => s + stage.allSubStages.length,
      );
      expect(plan.totalPlannedCount, expected);
    });
  });

  group('LearningPlan.nextPlannedAfter', () {
    final plan = LearningPlan.standard();

    test('当前阶段 plan 中间项 → 返回下一项', () {
      // firstLearn = [blind, intensive, shadow, retell]
      final next = plan.nextPlannedAfter(
        LearningStage.firstLearn,
        SubStageType.intensiveListen,
      );
      expect(next, isNotNull);
      expect(next!.stage, LearningStage.firstLearn);
      expect(next.subStage, SubStageType.listenAndRepeat);
    });

    test('当前阶段 plan 末尾 → 返回 null（不跨阶段引导）', () {
      final next = plan.nextPlannedAfter(
        LearningStage.firstLearn,
        SubStageType.retell,
      );
      expect(next, isNull);
    });
  });
}
