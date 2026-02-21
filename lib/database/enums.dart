/// 同步状态枚举
/// 用于标记数据的同步状态，为未来服务器同步做准备
enum SyncStatus {
  /// 已同步
  synced(0),

  /// 等待上传
  pendingUpload(1),

  /// 等待删除
  pendingDelete(2);

  const SyncStatus(this.value);
  final int value;

  static SyncStatus fromValue(int value) {
    return SyncStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SyncStatus.synced,
    );
  }
}
