import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluency/services/study_time_service.dart';

void main() {
  group('StudyTimeService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('首次调用 getTodayStudyTime 返回 0', () async {
      final service = StudyTimeService();
      final result = await service.getTodayStudyTime();
      expect(result, 0);
    });

    test('addStudyTime 累加到今日 key', () async {
      final service = StudyTimeService();

      await service.addStudyTime(30);
      expect(await service.getTodayStudyTime(), 30);

      await service.addStudyTime(45);
      expect(await service.getTodayStudyTime(), 75);
    });

    test('addStudyTime(0) 不改变已有值', () async {
      final service = StudyTimeService();

      await service.addStudyTime(60);
      await service.addStudyTime(0);
      expect(await service.getTodayStudyTime(), 60);
    });

    test('负数被忽略', () async {
      final service = StudyTimeService();

      await service.addStudyTime(60);
      await service.addStudyTime(-10);
      expect(await service.getTodayStudyTime(), 60);
    });

    test('自定义日期 key 读写正确', () async {
      final service = StudyTimeService();
      final customDate = DateTime(2026, 1, 15);

      await service.addStudyTime(120, date: customDate);
      expect(await service.getStudyTime(customDate), 120);

      // 今日仍为 0
      expect(await service.getTodayStudyTime(), 0);
    });

    test('跨天时 key 自动切换', () async {
      final service = StudyTimeService();

      final day1 = DateTime(2026, 3, 5);
      final day2 = DateTime(2026, 3, 6);

      await service.addStudyTime(100, date: day1);
      await service.addStudyTime(200, date: day2);

      expect(await service.getStudyTime(day1), 100);
      expect(await service.getStudyTime(day2), 200);
    });
  });
}
