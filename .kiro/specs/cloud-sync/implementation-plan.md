# 云同步功能实施计划

## 快速概览

| 项目 | 内容 |
|------|------|
| **总工期** | 8 周 |
| **开发人员** | 1-2 人 |
| **技术栈** | Flutter + Supabase + GitHub API |
| **预算** | 开发期间 ¥0（使用免费服务） |
| **目标版本** | v0.3 |

---

## 第一周：环境搭建和基础认证

### Day 1-2: Supabase 项目创建

**任务清单**:
- [ ] 注册 Supabase 账号
- [ ] 创建新项目 `bovaplayer-cloud`
- [ ] 配置项目设置（区域选择：新加坡或东京）
- [ ] 获取 API Keys（anon key, service role key）
- [ ] 配置 Flutter 环境变量

**代码示例**:
```dart
// lib/core/config/supabase_config.dart
class SupabaseConfig {
  static const String url = 'YOUR_SUPABASE_URL';
  static const String anonKey = 'YOUR_ANON_KEY';
  
  static SupabaseClient get client => SupabaseClient(url, anonKey);
}
```

**验收标准**:
- ✅ Supabase 项目创建成功
- ✅ Flutter 可以连接到 Supabase
- ✅ 环境变量配置完成

### Day 3-4: 数据库设计和创建

**任务清单**:
- [ ] 在 Supabase SQL Editor 中执行数据库脚本
- [ ] 创建所有表（users, devices, media_servers, play_history, favorites, user_settings, subscriptions）
- [ ] 配置 RLS 策略
- [ ] 创建索引
- [ ] 测试数据库连接

**SQL 脚本位置**:
```
.kiro/specs/cloud-sync/database/
├── 01_create_tables.sql
├── 02_create_indexes.sql
├── 03_create_rls_policies.sql
└── 04_seed_data.sql
```

**验收标准**:
- ✅ 所有表创建成功
- ✅ RLS 策略生效
- ✅ 可以通过 Supabase Dashboard 查询数据

### Day 5-7: 认证功能实现

**任务清单**:
- [ ] 集成 `supabase_flutter` 包
- [ ] 实现注册功能
- [ ] 实现登录功能
- [ ] 实现邮箱验证
- [ ] 实现密码重置
- [ ] 实现本地 session 管理
- [ ] 创建登录/注册 UI

**文件结构**:
```
lib/features/auth/
├── data/
│   ├── auth_repository.dart
│   └── models/
│       └── user_model.dart
├── domain/
│   ├── auth_service.dart
│   └── entities/
│       └── user.dart
└── presentation/
    ├── pages/
    │   ├── login_page.dart
    │   ├── register_page.dart
    │   └── forgot_password_page.dart
    └── widgets/
        ├── auth_form.dart
        └── social_login_buttons.dart
```

**验收标准**:
- ✅ 用户可以注册账号
- ✅ 用户可以登录
- ✅ 邮箱验证流程正常
- ✅ Session 持久化
- ✅ UI 美观易用

---

## 第二周：Supabase 数据同步

### Day 8-9: 服务器列表同步

**任务清单**:
- [ ] 实现 `SyncRepository`
- [ ] 实现服务器上传功能
- [ ] 实现服务器下载功能
- [ ] 实现增量同步
- [ ] 添加同步状态指示器
- [ ] 处理同步冲突

**核心代码**:
```dart
// lib/features/sync/data/sync_repository.dart
class SyncRepository {
  Future<void> syncServers() async {
    // 1. 获取本地服务器列表
    final localServers = await _localDb.getServers();
    
    // 2. 获取云端服务器列表
    final cloudServers = await _supabase
      .from('media_servers')
      .select()
      .eq('user_id', _userId);
    
    // 3. 合并数据（使用 updated_at 判断）
    final merged = _mergeServers(localServers, cloudServers);
    
    // 4. 更新本地和云端
    await _updateLocal(merged);
    await _updateCloud(merged);
  }
}
```

**验收标准**:
- ✅ 添加服务器后自动同步到云端
- ✅ 登录后自动下载服务器列表
- ✅ 多设备数据一致
- ✅ 冲突正确解决

### Day 10-11: 播放历史同步

**任务清单**:
- [ ] 实现播放历史上传
- [ ] 实现播放历史下载
- [ ] 实现断点续播
- [ ] 添加"继续观看"列表
- [ ] 优化同步性能（批量上传）

**验收标准**:
- ✅ 播放位置实时同步
- ✅ 跨设备断点续播
- ✅ 历史记录完整

### Day 12-13: 收藏和设置同步

**任务清单**:
- [ ] 实现收藏列表同步
- [ ] 实现用户设置同步
- [ ] 添加同步设置页面
- [ ] 实现选择性同步

**验收标准**:
- ✅ 收藏列表同步
- ✅ 设置同步
- ✅ 用户可以控制同步项目

### Day 14: 实时订阅和测试

**任务清单**:
- [ ] 实现 Realtime 订阅
- [ ] 测试多设备实时同步
- [ ] 性能优化
- [ ] Bug 修复

**验收标准**:
- ✅ 实时同步延迟 < 2 秒
- ✅ 无明显 Bug

---

## 第三周：GitHub 同步（前半周）

### Day 15-16: GitHub OAuth 集成

**任务清单**:
- [ ] 注册 GitHub OAuth App
- [ ] 实现 OAuth 认证流程
- [ ] 获取和存储 Access Token
- [ ] 测试 GitHub API 连接

**GitHub OAuth 配置**:
```yaml
Application name: BovaPlayer
Homepage URL: https://bovaplayer.com
Authorization callback URL: bovaplayer://auth/github/callback
```

**验收标准**:
- ✅ 用户可以授权 GitHub
- ✅ 成功获取 Access Token
- ✅ Token 安全存储

### Day 17-18: GitHub 仓库管理

**任务清单**:
- [ ] 实现仓库创建
- [ ] 初始化仓库结构
- [ ] 实现文件上传
- [ ] 实现文件下载
- [ ] 处理 Git 冲突

**验收标准**:
- ✅ 自动创建私有仓库
- ✅ 目录结构正确
- ✅ 文件操作正常

---

## 第四周：GitHub 同步（后半周）+ 账号体系

### Day 19-21: GitHub 数据同步

**任务清单**:
- [ ] 实现数据序列化
- [ ] 实现同步逻辑
- [ ] 实现冲突解决
- [ ] 添加 GitHub 同步 UI
- [ ] 测试和优化

**验收标准**:
- ✅ 数据正确同步到 GitHub
- ✅ 可以从 GitHub 恢复数据
- ✅ UI 友好

### Day 22-24: 账号类型和限额

**任务清单**:
- [ ] 实现账号类型枚举
- [ ] 实现限额检查
- [ ] 实现使用量统计
- [ ] 添加升级提示
- [ ] 创建账号信息页面

**核心逻辑**:
```dart
class AccountLimits {
  static Map<AccountType, Limits> limits = {
    AccountType.free: Limits(
      maxServers: 10,
      maxDevices: 2,
      storageQuotaMb: 100,
    ),
    AccountType.pro: Limits(
      maxServers: -1, // 无限
      maxDevices: 5,
      storageQuotaMb: 1024,
    ),
    AccountType.lifetime: Limits(
      maxServers: -1, // 无限
      maxDevices: -1, // 无限
      storageQuotaMb: 5120,
    ),
  };
  
  static bool canAddServer(AccountType type, int currentCount) {
    final limit = limits[type]!.maxServers;
    return limit == -1 || currentCount < limit;
  }
}
```

**验收标准**:
- ✅ 限额正确生效
- ✅ 超限时提示升级
- ✅ 使用量实时更新

---

## 第五周：支付集成

### Day 25-27: 支付宝/微信支付

**任务清单**:
- [ ] 选择支付服务商（Ping++/易宝）
- [ ] 注册商户账号
- [ ] 集成支付 SDK
- [ ] 实现订单创建
- [ ] 实现支付回调
- [ ] 测试支付流程

**支付流程**:
```dart
class PaymentService {
  Future<void> createOrder(String plan) async {
    // 1. 创建订单
    final order = await _api.post('/api/payment/create', {
      'plan': plan,
      'user_id': _userId,
    });
    
    // 2. 调起支付
    final result = await _paymentSDK.pay(order.paymentUrl);
    
    // 3. 验证支付结果
    if (result.success) {
      await _verifyPayment(order.id);
    }
  }
}
```

**验收标准**:
- ✅ 可以创建订单
- ✅ 支付流程正常
- ✅ 回调处理正确
- ✅ 账号自动升级

### Day 28-29: 订阅管理

**任务清单**:
- [ ] 实现订阅状态查询
- [ ] 实现订阅续费
- [ ] 实现订阅取消
- [ ] 添加订阅管理页面
- [ ] 实现到期提醒

**验收标准**:
- ✅ 用户可以查看订阅状态
- ✅ 可以取消订阅
- ✅ 到期前提醒

---

## 第六周：UI 完善和优化

### Day 30-32: UI 设计和实现

**任务清单**:
- [ ] 设计升级页面
- [ ] 设计账号页面
- [ ] 设计同步设置页面
- [ ] 实现所有 UI
- [ ] UI 适配（多平台）

**页面清单**:
- [ ] 登录页面
- [ ] 注册页面
- [ ] 账号信息页面
- [ ] 升级页面
- [ ] 同步设置页面
- [ ] GitHub 设置页面
- [ ] 订阅管理页面

**验收标准**:
- ✅ UI 美观统一
- ✅ 交互流畅
- ✅ 多平台适配

### Day 33-35: 性能优化

**任务清单**:
- [ ] 优化同步性能
- [ ] 减少网络请求
- [ ] 实现智能缓存
- [ ] 优化数据库查询
- [ ] 减少内存占用

**优化目标**:
- 同步延迟 < 2 秒
- API 响应 < 500ms
- 内存占用 < 100MB

**验收标准**:
- ✅ 达到性能目标
- ✅ 无明显卡顿

---

## 第七周：测试和文档

### Day 36-38: 功能测试

**测试清单**:
- [ ] 注册/登录测试
- [ ] 数据同步测试
- [ ] 多设备测试
- [ ] 冲突解决测试
- [ ] 支付流程测试
- [ ] 限额测试
- [ ] 边界条件测试

**测试场景**:
```yaml
场景 1: 新用户注册
  - 注册账号
  - 添加服务器
  - 播放视频
  - 验证数据同步

场景 2: 多设备同步
  - 设备 A 添加服务器
  - 设备 B 登录
  - 验证服务器同步
  - 设备 B 播放视频
  - 设备 A 验证历史同步

场景 3: 升级 Pro
  - 免费用户添加 4 个服务器（应失败）
  - 升级到 Pro
  - 添加第 4 个服务器（应成功）
  - 验证限额更新

场景 4: GitHub 同步
  - 连接 GitHub
  - 同步数据到 GitHub
  - 删除本地数据
  - 从 GitHub 恢复
  - 验证数据完整性
```

**验收标准**:
- ✅ 所有测试通过
- ✅ 无严重 Bug

### Day 39-40: 文档编写

**文档清单**:
- [ ] 用户使用指南
- [ ] 开发者文档
- [ ] API 文档
- [ ] 部署文档
- [ ] FAQ

**验收标准**:
- ✅ 文档完整清晰
- ✅ 示例代码可运行

---

## 第八周：发布准备

### Day 41-42: 安全审计

**审计清单**:
- [ ] 代码安全审查
- [ ] 数据加密验证
- [ ] RLS 策略测试
- [ ] Token 安全检查
- [ ] 支付安全验证

**验收标准**:
- ✅ 无安全漏洞
- ✅ 数据加密正确

### Day 43-44: 性能测试

**测试项目**:
- [ ] 压力测试（1000 并发用户）
- [ ] 同步性能测试
- [ ] 数据库性能测试
- [ ] 内存泄漏检测

**验收标准**:
- ✅ 通过压力测试
- ✅ 无内存泄漏

### Day 45-47: Beta 测试

**任务清单**:
- [ ] 招募 Beta 测试用户（50-100 人）
- [ ] 发布 Beta 版本
- [ ] 收集用户反馈
- [ ] 修复 Bug
- [ ] 优化体验

**验收标准**:
- ✅ Beta 测试顺利
- ✅ 用户反馈积极

### Day 48: 正式发布

**发布清单**:
- [ ] 更新版本号到 v0.3
- [ ] 编写发布说明
- [ ] 构建所有平台版本
- [ ] 上传到应用商店
- [ ] 发布公告

**验收标准**:
- ✅ v0.3 正式发布
- ✅ 云同步功能可用

---

## 技术栈和依赖

### Flutter 依赖
```yaml
dependencies:
  # Supabase
  supabase_flutter: ^2.0.0
  
  # GitHub
  github: ^9.0.0
  
  # 本地存储
  flutter_secure_storage: ^9.0.0
  sqflite: ^2.3.0
  
  # 状态管理
  provider: ^6.1.0
  
  # 网络
  dio: ^5.4.0
  
  # 支付
  tobias: ^3.0.0  # 支付宝
  fluwx: ^4.0.0   # 微信
  
  # UI
  flutter_svg: ^2.0.0
  cached_network_image: ^3.3.0
```

### 后端服务
```yaml
Supabase:
  - PostgreSQL 15
  - Supabase Auth
  - Realtime
  - Edge Functions (Deno)

GitHub:
  - GitHub API v3
  - GitHub OAuth

支付:
  - Ping++ / 易宝支付
  - Stripe (国际)
```

---

## 里程碑和检查点

### Milestone 1: 基础认证（Week 1）
- ✅ Supabase 项目搭建
- ✅ 用户注册/登录
- ✅ Session 管理

### Milestone 2: Supabase 同步（Week 2）
- ✅ 服务器列表同步
- ✅ 播放历史同步
- ✅ 实时订阅

### Milestone 3: GitHub 同步（Week 3-4）
- ✅ GitHub OAuth
- ✅ 仓库管理
- ✅ 数据同步

### Milestone 4: 账号和支付（Week 4-5）
- ✅ 账号体系
- ✅ 支付集成
- ✅ 订阅管理

### Milestone 5: 完善和发布（Week 6-8）
- ✅ UI 完善
- ✅ 测试和优化
- ✅ 正式发布

---

## 风险和应对

| 风险 | 应对措施 |
|------|---------|
| Supabase 免费额度不足 | 监控使用量，必要时升级 |
| GitHub API 限流 | 实现请求缓存和限流 |
| 支付集成困难 | 使用成熟的聚合支付 |
| 开发进度延期 | 优先核心功能，次要功能后续迭代 |
| 用户数据安全 | 严格的加密和 RLS 策略 |

---

## 成功标准

### 功能完整性
- ✅ 用户可以注册/登录
- ✅ 数据可以同步到云端
- ✅ 支持 Supabase 和 GitHub 两种同步方式
- ✅ 账号体系完整
- ✅ 支付流程正常

### 性能指标
- ✅ 同步延迟 < 2 秒
- ✅ API 响应 < 500ms
- ✅ 同步成功率 > 99%

### 用户体验
- ✅ UI 美观易用
- ✅ 流程顺畅
- ✅ 错误提示清晰

---

**文档版本**: v1.0  
**创建日期**: 2026-03-02  
**预计完成**: 2026-04-27  
**状态**: 待开始

