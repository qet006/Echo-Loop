// 收藏词汇页 TTS 预热接线测试
//
// 验证进入收藏页后 _WordsView 自动预热「单词 + 意群」发音文本，离开时取消。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/daos/audio_item_dao.dart';
import 'package:echo_loop/database/daos/bookmark_dao.dart';
import 'package:echo_loop/database/daos/saved_sense_group_dao.dart';
import 'package:echo_loop/database/daos/saved_word_dao.dart';
import 'package:echo_loop/database/daos/sentence_ai_cache_dao.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/providers/tts/tts_controller_provider.dart';
import 'package:echo_loop/screens/favorites_screen.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:echo_loop/theme/app_theme.dart';

import '../helpers/mock_providers.dart';

class _MockCacheDao extends Mock implements SentenceAiCacheDao {}

class _MockApiClient extends Mock implements SentenceAiApiClient {}

class _MockAudioItemDao extends Mock implements AudioItemDao {
  _MockAudioItemDao() {
    when(() => getById(any())).thenAnswer((_) async => null);
  }
}

class _TestBookmarkDao implements BookmarkDao {
  final StreamController<List<BookmarkWithAudio>> _c;
  _TestBookmarkDao(this._c);
  @override
  Stream<List<BookmarkWithAudio>> watchAllWithAudioName() => _c.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _TestSavedWordDao implements SavedWordDao {
  final StreamController<List<SavedWord>> _c;
  _TestSavedWordDao(this._c);
  @override
  Stream<List<SavedWord>> watchAll() => _c.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _TestSavedSenseGroupDao implements SavedSenseGroupDao {
  final StreamController<List<SavedSenseGroup>> _c;
  _TestSavedSenseGroupDao(this._c);
  @override
  Stream<List<SavedSenseGroup>> watchAll() => _c.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// 录制预热调用的 TTS 控制器：build 跳过真实协调器/数据库，仅记录 prewarm/cancel。
class _RecordingTtsController extends TtsController {
  final List<List<String>> prewarmCalls = [];
  int cancelCount = 0;

  @override
  TtsControllerState build() => const TtsControllerState();

  @override
  Future<void> prewarmTexts(List<String> texts) async {
    prewarmCalls.add(List.of(texts));
  }

  @override
  void cancelTextsPrewarm() => cancelCount++;
}

SavedWord _word(int id, String word) => SavedWord(
  id: id,
  word: word,
  audioItemId: null,
  sentenceIndex: null,
  sentenceText: null,
  sentenceStartMs: null,
  sentenceEndMs: null,
  practiceCount: 0,
  totalStudyMs: 0,
  viewedBack: false,
  lastPracticedAt: null,
  createdAt: DateTime(2026, 1, id),
  updatedAt: DateTime(2026, 1, id),
  deletedAt: null,
  syncStatus: 0,
);

SavedSenseGroup _phrase(int id, String display) => SavedSenseGroup(
  id: id,
  phraseText: display.toLowerCase(),
  displayText: display,
  audioItemId: null,
  sentenceIndex: null,
  sentenceText: null,
  sentenceStartMs: null,
  sentenceEndMs: null,
  groupStartMs: null,
  groupEndMs: null,
  practiceCount: 0,
  totalStudyMs: 0,
  viewedBack: false,
  lastPracticedAt: null,
  createdAt: DateTime(2026, 2, id),
  updatedAt: DateTime(2026, 2, id),
  deletedAt: null,
  syncStatus: 0,
);

void main() {
  late StreamController<List<BookmarkWithAudio>> bookmarkC;
  late StreamController<List<SavedWord>> wordC;
  late StreamController<List<SavedSenseGroup>> phraseC;
  late _RecordingTtsController rec;

  setUp(() {
    bookmarkC = StreamController<List<BookmarkWithAudio>>.broadcast();
    wordC = StreamController<List<SavedWord>>.broadcast();
    phraseC = StreamController<List<SavedSenseGroup>>.broadcast();
    rec = _RecordingTtsController();
  });

  tearDown(() {
    bookmarkC.close();
    wordC.close();
    phraseC.close();
  });

  Widget createWidget() {
    final router = GoRouter(
      initialLocation: '/favorites',
      routes: [
        GoRoute(
          path: '/favorites',
          builder: (context, state) => const FavoritesScreen(),
        ),
        GoRoute(
          path: '/other',
          builder: (context, state) => const Scaffold(body: Text('Other')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        analyticsOverride(),
        ...studyTimeOverrides(),
        bookmarkDaoProvider.overrideWithValue(_TestBookmarkDao(bookmarkC)),
        savedWordDaoProvider.overrideWithValue(_TestSavedWordDao(wordC)),
        savedSenseGroupDaoProvider.overrideWithValue(
          _TestSavedSenseGroupDao(phraseC),
        ),
        audioItemDaoProvider.overrideWithValue(_MockAudioItemDao()),
        audioEngineProvider.overrideWith(() => TestAudioEngine()),
        sentenceAiNotifierProvider.overrideWithValue(
          SentenceAiNotifier(
            cacheDao: _MockCacheDao(),
            apiClient: _MockApiClient(),
          ),
        ),
        ttsControllerProvider.overrideWith(() => rec),
      ],
      child: MaterialApp.router(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    );
  }

  testWidgets('停在句子 tab 不预热词汇', (tester) async {
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([_word(1, 'tomorrow'), _word(2, 'finished')]);
    phraseC.add([_phrase(1, 'can I book a table')]);
    await tester.pumpAndSettle();

    // 默认在句子 tab：IndexedStack 虽构建 _WordsView，但未激活不应预热。
    expect(rec.prewarmCalls, isEmpty);
  });

  testWidgets('切到词汇 tab 后预热「单词 + 意群」全部发音文本', (tester) async {
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([_word(1, 'tomorrow'), _word(2, 'finished')]);
    phraseC.add([_phrase(1, 'can I book a table')]);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();

    expect(rec.prewarmCalls, isNotEmpty);
    final texts = rec.prewarmCalls.last;
    // 单词用 word，意群用 displayText（原始大小写）。
    expect(texts, containsAll(['tomorrow', 'finished', 'can I book a table']));
  });

  testWidgets('切离词汇 tab 取消在途预热', (tester) async {
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([_word(1, 'tomorrow')]);
    phraseC.add([]);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();
    final cancelsBefore = rec.cancelCount;

    await tester.tap(find.textContaining('Sentences'));
    await tester.pumpAndSettle();

    expect(rec.cancelCount, greaterThan(cancelsBefore));
  });

  testWidgets('数据流重发相同列表不重复重启预热（签名去重）', (tester) async {
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([_word(1, 'tomorrow')]);
    phraseC.add([]);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();

    final before = rec.prewarmCalls.length;
    expect(before, greaterThanOrEqualTo(1));

    // drift 流可能重发内容相同的新实例列表 → 触发 _WordsView 重建，但发音文本不变。
    wordC.add([_word(1, 'tomorrow')]);
    phraseC.add([]);
    await tester.pumpAndSettle();

    expect(rec.prewarmCalls.length, before, reason: '文本未变不应重启预热');
  });

  testWidgets('离开收藏页取消在途预热', (tester) async {
    await tester.pumpWidget(createWidget());
    bookmarkC.add([]);
    wordC.add([_word(1, 'tomorrow')]);
    phraseC.add([]);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Vocabulary'));
    await tester.pumpAndSettle();

    // 导航离开 → _WordsView dispose → cancelTextsPrewarm。
    final ctx = tester.element(find.byType(FavoritesScreen));
    GoRouter.of(ctx).go('/other');
    await tester.pumpAndSettle();

    expect(rec.cancelCount, greaterThanOrEqualTo(1));
  });
}
