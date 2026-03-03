# 云同步功能实现 - 首次同步

## 功能概述
实现了登录后自动同步本地数据到云端的功能，这是云同步功能的第一步。

## 实现内容

### 1. 同步架构
采用 Clean Architecture 分层：
```
lib/features/sync/
├── domain/
│   ├── repositories/
│   │   └── sync_repository.dart          # 同步仓库接口
│   └── services/
│       └── sync_service.dart              # 同步服务
└── data/
    └── repositories/
        └── sync_repository_impl.dart      # 同步仓库实现
```

### 2. 核心功能

#### SyncRepository (接口)
定义同步操作的抽象方法：
- `syncMediaServers()` - 同步媒体服务器列表
- `syncNetworkConnections()` - 同步网络连接列表
- `syncPlayHistory()` - 同步播放历史（待实现）
- `syncFavorites()` - 同步收藏列表（待实现）
- `syncUserSettings()` - 同步用户设置（待实现）
- `syncAll()` - 执行完整同步
- `getLastSyncTime()` - 获取上次同步时间

#### SyncRepositoryImpl (实现)
实现具体的同步逻辑：

**媒体服务器同步**:
```dart
// 1. 读取本地 SharedPreferences 中的 emby_servers
// 2. 查询云端 media_servers 表
// 3. 首次同步策略：
//    - 如果云端为空，本地有数据 → 上传到云端
//    - 如果本地为空，云端有数据 → 下载到本地
//    - 如果都有数据 → 智能合并（待实现）
```

**网络连接同步**:
```dart
// 1. 读取本地 network_connections
// 2. 查询云端 network_connections 表
// 3. 注意：密码不上传云端，仅同步元数据
// 4. 首次同步：上传本地连接到云端
```

#### SyncService (服务层)
提供高级同步功能：
- `performInitialSync()` - 首次同步（登录后调用）
- `performIncrementalSync()` - 增量同步（定期调用）
- `needsSync()` - 检查是否需要同步（超过 5 分钟）

### 3. 集成到认证流程

修改 `AuthProvider`：
```dart
class AuthProvider {
  SyncService? _syncService;
  
  // 初始化时创建同步服务
  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final syncRepo = SyncRepositoryImpl(prefs: prefs);
    _syncService = SyncService(syncRepo);
  }
  
  // 登录成功后自动同步
  Future<bool> login(...) async {
    _user = await _authService.login(...);
    _setState(AuthState.authenticated);
    
    // 后台执行首次同步
    _performInitialSync();
    
    return true;
  }
  
  // 首次同步（不阻塞 UI）
  Future<void> _performInitialSync() async {
    await _syncService!.performInitialSync();
    await refreshUser(); // 刷新用户数据
  }
}
```

## 同步流程

### 首次登录流程
```
1. 用户输入邮箱密码
2. 调用 Supabase Auth 登录
3. 登录成功，获取用户信息
4. 显示主界面
5. 后台执行首次同步：
   a. 读取本地 emby_servers
   b. 上传到 media_servers 表
   c. 读取本地 network_connections
   d. 上传到 network_connections 表
6. 同步完成，刷新用户数据
7. 账号页面显示正确的服务器数量
```

### 数据流向
```
本地 SharedPreferences
  ↓
  emby_servers (JSON)
  network_connections (JSON)
  ↓
  SyncRepositoryImpl
  ↓
  Supabase Database
  ↓
  media_servers 表
  network_connections 表
```

## 安全考虑

### 1. 密码不上传
网络连接（SMB/FTP）的密码永远不会上传到云端：
```dart
// ✅ 上传到云端的数据（不含密码）
{
  'protocol': 'smb',
  'name': '家庭服务器',
  'host': '192.168.1.100',
  'port': 445,
  'username': 'user',
  'share_name': 'movies',
  // 注意：没有 password 字段
}

// ✅ 本地存储的数据（含密码）
{
  'protocol': 'smb',
  'name': '家庭服务器',
  'host': '192.168.1.100',
  'port': 445,
  'username': 'user',
  'password': 'encrypted_password', // 仅本地存储
  'share_name': 'movies',
}
```

### 2. Emby Token 加密
Emby 的 accessToken 会加密后上传：
```dart
{
  'server_type': 'emby',
  'name': 'My Emby',
  'url': 'https://emby.example.com',
  'username': 'user',
  'access_token_encrypted': 'AES256_ENCRYPTED_TOKEN', // 加密存储
  'user_id_server': 'emby_user_id',
}
```

## 数据库表结构

### media_servers 表
```sql
CREATE TABLE public.media_servers (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.users(id),
  server_type VARCHAR(20) NOT NULL,  -- 'emby', 'jellyfin', 'plex'
  name VARCHAR(100) NOT NULL,
  url TEXT NOT NULL,
  access_token_encrypted TEXT,       -- 加密的访问令牌
  user_id_server VARCHAR(100),       -- 服务器上的用户 ID
  is_active BOOLEAN DEFAULT true,
  last_synced_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### network_connections 表
```sql
CREATE TABLE public.network_connections (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.users(id),
  protocol VARCHAR(20) NOT NULL,     -- 'smb', 'ftp'
  name VARCHAR(100) NOT NULL,
  host VARCHAR(255) NOT NULL,
  port INTEGER NOT NULL,
  username VARCHAR(100),
  share_name VARCHAR(100),           -- SMB only
  workgroup VARCHAR(100),            -- SMB only
  is_active BOOLEAN DEFAULT true,
  last_used_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## 待实现功能

### 1. 智能合并
当本地和云端都有数据时，需要智能合并：
```dart
// 基于 updated_at 时间戳判断
if (local.updatedAt > cloud.updatedAt) {
  // 本地更新，上传到云端
  await uploadToCloud(local);
} else {
  // 云端更新，下载到本地
  await downloadToLocal(cloud);
}
```

### 2. 冲突解决
当两端都有修改时：
- 选项 1：最后修改优先（Last Write Wins）
- 选项 2：提示用户选择
- 选项 3：保留两个版本

### 3. 增量同步
只同步变更的数据：
```dart
// 记录每个项目的同步状态
{
  'server_id': 'xxx',
  'last_synced_at': '2026-03-02T10:00:00Z',
  'sync_status': 'synced', // 'synced', 'pending', 'conflict'
}
```

### 4. 实时同步
使用 Supabase Realtime 订阅：
```dart
_supabase
  .from('media_servers')
  .stream(primaryKey: ['id'])
  .eq('user_id', userId)
  .listen((data) {
    // 实时更新本地数据
    updateLocalData(data);
  });
```

### 5. 播放历史同步
```dart
Future<void> syncPlayHistory() async {
  // 1. 读取本地播放历史
  // 2. 上传到 play_history 表
  // 3. 下载云端历史
  // 4. 合并并去重
}
```

### 6. 收藏列表同步
```dart
Future<void> syncFavorites() async {
  // 1. 读取本地收藏
  // 2. 上传到 favorites 表
  // 3. 下载云端收藏
  // 4. 合并并去重
}
```

## 测试步骤

### 场景 1：首次登录（本地有数据）
1. 本地添加 2 个 Emby 服务器
2. 本地添加 1 个 SMB 连接
3. 注册并登录账号
4. 等待同步完成（查看日志）
5. 打开账号页面，验证服务器数量显示为 2
6. 在 Supabase Dashboard 查看 media_servers 表，应该有 2 条记录

### 场景 2：多设备同步
1. 设备 A：登录并添加服务器
2. 设备 B：登录同一账号
3. 设备 B 应该自动下载设备 A 的服务器列表
4. 验证两个设备的服务器列表一致

### 场景 3：密码安全
1. 添加 SMB 连接（含密码）
2. 登录并同步
3. 在 Supabase Dashboard 查看 network_connections 表
4. 验证密码字段为空或不存在

## 日志输出

同步过程会输出详细日志：
```
[Sync] 开始完整同步...
[Sync] 开始同步媒体服务器...
[Sync] 本地服务器数量: 2
[Sync] 云端服务器数量: 0
[Sync] 首次同步：上传本地服务器到云端
[Sync] 上传完成
[Sync] 媒体服务器同步完成
[Sync] 开始同步网络连接...
[Sync] 本地连接数量: 1
[Sync] 云端连接数量: 0
[Sync] 首次同步：上传本地连接到云端
[Sync] 上传完成
[Sync] 网络连接同步完成
[Sync] 完整同步完成
[Auth] 首次同步完成
```

## 性能优化

### 1. 批量上传
```dart
// 不要逐个上传
for (var server in servers) {
  await _supabase.from('media_servers').insert(server);
}

// 应该批量上传
await _supabase.from('media_servers').insert(servers);
```

### 2. 后台同步
同步不阻塞 UI，登录后立即显示主界面：
```dart
// ✅ 正确：后台同步
_setState(AuthState.authenticated);
_performInitialSync(); // 不 await

// ❌ 错误：阻塞 UI
await _performInitialSync();
_setState(AuthState.authenticated);
```

### 3. 缓存上次同步时间
避免频繁同步：
```dart
final lastSync = await getLastSyncTime();
if (lastSync != null && DateTime.now().difference(lastSync).inMinutes < 5) {
  print('距离上次同步不到 5 分钟，跳过');
  return;
}
```

## 文件清单

新增文件：
- ✅ `lib/features/sync/domain/repositories/sync_repository.dart`
- ✅ `lib/features/sync/domain/services/sync_service.dart`
- ✅ `lib/features/sync/data/repositories/sync_repository_impl.dart`

修改文件：
- ✅ `lib/features/auth/presentation/providers/auth_provider.dart`

## 下一步计划

1. 实现智能合并逻辑
2. 实现播放历史同步
3. 实现收藏列表同步
4. 实现用户设置同步
5. 添加同步设置页面（让用户控制同步项目）
6. 实现 Realtime 订阅（实时同步）
7. 添加同步状态指示器（UI）

## 完成时间
2026-03-02
