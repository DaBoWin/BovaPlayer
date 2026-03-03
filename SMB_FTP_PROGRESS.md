# SMB/FTP 功能开发进度

## 已完成 ✅

### 1. 技术方案设计
- ✅ 创建技术设计文档 (`.kiro/specs/smb-ftp-implementation/tech-design.md`)
- ✅ 选定技术栈：
  - FTP: `ftpconnect` 包
  - 本地代理: `shelf` + `shelf_router`
  - 安全存储: `flutter_secure_storage`
  - 云同步: `supabase_flutter`

### 2. 数据模型
- ✅ `NetworkConnection` - 网络连接配置
- ✅ `NetworkFile` - 文件/目录信息

### 3. 服务层
- ✅ `FTPService` - FTP 连接和文件操作
  - 连接/断开
  - 目录浏览
  - 文件下载
  - 连接测试
- ✅ `ConnectionManager` - 连接管理
  - 保存/加载连接
  - 安全存储密码
  - 最近使用记录

### 4. UI 层
- ✅ `NetworkBrowserPage` - 网络浏览器主页面
  - 连接列表
  - 文件浏览
  - 添加/删除连接
- ✅ 集成到主导航（第三个标签）

### 5. 依赖安装
- ✅ 所有必要的包已添加到 `pubspec.yaml`
- ✅ `flutter pub get` 成功

## 当前状态

### 可用功能
1. **FTP 连接管理**
   - 添加 FTP 服务器连接
   - 保存连接信息（密码加密存储）
   - 查看连接列表
   - 删除连接

2. **FTP 文件浏览**
   - 连接到 FTP 服务器
   - 浏览目录
   - 查看文件信息（名称、大小）
   - 识别视频/音频文件

3. **跨平台支持**
   - ✅ Windows
   - ✅ macOS
   - ✅ Android

## 待完成 🚧

### M1: 技术验证（剩余工作）
- [ ] SMB 协议支持（需要找合适的 Dart 包或使用平台特定实现）
- [ ] 本地代理服务器实现
- [ ] 播放器集成测试

### M2: MVP 完善
- [ ] 实现本地 HTTP 代理服务器
  - 从 FTP/SMB 读取数据
  - 支持 HTTP Range 请求
  - 提供给播放器使用
- [ ] 播放器集成
  - 通过代理服务器播放网络文件
  - 支持 seek 操作
  - 显示缓冲进度
- [ ] 错误处理优化
  - 连接超时
  - 网络中断
  - 权限错误

### M3: 功能完善
- [ ] 文件搜索和过滤
- [ ] 目录缓存
- [ ] 断线重连
- [ ] 性能优化

### M4: 测试
- [ ] Windows 完整测试
- [ ] macOS 完整测试
- [ ] Android 完整测试
- [ ] NAS 兼容性测试

## SMB 协议方案

### 问题
目前没有找到成熟的纯 Dart SMB 实现。

### 可选方案

#### 方案 1: 平台特定实现（推荐）
- **Windows**: 使用 UNC 路径 (`\\server\share`)
  - 通过 FFI 调用 Windows API
  - 或使用 `Process.run` 执行 `net use` 命令
- **macOS**: 使用 `smb://` URL
  - 通过 `mount_smbfs` 命令挂载
  - 或使用 Finder 的 SMB 支持
- **Android**: 使用 jcifs-ng 库
  - 通过 Platform Channel 调用 Java 代码

#### 方案 2: 使用 smbclient 命令行工具
- 跨平台
- 需要系统安装 smbclient
- 通过 `Process.run` 调用

#### 方案 3: 等待社区包
- 关注 pub.dev 上的 SMB 相关包
- 或考虑贡献一个纯 Dart 实现

## 下一步行动

### 立即可做
1. **测试 FTP 功能**
   ```bash
   flutter run
   ```
   - 添加一个 FTP 连接
   - 浏览文件
   - 验证基本功能

2. **实现本地代理服务器**
   - 创建 `LocalProxyServer` 类
   - 支持 HTTP Range 请求
   - 集成到播放器

3. **播放器集成**
   - 修改播放器接受代理 URL
   - 测试播放功能

### 短期目标（本周）
- [ ] 完成 FTP 播放功能
- [ ] 实现本地代理服务器
- [ ] 基本的 SMB 支持（至少一个平台）

### 中期目标（2周内）
- [ ] 三个平台的 SMB 支持
- [ ] 性能优化
- [ ] 错误处理完善

## 云同步功能

### 已准备
- ✅ `supabase_flutter` 依赖已添加
- ✅ 数据模型支持云同步

### 待实现
- [ ] Supabase 项目设置
- [ ] 用户认证 UI
- [ ] 数据同步逻辑
- [ ] 冲突解决

## 测试指南

### 测试 FTP 功能

1. **启动应用**
   ```bash
   cd ui/flutter_app
   flutter run
   ```

2. **添加 FTP 连接**
   - 点击底部导航的"网络"标签
   - 点击右下角 + 按钮
   - 填写 FTP 服务器信息：
     - 协议: FTP
     - 名称: 测试服务器
     - 主机: your-ftp-server.com
     - 端口: 21
     - 用户名: your-username
     - 密码: your-password
   - 点击"保存"

3. **浏览文件**
   - 点击连接
   - 等待连接成功
   - 浏览目录和文件

4. **测试功能**
   - 进入子目录
   - 查看文件信息
   - 识别视频文件（图标不同）

### 已知限制

1. **播放功能未实现**
   - 点击视频文件只显示提示
   - 需要实现代理服务器

2. **SMB 未实现**
   - 选择 SMB 协议会显示"即将支持"

3. **性能**
   - 大目录可能加载慢
   - 需要添加缓存

## 技术债务

- [ ] 添加单元测试
- [ ] 添加集成测试
- [ ] 错误日志收集
- [ ] 性能监控

## 参考资料

- [ftpconnect 文档](https://pub.dev/packages/ftpconnect)
- [shelf 文档](https://pub.dev/packages/shelf)
- [flutter_secure_storage 文档](https://pub.dev/packages/flutter_secure_storage)
- [supabase_flutter 文档](https://pub.dev/packages/supabase_flutter)
