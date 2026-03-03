import '../repositories/sync_repository.dart';

/// 同步服务
/// 
/// 提供高级同步功能
class SyncService {
  final SyncRepository _repository;

  SyncService(this._repository);
  
  /// 获取底层 repository（用于设置密码等）
  SyncRepository get repository => _repository;

  /// 执行首次同步
  /// 
  /// 登录后调用，将本地数据上传到云端
  Future<void> performInitialSync() async {
    print('[SyncService] 执行首次同步');
    await _repository.syncAll();
  }

  /// 执行增量同步
  /// 
  /// 定期调用，同步最新变更
  Future<void> performIncrementalSync() async {
    print('[SyncService] 执行增量同步');
    await _repository.syncAll();
  }

  /// 获取上次同步时间
  Future<DateTime?> getLastSyncTime() async {
    return await _repository.getLastSyncTime();
  }

  /// 检查是否需要同步
  Future<bool> needsSync() async {
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;

    // 如果超过 5 分钟未同步，则需要同步
    final now = DateTime.now();
    final diff = now.difference(lastSync);
    return diff.inMinutes > 5;
  }
}
