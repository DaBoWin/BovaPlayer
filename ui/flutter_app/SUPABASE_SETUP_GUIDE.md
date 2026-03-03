# Supabase 配置完成指南

## ✅ 已完成的配置

### 1. 环境变量配置
- ✅ 创建了 `.env` 文件
- ✅ 配置了 Supabase URL: `https://coljzupoztgupdmadmnr.supabase.co`
- ✅ 配置了 Anon Key（已设置）
- ✅ 添加了 `.env` 到 `.gitignore`（保护敏感信息）

### 2. 依赖包配置
- ✅ `supabase_flutter: ^2.5.0` - Supabase 客户端
- ✅ `flutter_secure_storage: ^9.0.0` - 安全存储
- ✅ `provider: ^6.1.2` - 状态管理
- ✅ `flutter_dotenv: ^5.1.0` - 环境变量加载
- ✅ `uuid: ^4.3.3` - UUID 生成

---

## 📋 下一步操作

### Step 1: 安装依赖包

在 `ui/flutter_app` 目录下运行：

```bash
cd ui/flutter_app
flutter pub get
```

### Step 2: 执行数据库脚本

1. **打开 Supabase Dashboard**
   - 访问：https://supabase.com/dashboard
   - 选择你的项目（coljzupoztgupdmadmnr）

2. **进入 SQL Editor**
   - 点击左侧边栏的 **SQL Editor** 图标（</> 图标）
   - 或者点击 **Database** → **SQL Editor**

3. **执行建表脚本**
   - 点击 **New query** 创建新查询
   - 复制 `.kiro/specs/cloud-sync/database/01_create_tables.sql` 的全部内容
   - 粘贴到 SQL Editor
   - 点击右下角的 **Run** 按钮（或按 Ctrl+Enter）

4. **验证表创建**
   - 点击左侧边栏的 **Table Editor**
   - 你应该能看到以下表：
     - users
     - devices
     - media_servers
     - network_connections
     - play_history
     - favorites
     - user_settings
     - subscriptions
     - sync_logs

### Step 3: 配置认证设置

1. **启用邮箱认证**
   - 在 Supabase Dashboard，点击 **Authentication** → **Providers**
   - 确保 **Email** 已启用
   - 配置邮件模板（可选）

2. **配置 GitHub OAuth（可选）**
   - 在 **Authentication** → **Providers** 中找到 **GitHub**
   - 点击启用
   - 需要在 GitHub 创建 OAuth App：
     - 访问：https://github.com/settings/developers
     - 创建 New OAuth App
     - Authorization callback URL: `https://coljzupoztgupdmadmnr.supabase.co/auth/v1/callback`
   - 将 Client ID 和 Client Secret 填入 Supabase

3. **配置 URL 重定向**
   - 在 **Authentication** → **URL Configuration**
   - 添加 Redirect URLs:
     - `bovaplayer://auth/callback`
     - `http://localhost:3000/auth/callback`（开发用）

### Step 4: 测试连接

创建一个简单的测试脚本来验证配置：

```dart
// test/supabase_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Supabase connection test', () async {
    await Supabase.initialize(
      url: 'https://coljzupoztgupdmadmnr.supabase.co',
      anonKey: 'your-anon-key',
    );
    
    final supabase = Supabase.instance.client;
    
    // 测试查询
    final response = await supabase.from('users').select().limit(1);
    
    print('Connection successful!');
    print('Response: $response');
  });
}
```

---

## 🔒 安全检查清单

- ✅ `.env` 文件已添加到 `.gitignore`
- ✅ 使用 anon key（不是 service_role key）
- ✅ 环境变量不会被提交到 Git
- ⚠️ 确保不要在代码中硬编码密钥
- ⚠️ 生产环境使用不同的配置

---

## 📊 Supabase 项目信息

| 项目信息 | 值 |
|---------|-----|
| **Project ID** | coljzupoztgupdmadmnr |
| **Project URL** | https://coljzupoztgupdmadmnr.supabase.co |
| **Region** | 未知（请在 Dashboard 查看） |
| **Database** | PostgreSQL 15 |
| **配置状态** | ✅ 已配置 |

---

## 🐛 常见问题

### Q: 运行 `flutter pub get` 报错？
A: 确保 Flutter SDK 版本 >= 3.0.0，运行 `flutter --version` 检查

### Q: Supabase 连接失败？
A: 
1. 检查 `.env` 文件中的 URL 和 Key 是否正确
2. 确保网络连接正常
3. 检查 Supabase 项目是否处于活动状态

### Q: 数据库脚本执行失败？
A: 
1. 检查是否有语法错误
2. 确保 UUID 扩展已启用
3. 查看 SQL Editor 的错误信息

### Q: 认证不工作？
A: 
1. 确保在 Supabase Dashboard 启用了 Email 认证
2. 检查 RLS 策略是否正确
3. 查看浏览器控制台的错误信息

---

## 📚 相关文档

- [Supabase 官方文档](https://supabase.com/docs)
- [Flutter Supabase 集成](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)
- [账号体系设计](../../.kiro/specs/cloud-sync/account-system-design.md)
- [实施计划](../../.kiro/specs/cloud-sync/implementation-plan.md)

---

## 🎯 完成后的下一步

配置完成后，你可以：

1. **运行应用**
   ```bash
   flutter run
   ```

2. **测试注册功能**
   - 打开应用
   - 进入登录页面
   - 点击"立即注册"
   - 填写邮箱和密码
   - 提交注册

3. **查看数据库**
   - 在 Supabase Dashboard 的 Table Editor 中
   - 查看 `users` 表
   - 应该能看到新注册的用户

---

**配置完成时间**: 2026-03-02  
**配置状态**: ✅ 环境变量已配置，等待执行数据库脚本  
**下一步**: 执行 Step 1-4

