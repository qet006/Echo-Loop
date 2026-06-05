import 'package:echo_loop/features/subtitle_editor/subtitle_edit_engine.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = SubtitleEditEngine();

  List<Sentence> sentences() => [
    Sentence(
      index: 0,
      text: 'Hello world.',
      startTime: Duration.zero,
      endTime: const Duration(seconds: 2),
    ),
    Sentence(
      index: 1,
      text: 'Next sentence.',
      startTime: const Duration(seconds: 2),
      endTime: const Duration(seconds: 4),
    ),
    Sentence(
      index: 2,
      text: 'Last one.',
      startTime: const Duration(seconds: 4),
      endTime: const Duration(seconds: 6),
    ),
  ];

  group('SubtitleEditEngine', () {
    test('mergeWithNext 合并文本和时间并重排 index', () {
      final result = engine.mergeWithNext(sentences(), 0);

      expect(result, hasLength(2));
      expect(result[0].index, 0);
      expect(result[0].text, 'Hello world. Next sentence.');
      expect(result[0].startTime, Duration.zero);
      expect(result[0].endTime, const Duration(seconds: 4));
      expect(result[1].index, 1);
      expect(result[1].text, 'Last one.');
    });

    test('mergeWithNext 最后一句不变', () {
      final input = sentences();
      final result = engine.mergeWithNext(input, 2);

      expect(result, same(input));
    });

    test('deleteSentence 删除句子并重排 index', () {
      final result = engine.deleteSentence(sentences(), 1);

      expect(result, hasLength(2));
      expect(result[0].index, 0);
      expect(result[0].text, 'Hello world.');
      expect(result[1].index, 1);
      expect(result[1].text, 'Last one.');
    });

    test('deleteSentence 不允许删除到空字幕', () {
      final input = [
        Sentence(
          index: 0,
          text: 'Only one.',
          startTime: Duration.zero,
          endTime: const Duration(seconds: 1),
        ),
      ];

      final result = engine.deleteSentence(input, 0);

      expect(result, same(input));
    });
  });

  group('SubtitleEditEngine.adjustBoundary', () {
    const total = Duration(seconds: 6);

    test('调整 start 在合法范围内生效，且不动相邻句', () {
      final result = engine.adjustBoundary(
        sentences(),
        1,
        BoundaryEdge.start,
        const Duration(milliseconds: 2500),
        totalDuration: total,
      );

      expect(result[1].startTime, const Duration(milliseconds: 2500));
      expect(result[1].endTime, const Duration(seconds: 4));
      // 相邻句不变。
      expect(result[0].endTime, const Duration(seconds: 2));
      expect(result[2].startTime, const Duration(seconds: 4));
    });

    test('start 不能拖到上一句 endTime 之前（钳制到 prev.end）', () {
      final result = engine.adjustBoundary(
        sentences(),
        1,
        BoundaryEdge.start,
        const Duration(milliseconds: 500), // < prev.end(2s)
        totalDuration: total,
      );

      expect(result[1].startTime, const Duration(seconds: 2));
    });

    test('end 不能拖到下一句 startTime 之后（钳制到 next.start）', () {
      final result = engine.adjustBoundary(
        sentences(),
        1,
        BoundaryEdge.end,
        const Duration(milliseconds: 5000), // > next.start(4s)
        totalDuration: total,
      );

      expect(result[1].endTime, const Duration(seconds: 4));
    });

    test('start 不能越过本句 end 减最小句长', () {
      final result = engine.adjustBoundary(
        sentences(),
        1,
        BoundaryEdge.start,
        const Duration(seconds: 4), // == 本句 end，应被钳到 end - minDur
        totalDuration: total,
      );

      expect(
        result[1].startTime,
        const Duration(seconds: 4) - kMinSentenceDuration,
      );
    });

    test('首句 start 下限为 0', () {
      final result = engine.adjustBoundary(
        sentences(),
        0,
        BoundaryEdge.start,
        const Duration(milliseconds: -500),
        totalDuration: total,
      );

      expect(result[0].startTime, Duration.zero);
    });

    test('末句 end 上限为 totalDuration', () {
      final result = engine.adjustBoundary(
        sentences(),
        2,
        BoundaryEdge.end,
        const Duration(seconds: 99),
        totalDuration: total,
      );

      expect(result[2].endTime, total);
    });

    test('无实际变化时返回同一引用', () {
      final input = sentences();
      final result = engine.adjustBoundary(
        input,
        1,
        BoundaryEdge.start,
        const Duration(seconds: 2), // 已等于当前 start
        totalDuration: total,
      );

      expect(result, same(input));
    });

    test('index 越界返回同一引用', () {
      final input = sentences();
      expect(
        engine.adjustBoundary(
          input,
          9,
          BoundaryEdge.start,
          Duration.zero,
          totalDuration: total,
        ),
        same(input),
      );
    });
  });
}
