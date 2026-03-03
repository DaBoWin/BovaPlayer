# 设备注册功能实现

## 功能概述
实现了登录后自动注册当前设备的功能，解决账号页面设备数量显示为 0 的问题。

## 实现内容

### 1. DeviceService
创建了设备服务，负责设备注册和管理：

```dart
lib/features/sync/domain/services/device_service.dart
```

**核心功能**：
- `registerCurrentDevice()` - 注册当前设备
- `getDevices()` - 获取用户的所有设备
- `removeDevice()` - 删除设备
- `_getDeviceInfo()` - 获取设备信息（跨平台）
- `_updateDeviceCount()` - 更新设备数量统计

### 2. 设备信息获取
使用 `device_info_plus` 包获取设备信息：

**支持的平台**：
- Android: 使用 Android ID
- iOS: 使用 identifierForVendor
- macOS: 使用 systemGUID
- Windows: 使用 computerName hash
- Linux: 使用 machineId
- Web: 使用 userAgent hash

**设备信息结构**：
```dart
{
  'device_name': 'MacBook Pro',      // 设备名称
  'device_type': 'macos',            // 设备类型
  'device_id': 'xxx-xxx-xxx',        // 设备唯一标识
}
```

### 3. 注册流程

#### 登录时自动注册
```
1. 用户登录成功
2. 获取设备信息
3. 检查设备是否已注册
   - 已存在：更新 last_active_at
   - 不存在：插入新记录
4. 更新 users.device_count
5. 刷新用户数据
```

#### 数据库操作
```sql
-- 插入新设备
INSERT INTO public.devices (
  user_id,
  device_name,
  device_type,
  device_id
) VALUES (
  '<user_id>',
  'MacBook Pro',
  'macos',
  'xxx-xxx-xxx'
);

-- 更新设备数量
UPDATE public.users
SET device_count = (
  SELECT COUNT(*) FROM public.devices WHERE user_id = '<user_id>'
)
WHERE id = '<user_id>';
```

### 4. 集成到认证流程

修改 `AuthProvider._performInitialSync()`：
```dart
Future<void> _performInitialSync() async {
  // 1. 注册当前设备
  await _deviceService!.registerCurrentDevice();
  
  // 2. 同步数据
  await _syncService!.performInitialSync();
  
  // 3. 刷新用户数据
  await refreshUser();
}
```

## 数据库表结构

### devices 表
```sql
CREATE TABLE public.devices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  
  device_name VARCHAR(100) NOT NULL,
  device_type VARCHAR(20) NOT NULL CHECK (device_type IN ('android', 'ios', 'windows', 'macos', 'linux', 'web')),
  device_id VARCHAR(255) NOT NULL,
  
  last_active_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(user_id, device_id)
);
```

### users 表（相关字段）
```sql
device_count INTEGER DEFAULT 0,  -- 设备数量统计
max_devices INTEGER DEFAULT 2,   -- 设备数量限额
```

## 设备限额检查

### 免费版
- 最多 2 个设备
- 超过限额时提示升级

### Pro 版
- 最多 5 个设备

### 永久版
- 无限设备

### 检查逻辑
```dart
// 在注册设备前检查
final currentCount = await _getDeviceCount();
if (currentCount >= user.limits.maxDevices) {
  throw Exception('设备数量已达上限，请升级账号或删除旧设备');
}
```

## 设备管理功能

### 查看设备列表
```dart
final devices = await deviceService.getDevices();
// 返回：
// [
//   {
//     'id': 'xxx',
//     'device_name': 'MacBook Pro',
//     'device_type': 'macos',
//     'last_active_at': '2026-03-02T10:00:00Z',
//   },
//   ...
// ]
```

### 删除设备
```dart
await deviceService.removeDevice(deviceId);
// 自动更新 device_count
```

## 安全考虑

### 1. 设备唯一标识
- Android: 使用 Android ID（可重置）
- iOS: 使用 identifierForVendor（卸载后重置）
- macOS: 使用 systemGUID（硬件标识）
- Windows/Linux: 使用计算机名 hash（可能重复）

### 2. 隐私保护
- 不收集设备序列号
- 不收集 MAC 地址
- 不收集 IMEI/MEID

### 3. 设备验证
- 使用 UNIQUE 约束防止重复注册
- 使用 user_id 关联确保数据隔离

## RLS 策略

需要添加以下 RLS 策略：

```sql
-- 用户可以查看自己的设备
CREATE POLICY "Users can view own devices"
ON public.devices FOR SELECT
USING (auth.uid() = user_id);

-- 用户可以插入自己的设备
CREATE POLICY "Users can insert own devices"
ON public.devices FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- 用户可以更新自己的设备
CREATE POLICY "Users can update own devices"
ON public.devices FOR UPDATE
USING (auth.uid() = user_id);

-- 用户可以删除自己的设备
CREATE POLICY "Users can delete own devices"
ON public.devices FOR DELETE
USING (auth.uid() = user_id);
```

## 依赖包

添加到 `pubspec.yaml`：
```yaml
dependencies:
  device_info_plus: ^10.1.0
```

安装：
```bash
cd ui/flutter_app
flutter pub get
```

## 测试步骤

### 场景 1：首次登录
1. 注册并登录账号
2. 查看控制台日志：
   ```
   [Device] 开始注册设备...
   [Device] 设备信息: {device_name: MacBook Pro, device_type: macos, device_id: xxx}
   [Device] 注册新设备
   [Device] 设备数量已更新: 1
   [Device] 设备注册完成
   ```
3. 打开账号页面，验证设备数量显示为 1/2

### 场景 2：多设备登录
1. 在设备 A 登录
2. 在设备 B 登录同一账号
3. 账号页面应显示 2/2
4. 在 Supabase Dashboard 查看 devices 表，应该有 2 条记录

### 场景 3：重复登录
1. 登录账号
2. 登出
3. 再次登录
4. 设备数量应该保持不变（不会重复注册）

### 场景 4：超过限额
1. 免费用户在 2 个设备上登录
2. 在第 3 个设备上登录
3. 应该成功登录（当前未实现限额检查）
4. 账号页面显示 3/2（超限）

## 待实现功能

### 1. 设备限额检查
在注册设备前检查是否超过限额：
```dart
if (currentCount >= user.limits.maxDevices && user.limits.maxDevices != -1) {
  throw DeviceLimitExceededException();
}
```

### 2. 设备管理页面
创建设备管理页面，显示：
- 设备列表
- 设备类型图标
- 最后活跃时间
- 删除按钮

### 3. 设备信任
- 标记信任设备
- 非信任设备需要二次验证

### 4. 设备通知
- 新设备登录时发送通知
- 异常登录检测

### 5. 设备会话管理
- 远程登出设备
- 查看设备活跃状态

## 存储空间统计

存储空间统计需要在上传数据时计算：

### 计算逻辑
```dart
// 计算 JSON 数据大小
final jsonData = jsonEncode(data);
final sizeBytes = utf8.encode(jsonData).length;
final sizeMb = sizeBytes / (1024 * 1024);

// 更新存储使用量
await _supabase
  .from('users')
  .update({
    'storage_used_mb': FieldValue.increment(sizeMb),
  })
  .eq('id', userId);
```

### 统计项目
- 服务器列表数据
- 播放历史数据
- 收藏列表数据
- 用户设置数据

## 日志输出

设备注册过程会输出详细日志：
```
[Auth] 注册设备...
[Device] 开始注册设备...
[Device] 设备信息: {device_name: MacBook Pro, device_type: macos, device_id: xxx-xxx-xxx}
[Device] 注册新设备
[Device] 设备数量已更新: 1
[Device] 设备注册完成
[Auth] 开始首次同步...
[Sync] 开始完整同步...
...
```

## 文件清单

新增文件：
- ✅ `lib/features/sync/domain/services/device_service.dart`

修改文件：
- ✅ `lib/features/auth/presentation/providers/auth_provider.dart`
- ✅ `pubspec.yaml`

## 完成时间
2026-03-02
