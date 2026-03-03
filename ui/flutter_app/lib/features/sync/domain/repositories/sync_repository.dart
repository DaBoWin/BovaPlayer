/// 同步仓库接口
/// 
/// 定义数据同步的抽象方法
abstract class SyncRepository {
  /// 同步媒体服务器列表
  Future<void> syncMediaServers();

  /// 同步网络连接列表
  Future<void> syncNetworkConnections();

  /// 同步播放历史
  Future<void> syncPlayHistory();

  /// 同步收藏列表
  Future<void> syncFavorites();

  /// 同步用户设置
  Future<void> syncUserSettings();

  /// 执行完整同步
  Future<void> syncAll();

  /// 获取上次同步时间
  Future<DateTime?> getLastSyncTime();
}
