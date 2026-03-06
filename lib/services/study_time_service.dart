import 'package:shared_preferences/shared_preferences.dart';

/// 学习时长存储服务
///
/// 使用 SharedPreferences 按日累计学习秒数。
/// Key 格式：`study_time_YYYY-MM-DD`，value 为当日累计秒数。
class StudyTimeService {
  static const String _keyPrefix = 'study_time_';

  /// 获取指定日期的学习时长（秒）
  Future<int> getStudyTime(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFor(date)) ?? 0;
  }

  /// 获取今日学习时长（秒）
  Future<int> getTodayStudyTime() => getStudyTime(DateTime.now());

  /// 累加学习时长（秒）到指定日期
  ///
  /// [seconds] 必须 > 0，否则忽略。
  /// [date] 默认为今天。
  Future<void> addStudyTime(int seconds, {DateTime? date}) async {
    if (seconds <= 0) return;

    final targetDate = date ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(targetDate);
    final current = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, current + seconds);
  }

  /// 生成日期对应的存储 key
  String _keyFor(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$_keyPrefix$y-$m-$d';
  }
}
