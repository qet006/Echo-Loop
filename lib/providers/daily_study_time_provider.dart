import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/study_time_service.dart';

part 'daily_study_time_provider.g.dart';

/// 今日学习时长 Provider（秒）
///
/// 从 SharedPreferences 读取今日累计学习秒数。
/// 每次进入/退出学习模式后刷新。
@riverpod
class DailyStudyTime extends _$DailyStudyTime {
  @override
  Future<int> build() async {
    return StudyTimeService().getTodayStudyTime();
  }

  /// 手动刷新今日学习时长
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await StudyTimeService().getTodayStudyTime());
  }
}
