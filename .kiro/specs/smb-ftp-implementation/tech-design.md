# SMB/FTP 实现技术方案

## 目标
在 Windows、macOS、Android 三个平台上实现 SMB 和 FTP 协议支持，允许用户浏览和播放 NAS 上的媒体文件。

## 技术选型

### SMB 协议
**方案**: 使用 `smb2` Dart 包（纯 Dart 实现）
- **优点**: 
  - 纯 Dart 实现，跨平台兼容性好
  - 支持 SMB2/SMB3 协议
  - 无需原生代码
- **缺点**: 
  - 性能可能不如原生实现
  - 需要测试大文件性能

**备选方案**: 平台特定实现
- Windows: 使用 `\\server\share` UNC 路径
- macOS: 使用 `smb://` URL scheme
- Android: 使用 jcifs-ng 库

### FTP 协议
**方案**: 使用 `ftpconnect` 包
- **优点**:
  - 成熟稳定
  - 支持 FTP/FTPS
  - 简单易用
- **功能**:
  - 连接管理
  - 目录浏览
  - 文件下载

### 播放集成
**方案**: 本地代理服务器
- 使用 `shelf` 创建本地 HTTP 服务器
- 从 SMB/FTP 读取数据，通过 HTTP 提供给播放器
- 支持 HTTP Range 请求（快速 seek）

## 架构设计

```
┌─────────────────────────────────────────────────┐
│                   UI Layer                       │
│  ┌──────────────┐  ┌──────────────┐            │
│  │ SMB Browser  │  │ FTP Browser  │            │
│  └──────────────┘  └──────────────┘            │
└─────────────────────────────────────────────────┘
                      │
┌─────────────────────────────────────────────────┐
│              Service Layer                       │
│  ┌──────────────┐  ┌──────────────┐            │
│  │ SMB Service  │  │ FTP Service  │            │
│  └──────────────┘  └──────────────┘            │
│  ┌──────────────────────────────────┐          │
│  │   Connection Manager             │          │
│  │   (保存/加载连接信息)              │          │
│  └──────────────────────────────────┘          │
└─────────────────────────────────────────────────┘
                      │
┌─────────────────────────────────────────────────┐
│           Proxy Server Layer                     │
│  ┌──────────────────────────────────┐          │
│  │   Local HTTP Proxy Server        │          │
│  │   (shelf + HTTP Range support)   │          │
│  └──────────────────────────────────┘          │
└─────────────────────────────────────────────────┘
                      │
┌─────────────────────────────────────────────────┐
│              Player Layer                        │
│  ┌──────────────────────────────────┐          │
│  │   MDK/MPV Player                 │          │
│  │   (播放 http://localhost:xxxx)   │          │
│  └──────────────────────────────────┘          │
└─────────────────────────────────────────────────┘
```

## 数据模型

### NetworkConnection
```dart
class NetworkConnection {
  final String id;
  final NetworkProtocol protocol; // SMB, FTP
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final String? shareName; // SMB only
  final String? workgroup; // SMB only
  final DateTime lastConnected;
  final bool savePassword;
}
```

### NetworkFile
```dart
class NetworkFile {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? modified;
  final String? mimeType;
}
```

## 实现计划

### M1: 技术验证（1周）
- [x] 评估 smb2 和 ftpconnect 包
- [ ] 创建 POC：SMB 连接和文件列表
- [ ] 创建 POC：FTP 连接和文件列表
- [ ] 创建 POC：本地代理服务器
- [ ] 测试播放集成

### M2: MVP 实现（2-3周）
- [ ] 实现 NetworkConnection 数据模型
- [ ] 实现 ConnectionManager（保存/加载）
- [ ] 实现 SMBService
- [ ] 实现 FTPService
- [ ] 实现 LocalProxyServer
- [ ] 实现连接管理 UI
- [ ] 实现文件浏览 UI
- [ ] 集成播放器

### M3: 功能完善（1-2周）
- [ ] 连接历史记录
- [ ] 文件搜索和过滤
- [ ] 性能优化（缓存、预加载）
- [ ] 断线重连机制
- [ ] 错误处理和提示

### M4: 测试和发布（1周）
- [ ] Windows 测试
- [ ] macOS 测试
- [ ] Android 测试
- [ ] NAS 兼容性测试（群晖、威联通）
- [ ] 文档编写

## 依赖包

```yaml
dependencies:
  # SMB 支持
  smb2: ^0.1.0  # 纯 Dart SMB2/SMB3 实现
  
  # FTP 支持
  ftpconnect: ^2.0.0
  
  # 本地代理服务器
  shelf: ^1.4.0
  shelf_router: ^1.1.0
  
  # 数据持久化
  shared_preferences: ^2.2.2
  flutter_secure_storage: ^9.0.0  # 安全存储密码
  
  # 文件类型识别
  mime: ^1.0.4
```

## 安全考虑

1. **密码存储**: 使用 `flutter_secure_storage` 加密存储
2. **连接加密**: 支持 FTPS（FTP over TLS）
3. **权限控制**: 
   - Android: 需要网络权限
   - macOS: 需要网络权限（沙箱配置）
4. **输入验证**: 验证主机名、端口、路径

## 性能优化

1. **连接池**: 复用 SMB/FTP 连接
2. **缓存**: 缓存目录列表
3. **预加载**: 预加载下一个文件
4. **分块传输**: 支持 HTTP Range 请求
5. **并发控制**: 限制同时连接数

## 用户体验

1. **连接测试**: 保存前测试连接
2. **进度显示**: 显示连接和加载进度
3. **错误提示**: 友好的错误信息
4. **快速访问**: 最近使用的连接
5. **离线模式**: 缓存连接信息

## 下一步

1. 添加依赖包到 pubspec.yaml
2. 创建基础数据模型
3. 实现 SMB POC
4. 实现 FTP POC
5. 实现本地代理服务器
