# BovaPlayer 云同步账号体系设计

## 1. 账号体系概述

### 1.1 版本定位

| 版本 | 定价 | 目标用户 | 核心价值 |
|------|------|----------|----------|
| **社区免费版** | 免费 | 普通用户 | 基础播放 + 有限同步 |
| **Pro 版** | ¥68/年 或 ¥9/月 | 重度用户 | 完整同步 + 高级功能 |
| **永久版** | ¥298 一次性 | 忠实用户 | 终身 Pro 权益 |

### 1.2 功能对比

| 功能模块 | 社区免费版 | Pro 版 | 永久版 |
|---------|-----------|--------|--------|
| **基础播放** | ✅ | ✅ | ✅ |
| **本地媒体库** | ✅ | ✅ | ✅ |
| **Emby/Jellyfin/Plex** | ✅ | ✅ | ✅ |
| **SMB/FTP 支持** | ✅ | ✅ | ✅ |
| **云同步 - 服务器列表** | ✅ 最多 10 个 | ✅ 无限制 | ✅ 无限制 |
| **云同步 - 播放历史** | ✅ 最近 30 天 | ✅ 无限制 | ✅ 无限制 |
| **云同步 - 收藏列表** | ✅ 最多 50 个 | ✅ 无限制 | ✅ 无限制 |
| **云同步 - 设置同步** | ✅ | ✅ | ✅ |
| **GitHub 同步** | ❌ | ✅ | ✅ |
| **多设备同步** | ✅ 最多 2 台 | ✅ 最多 5 台 | ✅ 无限制 |
| **云存储空间** | 100MB | 1GB | 5GB |
| **HDR/Dolby Vision** | ✅ | ✅ | ✅ |
| **硬件解码** | ✅ | ✅ | ✅ |
| **主题定制** | 基础主题 | ✅ 全部主题 | ✅ 全部主题 |
| **插件系统** | ❌ | ✅ | ✅ |
| **优先支持** | ❌ | ✅ | ✅ |
| **无广告** | ✅ | ✅ | ✅ |

---

## 2. 云同步方案设计

### 2.1 双模式同步架构

#### 模式 1: Supabase 云同步（默认）
- **适用**: 大多数用户
- **优点**: 开箱即用、实时同步、跨设备快速
- **数据存储**: Supabase PostgreSQL
- **认证**: Supabase Auth

#### 模式 2: GitHub 同步（Pro/永久版）
- **适用**: 注重隐私、技术用户
- **优点**: 数据完全自主、版本控制、免费无限
- **数据存储**: GitHub Private Repository
- **认证**: GitHub OAuth + Personal Access Token

### 2.2 同步模式对比

| 特性 | Supabase 同步 | GitHub 同步 |
|------|--------------|-------------|
| **实时性** | 实时（< 2s） | 准实时（5-30s） |
| **存储空间** | 100MB - 5GB | 无限制 |
| **隐私性** | 中等（第三方服务） | 高（自主控制） |
| **技术门槛** | 低 | 中等 |
| **版本控制** | ❌ | ✅ Git 历史 |
| **离线支持** | ✅ | ✅ |
| **成本** | 免费额度有限 | 完全免费 |
| **适用版本** | 所有版本 | Pro/永久版 |


---

## 3. 数据加密与安全

### 3.1 加密策略

#### 本地加密存储
```dart
// 使用 flutter_secure_storage 加密存储敏感信息
class SecureStorage {
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  
  // 加密存储服务器信息
  Future<void> saveServerInfo(ServerInfo server) async {
    final encrypted = await _encrypt(server.toJson());
    await _storage.write(key: 'server_${server.id}', value: encrypted);
  }
  
  // 加密算法: AES-256-GCM
  Future<String> _encrypt(String data) async {
    final key = await _getOrCreateEncryptionKey();
    final cipher = AES(key, mode: AESMode.gcm);
    return cipher.encrypt(data);
  }
}
```

#### 云端加密
- **Emby/Jellyfin Token**: AES-256 加密后上传
- **SMB/FTP 密码**: 仅本地存储，不上传云端
- **用户密码**: bcrypt 哈希（Supabase 自动处理）

### 3.2 敏感数据处理

| 数据类型 | 本地存储 | 云端存储 | 加密方式 |
|---------|---------|---------|---------|
| **用户密码** | ❌ | ✅ Hash | bcrypt |
| **Emby Token** | ✅ 加密 | ✅ 加密 | AES-256 |
| **SMB 密码** | ✅ 加密 | ❌ 不上传 | AES-256 |
| **FTP 密码** | ✅ 加密 | ❌ 不上传 | AES-256 |
| **播放历史** | ✅ 明文 | ✅ 明文 | 无 |
| **收藏列表** | ✅ 明文 | ✅ 明文 | 无 |
| **用户设置** | ✅ 明文 | ✅ 明文 | 无 |

**安全原则**:
- 🔒 SMB/FTP 密码永不上传云端
- 🔒 媒体服务器 Token 加密后上传
- 🔒 本地使用设备密钥加密
- 🔒 云端使用用户密钥加密

---

## 4. 后端架构设计

### 4.1 技术栈选择

#### 主后端: Supabase (推荐)
```yaml
服务:
  - 认证: Supabase Auth
  - 数据库: PostgreSQL
  - 实时同步: Realtime Subscriptions
  - 存储: Supabase Storage
  - Edge Functions: Deno (可选)

优势:
  - 开源可自建
  - 免费额度充足
  - Flutter SDK 完善
  - 实时同步内置
  - 行级安全策略
```

#### 备选方案: 自建后端
```yaml
技术栈:
  - 后端框架: FastAPI (Python) / NestJS (TypeScript)
  - 数据库: PostgreSQL
  - 缓存: Redis
  - 认证: JWT
  - 实时: WebSocket
  - 部署: Docker + Railway/Fly.io

适用场景:
  - 需要完全控制
  - 特殊功能需求
  - 数据合规要求
```

### 4.2 数据库设计

#### 用户表 (users)
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR(255) UNIQUE NOT NULL,
  username VARCHAR(50),
  avatar_url TEXT,
  
  -- 账号类型
  account_type VARCHAR(20) DEFAULT 'free', -- free, pro, lifetime
  pro_expires_at TIMESTAMP, -- Pro 到期时间
  
  -- 限额
  max_servers INTEGER DEFAULT 3,
  max_devices INTEGER DEFAULT 2,
  storage_quota_mb INTEGER DEFAULT 100,
  
  -- 统计
  storage_used_mb INTEGER DEFAULT 0,
  device_count INTEGER DEFAULT 0,
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 索引
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_account_type ON users(account_type);
```

#### 设备表 (devices)
```sql
CREATE TABLE devices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  
  device_name VARCHAR(100),
  device_type VARCHAR(20), -- android, ios, windows, macos, linux
  device_id VARCHAR(255) UNIQUE, -- 设备唯一标识
  
  last_active_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  
  UNIQUE(user_id, device_id)
);

CREATE INDEX idx_devices_user_id ON devices(user_id);
```

#### 媒体服务器表 (media_servers)
```sql
CREATE TABLE media_servers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  
  server_type VARCHAR(20), -- emby, jellyfin, plex
  name VARCHAR(100),
  url TEXT NOT NULL,
  
  -- 加密的认证信息
  access_token_encrypted TEXT,
  user_id_server VARCHAR(100),
  
  is_active BOOLEAN DEFAULT true,
  last_synced_at TIMESTAMP,
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_media_servers_user_id ON media_servers(user_id);
```

#### 网络连接表 (network_connections)
```sql
CREATE TABLE network_connections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  
  protocol VARCHAR(20), -- smb, ftp
  name VARCHAR(100),
  host VARCHAR(255),
  port INTEGER,
  
  -- 注意: 密码不存储，仅存储连接元数据
  username VARCHAR(100),
  share_name VARCHAR(100), -- SMB only
  
  is_active BOOLEAN DEFAULT true,
  last_used_at TIMESTAMP,
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_network_connections_user_id ON network_connections(user_id);
```

#### 播放历史表 (play_history)
```sql
CREATE TABLE play_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  server_id UUID REFERENCES media_servers(id) ON DELETE CASCADE,
  
  item_id VARCHAR(100), -- 媒体服务器的 item ID
  item_name TEXT,
  item_type VARCHAR(20), -- movie, episode, video
  
  -- 播放位置
  position_seconds INTEGER,
  duration_seconds INTEGER,
  progress_percent DECIMAL(5,2),
  
  -- 元数据
  thumbnail_url TEXT,
  season_number INTEGER,
  episode_number INTEGER,
  
  last_played_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW(),
  
  UNIQUE(user_id, server_id, item_id)
);

CREATE INDEX idx_play_history_user_id ON play_history(user_id);
CREATE INDEX idx_play_history_last_played ON play_history(last_played_at DESC);
```

#### 收藏表 (favorites)
```sql
CREATE TABLE favorites (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  server_id UUID REFERENCES media_servers(id) ON DELETE CASCADE,
  
  item_id VARCHAR(100),
  item_name TEXT,
  item_type VARCHAR(20),
  thumbnail_url TEXT,
  
  created_at TIMESTAMP DEFAULT NOW(),
  
  UNIQUE(user_id, server_id, item_id)
);

CREATE INDEX idx_favorites_user_id ON favorites(user_id);
```

#### 用户设置表 (user_settings)
```sql
CREATE TABLE user_settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE UNIQUE,
  
  -- 设置 JSON
  settings_json JSONB DEFAULT '{}',
  
  -- 同步配置
  sync_enabled BOOLEAN DEFAULT true,
  sync_mode VARCHAR(20) DEFAULT 'supabase', -- supabase, github
  github_repo VARCHAR(255), -- Pro/Lifetime only
  
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_user_settings_user_id ON user_settings(user_id);
```

#### 订阅记录表 (subscriptions)
```sql
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  
  subscription_type VARCHAR(20), -- pro_monthly, pro_yearly, lifetime
  status VARCHAR(20), -- active, expired, cancelled
  
  -- 支付信息
  payment_method VARCHAR(50), -- alipay, wechat, stripe
  transaction_id VARCHAR(255),
  amount_cny DECIMAL(10,2),
  
  started_at TIMESTAMP,
  expires_at TIMESTAMP,
  cancelled_at TIMESTAMP,
  
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
```

### 4.3 行级安全策略 (RLS)

```sql
-- 用户只能访问自己的数据
ALTER TABLE media_servers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only access their own servers"
  ON media_servers
  FOR ALL
  USING (auth.uid() = user_id);

-- 同样应用到其他表
ALTER TABLE play_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can only access their own history"
  ON play_history FOR ALL USING (auth.uid() = user_id);

ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can only access their own favorites"
  ON favorites FOR ALL USING (auth.uid() = user_id);
```


---

## 5. GitHub 同步实现方案

### 5.1 GitHub 同步架构

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│   客户端     │ ◄─────► │ GitHub API   │ ◄─────► │  Private    │
│  (Flutter)  │         │              │         │  Repository │
└─────────────┘         └──────────────┘         └─────────────┘
      │
      │ 本地缓存
      ▼
┌─────────────┐
│   SQLite    │
└─────────────┘
```

### 5.2 数据存储结构

#### GitHub Repository 结构
```
bovaplayer-sync/
├── .github/
│   └── workflows/
│       └── validate.yml          # 数据验证
├── servers/
│   ├── emby_servers.json         # Emby 服务器列表
│   ├── jellyfin_servers.json     # Jellyfin 服务器列表
│   └── plex_servers.json         # Plex 服务器列表
├── history/
│   ├── 2026-03/
│   │   ├── play_history.json     # 按月分片
│   │   └── metadata.json
│   └── index.json                # 历史索引
├── favorites/
│   └── favorites.json            # 收藏列表
├── settings/
│   └── user_settings.json        # 用户设置
├── devices/
│   └── devices.json              # 设备列表
└── README.md                     # 说明文档
```

#### 数据文件格式示例

**servers/emby_servers.json**
```json
{
  "version": "1.0",
  "updated_at": "2026-03-02T10:30:00Z",
  "servers": [
    {
      "id": "uuid-1",
      "name": "家庭 Emby",
      "url": "https://emby.example.com",
      "access_token_encrypted": "encrypted_token_here",
      "user_id": "emby_user_id",
      "is_active": true,
      "created_at": "2026-01-01T00:00:00Z",
      "updated_at": "2026-03-02T10:30:00Z"
    }
  ]
}
```

**history/2026-03/play_history.json**
```json
{
  "version": "1.0",
  "month": "2026-03",
  "updated_at": "2026-03-02T10:30:00Z",
  "items": [
    {
      "id": "uuid-1",
      "server_id": "uuid-server-1",
      "item_id": "12345",
      "item_name": "电影名称",
      "item_type": "movie",
      "position_seconds": 3600,
      "duration_seconds": 7200,
      "progress_percent": 50.0,
      "last_played_at": "2026-03-02T10:00:00Z"
    }
  ]
}
```

### 5.3 GitHub 同步流程

#### 初始化流程
```dart
class GitHubSyncService {
  final GitHub _github;
  final String _repoName = 'bovaplayer-sync';
  
  // 1. 初始化 GitHub 同步
  Future<void> initialize() async {
    // 检查仓库是否存在
    final repoExists = await _checkRepository();
    
    if (!repoExists) {
      // 创建私有仓库
      await _createRepository();
      // 初始化目录结构
      await _initializeStructure();
    }
    
    // 克隆到本地缓存
    await _cloneOrPull();
  }
  
  // 2. 创建私有仓库
  Future<void> _createRepository() async {
    await _github.repositories.createRepository(
      RepositorySlug('user', _repoName),
      private: true,
      description: 'BovaPlayer 云同步数据（自动生成，请勿手动修改）',
    );
  }
}
```

#### 同步流程
```dart
// 上传数据到 GitHub
Future<void> syncToGitHub() async {
  // 1. 准备数据
  final servers = await _prepareServersData();
  final history = await _prepareHistoryData();
  final favorites = await _prepareFavoritesData();
  
  // 2. 更新本地 Git 仓库
  await _updateLocalRepo({
    'servers/emby_servers.json': servers,
    'history/${_currentMonth()}/play_history.json': history,
    'favorites/favorites.json': favorites,
  });
  
  // 3. Commit 并 Push
  await _gitCommitAndPush('Sync from ${_deviceName} at ${DateTime.now()}');
}

// 从 GitHub 下载数据
Future<void> syncFromGitHub() async {
  // 1. Pull 最新数据
  await _gitPull();
  
  // 2. 读取数据文件
  final servers = await _readJsonFile('servers/emby_servers.json');
  final history = await _readJsonFile('history/${_currentMonth()}/play_history.json');
  
  // 3. 更新本地数据库
  await _updateLocalDatabase(servers, history);
}
```

#### 冲突解决
```dart
class ConflictResolver {
  // 使用 "最后写入获胜" + 时间戳策略
  Future<void> resolveConflict(LocalData local, RemoteData remote) async {
    if (remote.updatedAt.isAfter(local.updatedAt)) {
      // 远程更新，使用远程数据
      await _applyRemoteData(remote);
    } else {
      // 本地更新，保持本地数据并推送
      await _pushLocalData(local);
    }
  }
}
```

### 5.4 GitHub API 配置

```dart
class GitHubConfig {
  // 使用 Personal Access Token (PAT)
  static const scopes = [
    'repo',  // 完整仓库访问权限
  ];
  
  // OAuth 流程
  Future<String> authenticate() async {
    // 1. 打开 GitHub OAuth 页面
    final authUrl = 'https://github.com/login/oauth/authorize'
        '?client_id=$clientId'
        '&scope=repo'
        '&redirect_uri=$redirectUri';
    
    // 2. 用户授权后获取 code
    final code = await _launchAuthFlow(authUrl);
    
    // 3. 交换 access token
    final token = await _exchangeToken(code);
    
    // 4. 安全存储 token
    await _secureStorage.write(key: 'github_token', value: token);
    
    return token;
  }
}
```

---

## 6. 账号管理后端服务

### 6.1 服务架构

```
┌──────────────────────────────────────────────────────┐
│                    客户端层                           │
│  Flutter App (Android/iOS/Windows/macOS/Linux)      │
└────────────────┬─────────────────────────────────────┘
                 │
                 │ HTTPS/WSS
                 ▼
┌──────────────────────────────────────────────────────┐
│                  API Gateway                         │
│              (Supabase Edge Functions)               │
└────────────────┬─────────────────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
┌──────────────┐   ┌──────────────┐
│  Supabase    │   │   GitHub     │
│   Auth       │   │     API      │
└──────┬───────┘   └──────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────┐
│              PostgreSQL Database                     │
│  (用户、订阅、服务器、历史、收藏、设置)                │
└──────────────────────────────────────────────────────┘
```

### 6.2 核心 API 设计

#### 认证 API

```typescript
// POST /auth/register
interface RegisterRequest {
  email: string;
  password: string;
  username?: string;
}

interface RegisterResponse {
  user: User;
  session: Session;
  account_type: 'free';
}

// POST /auth/login
interface LoginRequest {
  email: string;
  password: string;
}

// POST /auth/oauth/github
interface GitHubOAuthRequest {
  code: string;
}
```

#### 账号管理 API

```typescript
// GET /api/account/info
interface AccountInfo {
  user: User;
  account_type: 'free' | 'pro' | 'lifetime';
  pro_expires_at?: string;
  limits: {
    max_servers: number;
    max_devices: number;
    storage_quota_mb: number;
  };
  usage: {
    server_count: number;
    device_count: number;
    storage_used_mb: number;
  };
}

// POST /api/account/upgrade
interface UpgradeRequest {
  plan: 'pro_monthly' | 'pro_yearly' | 'lifetime';
  payment_method: 'alipay' | 'wechat' | 'stripe';
}

// POST /api/account/cancel
interface CancelSubscriptionRequest {
  reason?: string;
}
```

#### 同步配置 API

```typescript
// GET /api/sync/config
interface SyncConfig {
  sync_enabled: boolean;
  sync_mode: 'supabase' | 'github';
  github_repo?: string;
  last_synced_at?: string;
}

// PUT /api/sync/config
interface UpdateSyncConfigRequest {
  sync_mode: 'supabase' | 'github';
  github_token?: string; // 仅用于验证，不存储
}

// POST /api/sync/github/setup
interface GitHubSetupRequest {
  access_token: string;
}

interface GitHubSetupResponse {
  repo_url: string;
  repo_name: string;
  initialized: boolean;
}
```

#### 数据同步 API

```typescript
// POST /api/sync/servers
interface SyncServersRequest {
  servers: MediaServer[];
  device_id: string;
  timestamp: string;
}

// GET /api/sync/servers
interface SyncServersResponse {
  servers: MediaServer[];
  last_synced_at: string;
}

// POST /api/sync/history
interface SyncHistoryRequest {
  history: PlayHistory[];
  device_id: string;
}

// GET /api/sync/history?limit=50&offset=0
interface SyncHistoryResponse {
  history: PlayHistory[];
  total: number;
  has_more: boolean;
}
```

### 6.3 Edge Functions 实现

#### 账号升级处理
```typescript
// supabase/functions/upgrade-account/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const { plan, payment_method } = await req.json()
  const authHeader = req.headers.get('Authorization')!
  
  // 验证用户
  const supabase = createClient(...)
  const { data: { user } } = await supabase.auth.getUser(authHeader)
  
  // 创建支付订单
  const order = await createPaymentOrder(user.id, plan, payment_method)
  
  // 返回支付链接
  return new Response(JSON.stringify({
    order_id: order.id,
    payment_url: order.payment_url,
    amount: order.amount,
  }))
})
```

#### GitHub 同步初始化
```typescript
// supabase/functions/github-sync-setup/index.ts
serve(async (req) => {
  const { access_token } = await req.json()
  
  // 验证 GitHub token
  const octokit = new Octokit({ auth: access_token })
  const { data: user } = await octokit.users.getAuthenticated()
  
  // 创建私有仓库
  const repo = await octokit.repos.createForAuthenticatedUser({
    name: 'bovaplayer-sync',
    private: true,
    description: 'BovaPlayer Cloud Sync Data',
  })
  
  // 初始化仓库结构
  await initializeRepoStructure(octokit, repo.full_name)
  
  // 保存配置到数据库
  await supabase
    .from('user_settings')
    .update({
      sync_mode: 'github',
      github_repo: repo.full_name,
    })
    .eq('user_id', user.id)
  
  return new Response(JSON.stringify({
    repo_url: repo.html_url,
    repo_name: repo.full_name,
  }))
})
```


---

## 7. 支付集成方案

### 7.1 支付渠道

| 支付方式 | 适用地区 | 手续费 | 集成难度 |
|---------|---------|--------|---------|
| **支付宝** | 中国大陆 | 0.6% | 中等 |
| **微信支付** | 中国大陆 | 0.6% | 中等 |
| **Stripe** | 国际 | 2.9% + $0.30 | 简单 |
| **Paddle** | 国际 | 5% + $0.50 | 简单 |

### 7.2 定价策略

```yaml
社区免费版:
  价格: ¥0
  限制:
    - 服务器: 3 个
    - 设备: 2 台
    - 存储: 100MB
    - 历史: 30 天
    - 收藏: 50 个

Pro 月付版:
  价格: ¥9/月
  优惠: 首月 ¥1
  限制:
    - 服务器: 无限
    - 设备: 5 台
    - 存储: 1GB
    - 历史: 无限
    - 收藏: 无限
    - GitHub 同步: ✅

Pro 年付版:
  价格: ¥68/年
  优惠: 相当于 ¥5.67/月，节省 37%
  限制: 同月付版

永久版:
  价格: ¥298 一次性
  优惠: 早鸟价 ¥198（前 1000 名）
  限制:
    - 服务器: 无限
    - 设备: 10 台
    - 存储: 5GB
    - 历史: 无限
    - 收藏: 无限
    - GitHub 同步: ✅
    - 终身更新: ✅
```

### 7.3 支付流程

```dart
class PaymentService {
  // 创建订单
  Future<PaymentOrder> createOrder(String plan) async {
    final response = await _api.post('/api/payment/create', {
      'plan': plan,
      'payment_method': 'alipay', // or 'wechat', 'stripe'
    });
    
    return PaymentOrder.fromJson(response.data);
  }
  
  // 支付宝支付
  Future<void> payWithAlipay(PaymentOrder order) async {
    // 调用支付宝 SDK
    final result = await Alipay.pay(order.alipay_url);
    
    if (result.success) {
      // 轮询订单状态
      await _pollOrderStatus(order.id);
    }
  }
  
  // 验证支付结果
  Future<void> _pollOrderStatus(String orderId) async {
    for (int i = 0; i < 30; i++) {
      await Future.delayed(Duration(seconds: 2));
      
      final status = await _api.get('/api/payment/status/$orderId');
      
      if (status.data['paid']) {
        // 支付成功，刷新账号信息
        await _refreshAccountInfo();
        return;
      }
    }
  }
}
```

---

## 8. 客户端实现

### 8.1 Flutter 项目结构

```
lib/
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── auth_repository.dart
│   │   │   └── auth_api.dart
│   │   ├── domain/
│   │   │   ├── user.dart
│   │   │   └── auth_service.dart
│   │   └── presentation/
│   │       ├── login_page.dart
│   │       ├── register_page.dart
│   │       └── account_page.dart
│   ├── sync/
│   │   ├── data/
│   │   │   ├── sync_repository.dart
│   │   │   ├── supabase_sync_service.dart
│   │   │   └── github_sync_service.dart
│   │   ├── domain/
│   │   │   ├── sync_config.dart
│   │   │   └── sync_service.dart
│   │   └── presentation/
│   │       ├── sync_settings_page.dart
│   │       └── github_setup_page.dart
│   └── payment/
│       ├── data/
│       │   └── payment_repository.dart
│       ├── domain/
│       │   └── payment_service.dart
│       └── presentation/
│           ├── upgrade_page.dart
│           └── payment_page.dart
└── core/
    ├── storage/
    │   ├── secure_storage.dart
    │   └── local_database.dart
    └── network/
        ├── api_client.dart
        └── supabase_client.dart
```

### 8.2 核心服务实现

#### 认证服务
```dart
class AuthService {
  final SupabaseClient _supabase;
  final SecureStorage _storage;
  
  // 注册
  Future<User> register(String email, String password) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );
    
    if (response.user == null) {
      throw AuthException('注册失败');
    }
    
    // 创建用户配置
    await _createUserSettings(response.user!.id);
    
    return User.fromSupabase(response.user!);
  }
  
  // 登录
  Future<User> login(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    
    // 保存 session
    await _storage.saveSession(response.session!);
    
    // 同步数据
    await _syncService.syncFromCloud();
    
    return User.fromSupabase(response.user!);
  }
  
  // GitHub OAuth 登录
  Future<User> loginWithGitHub() async {
    final response = await _supabase.auth.signInWithOAuth(
      Provider.github,
      redirectTo: 'bovaplayer://auth/callback',
    );
    
    return User.fromSupabase(response.user!);
  }
}
```

#### Supabase 同步服务
```dart
class SupabaseSyncService implements SyncService {
  final SupabaseClient _supabase;
  
  // 同步服务器列表
  Future<void> syncServers(List<MediaServer> servers) async {
    for (final server in servers) {
      // 加密 token
      final encryptedToken = await _encrypt(server.accessToken);
      
      await _supabase.from('media_servers').upsert({
        'id': server.id,
        'user_id': _currentUserId,
        'server_type': server.type.name,
        'name': server.name,
        'url': server.url,
        'access_token_encrypted': encryptedToken,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }
  
  // 实时监听变化
  void subscribeToChanges() {
    _supabase
      .from('media_servers')
      .stream(primaryKey: ['id'])
      .eq('user_id', _currentUserId)
      .listen((data) {
        // 更新本地数据库
        _updateLocalServers(data);
      });
  }
  
  // 同步播放历史
  Future<void> syncPlayHistory(PlayHistory history) async {
    await _supabase.from('play_history').upsert({
      'user_id': _currentUserId,
      'server_id': history.serverId,
      'item_id': history.itemId,
      'position_seconds': history.positionSeconds,
      'last_played_at': DateTime.now().toIso8601String(),
    });
  }
}
```

#### GitHub 同步服务
```dart
class GitHubSyncService implements SyncService {
  final GitHub _github;
  final String _repoName = 'bovaplayer-sync';
  
  // 初始化
  Future<void> initialize(String accessToken) async {
    _github = GitHub(auth: Authentication.withToken(accessToken));
    
    // 检查仓库
    final repoExists = await _checkRepository();
    if (!repoExists) {
      await _createAndInitializeRepo();
    }
  }
  
  // 同步到 GitHub
  Future<void> syncToGitHub() async {
    // 1. 准备数据
    final data = await _prepareAllData();
    
    // 2. 更新文件
    for (final entry in data.entries) {
      await _updateFile(entry.key, entry.value);
    }
    
    // 3. Commit
    await _commitChanges('Sync from ${_deviceName}');
  }
  
  // 从 GitHub 同步
  Future<void> syncFromGitHub() async {
    // 1. 获取最新数据
    final servers = await _getFile('servers/emby_servers.json');
    final history = await _getFile('history/${_currentMonth()}/play_history.json');
    
    // 2. 更新本地
    await _updateLocalDatabase(servers, history);
  }
  
  // 更新文件
  Future<void> _updateFile(String path, String content) async {
    final slug = RepositorySlug.full('$_username/$_repoName');
    
    try {
      // 获取现有文件的 SHA
      final file = await _github.repositories.getContents(slug, path);
      
      // 更新文件
      await _github.repositories.updateFile(
        slug,
        path,
        'Update $path',
        content,
        file.file!.sha!,
      );
    } catch (e) {
      // 文件不存在，创建新文件
      await _github.repositories.createFile(
        slug,
        CreateFile(
          path: path,
          message: 'Create $path',
          content: base64.encode(utf8.encode(content)),
        ),
      );
    }
  }
}
```

### 8.3 UI 实现

#### 账号页面
```dart
class AccountPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('我的账号')),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (!auth.isLoggedIn) {
            return _buildLoginPrompt();
          }
          
          return ListView(
            children: [
              _buildUserInfo(auth.user),
              _buildAccountType(auth.accountInfo),
              _buildUsageStats(auth.accountInfo),
              _buildSyncSettings(),
              _buildUpgradeButton(),
              _buildLogoutButton(),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildAccountType(AccountInfo info) {
    return Card(
      child: ListTile(
        leading: Icon(_getAccountIcon(info.accountType)),
        title: Text(_getAccountTypeName(info.accountType)),
        subtitle: info.accountType == AccountType.pro
          ? Text('到期时间: ${_formatDate(info.proExpiresAt)}')
          : null,
        trailing: info.accountType == AccountType.free
          ? TextButton(
              onPressed: () => _showUpgradePage(),
              child: Text('升级'),
            )
          : null,
      ),
    );
  }
  
  Widget _buildUsageStats(AccountInfo info) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('使用情况', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 16),
            _buildUsageItem(
              '服务器',
              info.usage.serverCount,
              info.limits.maxServers,
            ),
            _buildUsageItem(
              '设备',
              info.usage.deviceCount,
              info.limits.maxDevices,
            ),
            _buildUsageItem(
              '存储空间',
              info.usage.storageUsedMb,
              info.limits.storageQuotaMb,
              unit: 'MB',
            ),
          ],
        ),
      ),
    );
  }
}
```

#### 升级页面
```dart
class UpgradePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('升级到 Pro')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildPlanCard(
            title: 'Pro 月付版',
            price: '¥9',
            period: '/月',
            features: [
              '无限服务器',
              '5 台设备',
              '1GB 存储',
              'GitHub 同步',
            ],
            onTap: () => _upgrade('pro_monthly'),
          ),
          _buildPlanCard(
            title: 'Pro 年付版',
            price: '¥68',
            period: '/年',
            badge: '节省 37%',
            features: [
              '无限服务器',
              '5 台设备',
              '1GB 存储',
              'GitHub 同步',
            ],
            onTap: () => _upgrade('pro_yearly'),
          ),
          _buildPlanCard(
            title: '永久版',
            price: '¥298',
            period: '一次性',
            badge: '最超值',
            features: [
              '无限服务器',
              '10 台设备',
              '5GB 存储',
              'GitHub 同步',
              '终身更新',
              '优先支持',
            ],
            onTap: () => _upgrade('lifetime'),
            highlighted: true,
          ),
        ],
      ),
    );
  }
  
  Future<void> _upgrade(String plan) async {
    // 创建订单
    final order = await _paymentService.createOrder(plan);
    
    // 选择支付方式
    final paymentMethod = await _showPaymentMethodDialog();
    
    // 发起支付
    if (paymentMethod == 'alipay') {
      await _paymentService.payWithAlipay(order);
    } else if (paymentMethod == 'wechat') {
      await _paymentService.payWithWechat(order);
    }
  }
}
```

#### GitHub 同步设置页面
```dart
class GitHubSyncSetupPage extends StatefulWidget {
  @override
  _GitHubSyncSetupPageState createState() => _GitHubSyncSetupPageState();
}

class _GitHubSyncSetupPageState extends State<GitHubSyncSetupPage> {
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('GitHub 同步设置')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GitHub 同步',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 8),
            Text(
              '使用 GitHub 私有仓库存储您的同步数据，完全掌控您的数据。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 24),
            _buildFeatureList(),
            Spacer(),
            _buildSetupButton(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFeatureList() {
    return Column(
      children: [
        _buildFeatureItem('🔒 数据完全自主', '存储在您的 GitHub 私有仓库'),
        _buildFeatureItem('📦 无限存储空间', 'GitHub 免费提供无限私有仓库'),
        _buildFeatureItem('🕐 版本历史', '完整的 Git 提交历史'),
        _buildFeatureItem('🔄 自动同步', '多设备实时同步'),
      ],
    );
  }
  
  Widget _buildSetupButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _setupGitHubSync,
      child: _isLoading
        ? CircularProgressIndicator()
        : Text('连接 GitHub'),
    );
  }
  
  Future<void> _setupGitHubSync() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. GitHub OAuth 认证
      final token = await _authService.authenticateGitHub();
      
      // 2. 初始化仓库
      final repo = await _syncService.setupGitHubSync(token);
      
      // 3. 首次同步
      await _syncService.syncToGitHub();
      
      // 4. 显示成功
      _showSuccessDialog(repo);
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
```


---

## 9. 部署方案

### 9.1 Supabase 部署

#### 使用 Supabase Cloud（推荐）
```bash
# 1. 创建项目
# 访问 https://supabase.com/dashboard
# 创建新项目

# 2. 配置数据库
# 在 SQL Editor 中执行数据库脚本
# 创建表和 RLS 策略

# 3. 配置认证
# 启用邮箱认证
# 配置 OAuth 提供商（GitHub）

# 4. 部署 Edge Functions
cd supabase/functions
supabase functions deploy upgrade-account
supabase functions deploy github-sync-setup
```

#### 自建 Supabase（可选）
```yaml
# docker-compose.yml
version: '3.8'
services:
  postgres:
    image: supabase/postgres:15.1.0.117
    environment:
      POSTGRES_PASSWORD: your-super-secret-password
    volumes:
      - postgres-data:/var/lib/postgresql/data
  
  auth:
    image: supabase/gotrue:v2.99.0
    environment:
      GOTRUE_DB_DRIVER: postgres
      GOTRUE_SITE_URL: https://your-domain.com
      GOTRUE_JWT_SECRET: your-jwt-secret
  
  rest:
    image: postgrest/postgrest:v11.2.0
    environment:
      PGRST_DB_URI: postgres://postgres:password@postgres:5432/postgres
      PGRST_JWT_SECRET: your-jwt-secret
  
  realtime:
    image: supabase/realtime:v2.25.35
    environment:
      DB_HOST: postgres
      DB_PORT: 5432
```

### 9.2 支付服务部署

#### 支付宝/微信支付
```typescript
// 使用第三方聚合支付（推荐）
// 例如: Ping++, BeeCloud, 易宝支付

import Pingpp from 'pingpp';

const pingpp = Pingpp('your_api_key');

// 创建支付订单
async function createPayment(amount: number, channel: string) {
  const charge = await pingpp.charges.create({
    amount: amount * 100, // 分
    currency: 'cny',
    subject: 'BovaPlayer Pro 订阅',
    body: 'BovaPlayer Pro 年付版',
    channel: channel, // 'alipay', 'wx'
    client_ip: req.ip,
  });
  
  return charge;
}
```

#### Stripe 支付（国际）
```typescript
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

// 创建订阅
async function createSubscription(customerId: string, priceId: string) {
  const subscription = await stripe.subscriptions.create({
    customer: customerId,
    items: [{ price: priceId }],
    payment_behavior: 'default_incomplete',
    expand: ['latest_invoice.payment_intent'],
  });
  
  return subscription;
}
```

### 9.3 监控和日志

```yaml
监控工具:
  - Sentry: 错误追踪
  - PostHog: 用户行为分析
  - Grafana: 性能监控
  - Supabase Dashboard: 数据库监控

日志收集:
  - Supabase Logs: 数据库日志
  - Edge Functions Logs: 函数日志
  - Flutter Crashlytics: 客户端崩溃
```

---

## 10. 开发计划

### 10.1 阶段 1: 基础认证（2 周）

**Week 1: 后端搭建**
- [ ] Day 1-2: Supabase 项目创建和配置
- [ ] Day 3-4: 数据库表设计和创建
- [ ] Day 5: RLS 策略配置
- [ ] Day 6-7: 认证 API 测试

**Week 2: 客户端集成**
- [ ] Day 1-2: Flutter Supabase SDK 集成
- [ ] Day 3-4: 登录/注册 UI
- [ ] Day 4-5: 本地存储和状态管理
- [ ] Day 6-7: 测试和 Bug 修复

**交付物**:
- ✅ 用户注册/登录功能
- ✅ 邮箱验证
- ✅ 本地 session 管理
- ✅ 基础账号页面

### 10.2 阶段 2: Supabase 同步（1.5 周）

**Week 3-4**
- [ ] Day 1-2: 服务器列表同步
- [ ] Day 3: 播放历史同步
- [ ] Day 4: 收藏列表同步
- [ ] Day 5: 设置同步
- [ ] Day 6: 实时订阅
- [ ] Day 7: 冲突解决
- [ ] Day 8-10: 测试和优化

**交付物**:
- ✅ 完整的 Supabase 同步功能
- ✅ 实时多设备同步
- ✅ 离线队列机制
- ✅ 同步状态 UI

### 10.3 阶段 3: GitHub 同步（1.5 周）

**Week 5-6**
- [ ] Day 1-2: GitHub OAuth 集成
- [ ] Day 3-4: 仓库创建和初始化
- [ ] Day 5-6: 数据同步逻辑
- [ ] Day 7-8: 冲突解决
- [ ] Day 9-10: UI 和测试

**交付物**:
- ✅ GitHub OAuth 认证
- ✅ 自动创建私有仓库
- ✅ 数据同步到 GitHub
- ✅ GitHub 同步设置页面

### 10.4 阶段 4: 账号体系和支付（2 周）

**Week 7: 账号体系**
- [ ] Day 1-2: 账号类型和限额实现
- [ ] Day 3-4: 使用量统计
- [ ] Day 5: 升级页面 UI
- [ ] Day 6-7: 权限控制

**Week 8: 支付集成**
- [ ] Day 1-3: 支付宝/微信支付集成
- [ ] Day 4-5: 订单管理
- [ ] Day 6: 支付回调处理
- [ ] Day 7: 测试和验证

**交付物**:
- ✅ 三级账号体系
- ✅ 使用量限制
- ✅ 支付功能
- ✅ 订阅管理

### 10.5 阶段 5: 测试和优化（1 周）

**Week 9**
- [ ] Day 1-2: 功能测试
- [ ] Day 3-4: 性能优化
- [ ] Day 5: 安全审计
- [ ] Day 6: 文档编写
- [ ] Day 7: 发布准备

**交付物**:
- ✅ 完整测试报告
- ✅ 性能优化
- ✅ 用户文档
- ✅ v0.3 发布

---

## 11. 成本估算

### 11.1 开发成本

| 阶段 | 时间 | 人力 | 成本估算 |
|------|------|------|---------|
| 基础认证 | 2 周 | 1 人 | - |
| Supabase 同步 | 1.5 周 | 1 人 | - |
| GitHub 同步 | 1.5 周 | 1 人 | - |
| 账号体系 | 2 周 | 1 人 | - |
| 测试优化 | 1 周 | 1 人 | - |
| **总计** | **8 周** | **1 人** | - |

### 11.2 运营成本

#### Supabase Cloud（免费版）
```yaml
免费额度:
  数据库: 500MB
  存储: 1GB
  带宽: 2GB/月
  认证用户: 50,000
  Edge Functions: 500,000 次调用/月

预估支持用户数: 1,000 - 5,000 活跃用户
成本: ¥0/月
```

#### Supabase Cloud（Pro 版）
```yaml
价格: $25/月 (约 ¥180/月)

额度:
  数据库: 8GB
  存储: 100GB
  带宽: 50GB/月
  认证用户: 100,000
  Edge Functions: 2,000,000 次调用/月

预估支持用户数: 10,000 - 50,000 活跃用户
```

#### 支付手续费
```yaml
支付宝/微信:
  手续费: 0.6%
  月收入 ¥10,000: 手续费 ¥60

Stripe:
  手续费: 2.9% + $0.30
  适用于国际用户
```

#### 总成本估算（月）
```yaml
用户规模: 1,000 活跃用户
  - Supabase: ¥0 (免费版)
  - 支付手续费: ¥60 (假设 100 笔订阅)
  - 总计: ¥60/月

用户规模: 10,000 活跃用户
  - Supabase: ¥180 (Pro 版)
  - 支付手续费: ¥600 (假设 1,000 笔订阅)
  - 总计: ¥780/月

用户规模: 50,000 活跃用户
  - Supabase: ¥1,800 (Team 版)
  - CDN: ¥500
  - 支付手续费: ¥3,000
  - 总计: ¥5,300/月
```

### 11.3 收入预测

```yaml
保守估算（1,000 活跃用户）:
  - 免费用户: 900 人
  - Pro 月付: 50 人 × ¥9 = ¥450/月
  - Pro 年付: 30 人 × ¥68 = ¥2,040/年 (¥170/月)
  - 永久版: 20 人 × ¥298 = ¥5,960 (一次性)
  
  月收入: ¥620
  年收入: ¥7,440 + ¥5,960 = ¥13,400

中等估算（10,000 活跃用户）:
  - 免费用户: 8,500 人
  - Pro 月付: 500 人 × ¥9 = ¥4,500/月
  - Pro 年付: 800 人 × ¥68 = ¥54,400/年 (¥4,533/月)
  - 永久版: 200 人 × ¥298 = ¥59,600 (一次性)
  
  月收入: ¥9,033
  年收入: ¥108,396 + ¥59,600 = ¥167,996

乐观估算（50,000 活跃用户）:
  - 免费用户: 42,500 人
  - Pro 月付: 2,500 人 × ¥9 = ¥22,500/月
  - Pro 年付: 4,000 人 × ¥68 = ¥272,000/年 (¥22,667/月)
  - 永久版: 1,000 人 × ¥298 = ¥298,000 (一次性)
  
  月收入: ¥45,167
  年收入: ¥542,004 + ¥298,000 = ¥840,004
```

---

## 12. 风险管理

### 12.1 技术风险

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|---------|
| Supabase 服务中断 | 高 | 低 | 本地缓存 + 离线模式 |
| GitHub API 限流 | 中 | 中 | 请求限制 + 缓存 |
| 数据同步冲突 | 中 | 中 | 冲突解决策略 |
| 支付回调失败 | 高 | 低 | 重试机制 + 手动核对 |
| 数据泄露 | 高 | 低 | 加密 + RLS + 审计 |

### 12.2 业务风险

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|---------|
| 用户增长缓慢 | 高 | 中 | 营销推广 + 功能优化 |
| 付费转化率低 | 高 | 中 | 优化定价 + 增值功能 |
| 运营成本超预算 | 中 | 低 | 成本监控 + 优化 |
| 竞品压力 | 中 | 中 | 差异化功能 |

### 12.3 合规风险

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|---------|
| 数据隐私合规 | 高 | 低 | GDPR/PIPL 合规 |
| 支付合规 | 高 | 低 | 使用合规支付渠道 |
| 内容版权 | 中 | 低 | 用户协议 + 免责声明 |

---

## 13. 成功指标

### 13.1 技术指标

```yaml
性能:
  - 同步延迟: < 2 秒
  - API 响应时间: < 500ms
  - 数据库查询: < 100ms
  - 同步成功率: > 99%

可靠性:
  - 服务可用性: > 99.9%
  - 数据一致性: 100%
  - 错误率: < 0.1%
```

### 13.2 业务指标

```yaml
用户增长:
  - 月活用户 (MAU): 目标 10,000
  - 日活用户 (DAU): 目标 3,000
  - 用户留存率 (30天): > 40%

付费转化:
  - 免费转付费率: > 5%
  - Pro 续费率: > 70%
  - 永久版占比: > 20%

收入:
  - 月收入: 目标 ¥10,000
  - 年收入: 目标 ¥150,000
  - ARPU: > ¥15/月
```

---

## 14. 总结

### 14.1 核心优势

1. **灵活的同步方案**
   - Supabase: 实时、易用
   - GitHub: 隐私、免费

2. **合理的定价策略**
   - 免费版: 吸引用户
   - Pro 版: 满足重度用户
   - 永久版: 忠实用户奖励

3. **安全的数据保护**
   - 本地加密存储
   - 云端加密传输
   - 敏感数据不上传

4. **完善的技术架构**
   - 开源可自建
   - 成本可控
   - 易于扩展

### 14.2 下一步行动

1. **立即开始**
   - 创建 Supabase 项目
   - 设计数据库表
   - 搭建基础认证

2. **并行开发**
   - 后端 API 开发
   - 客户端 UI 实现
   - 支付集成

3. **持续迭代**
   - 用户反馈收集
   - 功能优化
   - 性能提升

---

**文档版本**: v1.0  
**创建日期**: 2026-03-02  
**维护者**: BovaPlayer Team  
**状态**: 待评审

