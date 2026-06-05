import '../../models/sentence.dart';

/// 句子可拖动的边界端。
enum BoundaryEdge {
  /// 起始边界。
  start,

  /// 结束边界。
  end,
}

/// 拖动句子边界时允许的最小句长，避免拖成零长或负长。
const Duration kMinSentenceDuration = Duration(milliseconds: 100);

/// 字幕编辑纯逻辑。
///
/// 目前只支持句子级结构操作。所有方法都会返回新的句子列表并重新编号，
/// 让 UI 和持久化层不必各自维护 index 连续性。
class SubtitleEditEngine {
  const SubtitleEditEngine();

  /// 将 [index] 对应句子与下一句合并。
  List<Sentence> mergeWithNext(List<Sentence> sentences, int index) {
    if (index < 0 || index >= sentences.length - 1) {
      return sentences;
    }

    final next = [...sentences];
    final current = next[index];
    final following = next[index + 1];
    next[index] = current.copyWith(
      text: _joinSentenceText(current.text, following.text),
      endTime: following.endTime,
      isBookmarked: current.isBookmarked || following.isBookmarked,
    );
    next.removeAt(index + 1);
    return _reindex(next);
  }

  /// 删除指定句子；不允许删除到空字幕。
  List<Sentence> deleteSentence(List<Sentence> sentences, int index) {
    if (sentences.length <= 1 || index < 0 || index >= sentences.length) {
      return sentences;
    }

    final next = [...sentences]..removeAt(index);
    return _reindex(next);
  }

  /// 调整 [index] 句子某一端边界到 [target]，返回新列表。
  ///
  /// 自动按相邻句最近边界与 [kMinSentenceDuration] 钳制，保证句子互不重叠、
  /// 顺序不变，且只修改本句、不影响相邻句。无实际变化时返回原列表（同一引用）。
  ///
  /// - start 端：下限为上一句的 `endTime`（首句为 0），上限为本句 `endTime` 减去最小句长。
  /// - end 端：下限为本句 `startTime` 加上最小句长，上限为下一句的 `startTime`
  ///   （末句为 [totalDuration]）。
  List<Sentence> adjustBoundary(
    List<Sentence> sentences,
    int index,
    BoundaryEdge edge,
    Duration target, {
    required Duration totalDuration,
  }) {
    if (index < 0 || index >= sentences.length) return sentences;
    final current = sentences[index];

    final Duration clamped;
    if (edge == BoundaryEdge.start) {
      final lower = index > 0 ? sentences[index - 1].endTime : Duration.zero;
      final upper = current.endTime - kMinSentenceDuration;
      if (upper < lower) return sentences; // 句子过短，无法调整。
      clamped = _clampDuration(target, lower, upper);
      if (clamped == current.startTime) return sentences;
    } else {
      final lower = current.startTime + kMinSentenceDuration;
      final upper = index < sentences.length - 1
          ? sentences[index + 1].startTime
          : totalDuration;
      if (upper < lower) return sentences; // 句子过短，无法调整。
      clamped = _clampDuration(target, lower, upper);
      if (clamped == current.endTime) return sentences;
    }

    final next = [...sentences];
    next[index] = edge == BoundaryEdge.start
        ? current.copyWith(startTime: clamped)
        : current.copyWith(endTime: clamped);
    return next;
  }

  Duration _clampDuration(Duration value, Duration lower, Duration upper) {
    if (value < lower) return lower;
    if (value > upper) return upper;
    return value;
  }

  List<Sentence> _reindex(List<Sentence> sentences) {
    return [
      for (final (index, sentence) in sentences.indexed)
        sentence.copyWith(index: index),
    ];
  }

  String _joinSentenceText(String first, String second) {
    final left = first.trim();
    final right = second.trim();
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;
    return '$left $right';
  }
}
