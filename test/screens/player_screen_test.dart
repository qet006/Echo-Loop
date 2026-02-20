/// PlayerScreen 测试
///
/// 测试播放器页面的渲染和交互。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/screens/player_screen.dart';
import 'package:fluency/models/audio_engine_state.dart';
import 'package:fluency/providers/settings_provider.dart';
import 'package:fluency/providers/audio_library_provider.dart';
import 'package:fluency/providers/collection_provider.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

/// 有音频状态的通用 provider overrides
List<Override> _audioOverrides({
  ListeningPracticeState? practiceState,
  AudioEngineState? engineState,
}) {
  return [
    appSettingsProvider.overrideWith(() => TestAppSettings()),
    audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
    collectionListProvider.overrideWith(() => TestCollectionList()),
    listeningPracticeProvider.overrideWith(
      () => TestListeningPractice(
        practiceState ?? const ListeningPracticeState(),
      ),
    ),
    audioEngineProvider.overrideWith(
      () => TestAudioEngine(
        initialState:
            engineState ??
            const AudioEngineState(totalDuration: Duration(seconds: 120)),
      ),
    ),
  ];
}

void main() {
  group('PlayerScreen', () {
    group('渲染', () {
      testWidgets('无音频时显示空状态', (tester) async {
        await tester.pumpWidget(createTestScreen(const PlayerScreen()));
        await tester.pumpAndSettle();

        expect(find.text('No audio loaded'), findsOneWidget);
      });

      testWidgets('无音频时 AppBar 显示 Player 标题', (tester) async {
        await tester.pumpWidget(createTestScreen(const PlayerScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Player'), findsOneWidget);
      });

      testWidgets('有音频时显示音频名称作为标题', (tester) async {
        final item = createTestAudioItem(name: 'My Lesson');
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('My Lesson'), findsOneWidget);
      });

      testWidgets('有音频和句子时显示 TabBar', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // TabBar 应显示"全文"和"书签"标签
        expect(find.byType(TabBar), findsOneWidget);
        expect(find.textContaining('Full Text'), findsOneWidget);
        expect(find.textContaining('Bookmarked'), findsOneWidget);
      });

      testWidgets('句子列表正确显示', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 句子文本
        expect(find.text('Test sentence number 1.'), findsOneWidget);
        expect(find.text('Test sentence number 2.'), findsOneWidget);
        expect(find.text('Test sentence number 3.'), findsOneWidget);
      });

      testWidgets('显示 PlaybackControls', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 播放控制栏应存在
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
        expect(find.byIcon(Icons.skip_previous), findsOneWidget);
        expect(find.byIcon(Icons.skip_next), findsOneWidget);
      });

      testWidgets('AppBar 显示设置按钮', (tester) async {
        await tester.pumpWidget(createTestScreen(const PlayerScreen()));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.settings), findsOneWidget);
      });

      testWidgets('AppBar 显示自动滚动切换按钮', (tester) async {
        await tester.pumpWidget(createTestScreen(const PlayerScreen()));
        await tester.pumpAndSettle();

        // 默认启用自动滚动
        expect(find.byIcon(Icons.center_focus_strong), findsOneWidget);
      });

      testWidgets('有音频但无字幕时显示无字幕提示', (tester) async {
        final item = createTestAudioItem();

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: const [], // 无句子
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('No Subtitle'), findsOneWidget);
        expect(find.byIcon(Icons.subtitles_off_outlined), findsOneWidget);
      });
    });

    group('交互', () {
      testWidgets('点击设置按钮打开设置对话框', (tester) async {
        await tester.pumpWidget(createTestScreen(const PlayerScreen()));
        await tester.pumpAndSettle();

        // 点击设置按钮
        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();

        // 应弹出 SettingsDialog
        expect(find.text('Settings'), findsAtLeast(1));
        expect(find.text('Sentence Repeat'), findsOneWidget);
      });

      testWidgets('切换全文/书签 Tab', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 点击书签标签
        await tester.tap(find.textContaining('Bookmarked'));
        await tester.pumpAndSettle();

        // 应显示无书签提示
        expect(find.text('No bookmarked sentences'), findsOneWidget);
      });
    });
  });
}
