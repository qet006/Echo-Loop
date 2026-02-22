import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/bookmarks.dart';

part 'bookmark_dao.g.dart';

/// 书签 DAO
/// 提供书签的 CRUD 操作
@DriftAccessor(tables: [Bookmarks])
class BookmarkDao extends DatabaseAccessor<AppDatabase>
    with _$BookmarkDaoMixin {
  BookmarkDao(super.db);

  /// 获取指定音频的所有未删除书签
  Future<List<Bookmark>> getByAudioId(String audioItemId) {
    return (select(bookmarks)
          ..where(
            (t) => t.audioItemId.equals(audioItemId) & t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.sentenceIndex)]))
        .get();
  }

  /// 监听指定音频的所有未删除书签
  Stream<List<Bookmark>> watchByAudioId(String audioItemId) {
    return (select(bookmarks)
          ..where(
            (t) => t.audioItemId.equals(audioItemId) & t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.sentenceIndex)]))
        .watch();
  }

  /// 添加书签
  ///
  /// 以 (audioItemId, sentenceIndex) 为冲突键，冲突时更新已有行。
  Future<void> addBookmark(BookmarksCompanion entry) {
    return into(bookmarks).insert(
      entry,
      onConflict: DoUpdate(
        (old) => BookmarksCompanion(
          sentenceText: entry.sentenceText,
          startTime: entry.startTime,
          endTime: entry.endTime,
          updatedAt: entry.updatedAt,
          deletedAt: const Value(null),
          syncStatus: const Value(0),
        ),
        target: [bookmarks.audioItemId, bookmarks.sentenceIndex],
      ),
    );
  }

  /// 批量添加书签（用于迁移）
  Future<void> batchInsert(List<BookmarksCompanion> entries) async {
    await batch((b) {
      b.insertAll(bookmarks, entries, mode: InsertMode.insertOrReplace);
    });
  }

  /// 移除指定音频的某个书签（通过句子索引）
  Future<void> removeBookmark(String audioItemId, int sentenceIndex) {
    return (delete(bookmarks)..where(
          (t) =>
              t.audioItemId.equals(audioItemId) &
              t.sentenceIndex.equals(sentenceIndex),
        ))
        .go();
  }

  /// 移除指定音频的多个书签（通过句子索引集合）
  Future<void> removeBookmarks(String audioItemId, Set<int> sentenceIndices) {
    return (delete(bookmarks)..where(
          (t) =>
              t.audioItemId.equals(audioItemId) &
              t.sentenceIndex.isIn(sentenceIndices),
        ))
        .go();
  }

  /// 移除指定音频的所有书签
  Future<void> removeAllForAudio(String audioItemId) {
    return (delete(
      bookmarks,
    )..where((t) => t.audioItemId.equals(audioItemId))).go();
  }

  /// 获取指定音频的书签句子索引集合
  Future<Set<int>> getBookmarkedIndices(String audioItemId) async {
    final rows =
        await (select(bookmarks)..where(
              (t) => t.audioItemId.equals(audioItemId) & t.deletedAt.isNull(),
            ))
            .get();
    return rows.map((r) => r.sentenceIndex).toSet();
  }
}
