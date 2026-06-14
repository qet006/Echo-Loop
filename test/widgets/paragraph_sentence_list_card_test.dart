import 'package:echo_loop/models/retell_settings.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/widgets/common/paragraph_sentence_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

List<Sentence> _sentences(int count) {
  return List.generate(
    count,
    (index) => Sentence(
      index: index,
      text: 'Line${index + 1}',
      startTime: Duration(seconds: index),
      endTime: Duration(seconds: index + 1),
    ),
  );
}

Widget _buildCard({
  required List<Sentence> sentences,
  required int playingSentenceIndex,
  required bool autoFocusEnabled,
  Duration autoFocusResumeDelay = const Duration(seconds: 2),
}) {
  return createTestApp(
    Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          height: 180,
          child: ParagraphSentenceListCard(
            sentences: sentences,
            displayMode: RetellDisplayMode.showAll,
            keywordMap: const {},
            playingSentenceIndex: playingSentenceIndex,
            autoFocusEnabled: autoFocusEnabled,
            autoFocusResumeDelay: autoFocusResumeDelay,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('ParagraphSentenceListCard focus', () {
    testWidgets('focus 开启时播放句变化会自动滚到可见区域', (tester) async {
      final sentences = _sentences(30);

      await tester.pumpWidget(
        _buildCard(
          sentences: sentences,
          playingSentenceIndex: 0,
          autoFocusEnabled: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Line1'), findsOneWidget);

      await tester.pumpWidget(
        _buildCard(
          sentences: sentences,
          playingSentenceIndex: 24,
          autoFocusEnabled: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Line25'), findsOneWidget);
    });

    testWidgets('目标句已完整可见时不强制滚动', (tester) async {
      final sentences = _sentences(30);

      await tester.pumpWidget(
        _buildCard(
          sentences: sentences,
          playingSentenceIndex: 0,
          autoFocusEnabled: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Line1'), findsOneWidget);

      await tester.pumpWidget(
        _buildCard(
          sentences: sentences,
          playingSentenceIndex: 2,
          autoFocusEnabled: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Line1'), findsOneWidget);
      expect(find.text('Line3'), findsOneWidget);
    });

    testWidgets('focus 关闭时播放句变化不自动抢滚动位置', (tester) async {
      final sentences = _sentences(30);

      await tester.pumpWidget(
        _buildCard(
          sentences: sentences,
          playingSentenceIndex: 0,
          autoFocusEnabled: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Line1'), findsOneWidget);

      await tester.pumpWidget(
        _buildCard(
          sentences: sentences,
          playingSentenceIndex: 24,
          autoFocusEnabled: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Line25'), findsNothing);
    });

    testWidgets('用户滚动后延迟恢复 focus', (tester) async {
      final sentences = _sentences(40);

      await tester.pumpWidget(
        _buildCard(
          sentences: sentences,
          playingSentenceIndex: 0,
          autoFocusEnabled: true,
          autoFocusResumeDelay: const Duration(milliseconds: 200),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pump();

      await tester.pumpWidget(
        _buildCard(
          sentences: sentences,
          playingSentenceIndex: 30,
          autoFocusEnabled: true,
          autoFocusResumeDelay: const Duration(milliseconds: 200),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Line31'), findsNothing);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.text('Line31'), findsOneWidget);
    });
  });
}
