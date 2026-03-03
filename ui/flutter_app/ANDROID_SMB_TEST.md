# Android SMB 功能测试指南

## 📋 实现完成情况

### ✅ 已完成
- SMB 连接和认证（使用 jcifs-ng 2.1.10）
- 目录浏览和文件列表
- 文件读取（支持 Range 请求）
- 错误处理和日志记录
- 异步执行（避免阻塞 UI）

### 🔧 技术实现
- **库**: jcifs-ng 2.1.10
- **协议**: SMB 2.02 - SMB 3.1.1
- **认证**: NTLM 密码认证
- **超时**: 30 秒连接/响应超时

## 🧪 测试步骤

### 1. 准备测试环境

#### 选项 A: 使用 NAS（推荐）
- 群晖 (Synology)
- 威联通 (QNAP)
- 其他支持 SMB 的 NAS

#### 选项 B: 使用 Windows 共享
1. 在 Windows 上创建共享文件夹
2. 右键文件夹 → 属性 → 共享 → 高级共享
3. 设置共享名称和权限
4. 记录：
   - 主机 IP 地址
   - 共享名称
   - 用户名和密码

#### 选项 C: 使用 Linux Samba
```bash
# 安装 Samba
sudo apt-get install samba

# 配置共享
sudo nano /etc/samba/smb.conf

# 添加共享配置
[share]
   path = /path/to/share
   browseable = yes
   read only = no
   guest ok = no

# 创建 Samba 用户
sudo smbpasswd -a username

# 重启服务
sudo systemctl restart smbd
```

### 2. 构建 Android 应用

```bash
cd ui/flutter_app

# 清理构建
flutter clean

# 获取依赖
flutter pub get

# 构建 APK（调试版）
flutter build apk --debug

# 或构建 Release 版
flutter build apk --release

# 安装到设备
flutter install
```

### 3. 测试连接

#### 3.1 添加 SMB 连接
1. 打开应用
2. 进入"网络浏览器"页面
3. 点击右下角 "+" 按钮
4. 选择协议: **SMB**
5. 填写信息:
   - **名称**: 自定义名称（如"我的 NAS"）
   - **主机**: NAS/服务器 IP 地址（如 192.168.1.100）
   - **端口**: 445（默认）
   - **用户名**: SMB 用户名
   - **密码**: SMB 密码
   - **共享名**: 共享文件夹名称（如 "share", "movies"）
   - **工作组**: WORKGROUP（默认）
6. 点击"保存"

#### 3.2 连接测试
1. 点击刚添加的连接
2. 观察连接状态:
   - ✅ 成功: 显示文件列表
   - ❌ 失败: 显示错误信息

#### 3.3 浏览文件
1. 点击文件夹进入子目录
2. 验证文件列表正确显示:
   - 文件名
   - 文件大小
   - 文件/文件夹图标

#### 3.4 播放视频
1. 点击视频文件
2. 验证播放功能:
   - 视频能否正常加载
   - 播放是否流畅
   - 进度条是否正常
   - Seek 是否正常

### 4. 查看日志

使用 Android Studio 或 adb 查看日志：

```bash
# 查看所有日志
adb logcat | grep SMBHandler

# 查看连接日志
adb logcat | grep "连接到 SMB"

# 查看错误日志
adb logcat | grep "SMB.*失败"
```

## 🐛 常见问题排查

### 问题 1: 连接失败 "Connection refused"
**原因**: 
- 主机 IP 地址错误
- 端口被防火墙阻止
- SMB 服务未启动

**解决**:
```bash
# 测试网络连接
ping <主机IP>

# 测试 SMB 端口
telnet <主机IP> 445

# 或使用 nc
nc -zv <主机IP> 445
```

### 问题 2: 认证失败 "Authentication failed"
**原因**:
- 用户名或密码错误
- 工作组不匹配
- 用户权限不足

**解决**:
- 确认用户名和密码正确
- 尝试使用 "WORKGROUP" 作为工作组
- 检查 NAS/服务器上的用户权限

### 问题 3: 找不到共享 "Share not found"
**原因**:
- 共享名称错误
- 共享未启用
- 权限不足

**解决**:
- 在 Windows 上: `\\<主机IP>\` 查看可用共享
- 在 Linux 上: `smbclient -L <主机IP> -U <用户名>`
- 确认共享名称大小写正确

### 问题 4: 播放卡顿或失败
**原因**:
- 网络速度慢
- 文件太大
- 编码格式不支持

**解决**:
- 检查 WiFi 信号强度
- 尝试播放较小的文件
- 查看播放器日志

### 问题 5: 权限错误
**原因**:
- Android 网络权限未授予
- 应用未正确配置

**解决**:
- 检查 AndroidManifest.xml 中的权限
- 重新安装应用

## 📊 性能测试

### 测试场景
1. **小文件** (< 100MB)
   - 连接时间: < 3 秒
   - 首帧时间: < 2 秒
   - Seek 响应: < 1 秒

2. **中等文件** (100MB - 1GB)
   - 连接时间: < 5 秒
   - 首帧时间: < 3 秒
   - Seek 响应: < 2 秒

3. **大文件** (> 1GB)
   - 连接时间: < 5 秒
   - 首帧时间: < 5 秒
   - Seek 响应: < 3 秒

### 测试网络环境
- WiFi 5 (802.11ac): 推荐
- WiFi 6 (802.11ax): 最佳
- 移动网络: 不推荐（延迟高）

## ✅ 验收标准

### 功能验收
- [ ] 能成功连接到 SMB 服务器
- [ ] 能正确列出文件和文件夹
- [ ] 能进入子目录
- [ ] 能播放视频文件
- [ ] 能正常 Seek（快进/快退）
- [ ] 能处理大文件（> 1GB）
- [ ] 错误提示清晰友好

### 兼容性验收
- [ ] 群晖 NAS
- [ ] 威联通 NAS
- [ ] Windows 共享
- [ ] Linux Samba
- [ ] SMB 2.x 协议
- [ ] SMB 3.x 协议

### 性能验收
- [ ] 连接时间 < 5 秒
- [ ] 首帧时间 < 5 秒
- [ ] Seek 响应 < 3 秒
- [ ] 播放流畅（无明显卡顿）
- [ ] 内存占用合理（< 200MB）

## 🔍 调试技巧

### 启用详细日志
在 `SmbHandler.kt` 中已经添加了详细的日志输出：
- 连接信息
- 文件列表
- 读取操作
- 错误信息

### 使用 Android Studio Profiler
1. 打开 Android Studio
2. 运行应用
3. 打开 Profiler
4. 监控:
   - CPU 使用率
   - 内存使用
   - 网络流量

### 抓包分析
```bash
# 使用 tcpdump 抓包
adb shell tcpdump -i any -s 0 -w /sdcard/smb.pcap port 445

# 下载抓包文件
adb pull /sdcard/smb.pcap

# 使用 Wireshark 分析
wireshark smb.pcap
```

## 📝 测试报告模板

```markdown
## SMB 功能测试报告

**测试日期**: YYYY-MM-DD
**测试人员**: [姓名]
**应用版本**: [版本号]
**Android 版本**: [版本]
**设备型号**: [型号]

### 测试环境
- **SMB 服务器**: [NAS型号/Windows版本/Linux发行版]
- **网络环境**: [WiFi 5/WiFi 6/有线]
- **测试文件**: [文件大小和格式]

### 测试结果
| 测试项 | 结果 | 备注 |
|--------|------|------|
| 连接功能 | ✅/❌ | |
| 目录浏览 | ✅/❌ | |
| 文件播放 | ✅/❌ | |
| Seek 功能 | ✅/❌ | |
| 大文件支持 | ✅/❌ | |
| 错误处理 | ✅/❌ | |

### 性能数据
- 连接时间: [X] 秒
- 首帧时间: [X] 秒
- Seek 响应: [X] 秒
- 平均内存: [X] MB

### 问题记录
1. [问题描述]
   - 复现步骤: 
   - 错误信息:
   - 解决方案:

### 总体评价
[通过/不通过]

### 建议
[改进建议]
```

## 🚀 下一步

完成测试后，可以：
1. 提交测试报告
2. 记录发现的问题
3. 提出改进建议
4. 更新文档

## 📞 支持

如有问题，请：
1. 查看日志输出
2. 参考常见问题
3. 提交 Issue（附带日志）
