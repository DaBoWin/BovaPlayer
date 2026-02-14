# 构建标签使用指南

## 概述

通过不同的 tag 命名方式，可以控制 GitHub Actions 构建哪些平台。

## Tag 命名规则

### 1. 构建所有平台
```bash
git tag v0.0.3
git push origin v0.0.3
```
构建：Windows + macOS + Android

### 2. 只构建 Android
```bash
git tag v0.0.3-android
git push origin v0.0.3-android
```
构建：仅 Android

### 3. 只构建 Windows
```bash
git tag v0.0.3-windows
git push origin v0.0.3-windows
```
构建：仅 Windows

### 4. 只构建 macOS
```bash
git tag v0.0.3-macos
git push origin v0.0.3-macos
```
构建：仅 macOS

### 5. 构建 Windows + macOS（排除 Android）
```bash
git tag v0.0.3-android
git push origin v0.0.3-android
```
由于 tag 包含 `-android`，会跳过 Android 构建，只构建 Windows 和 macOS。

## 手动触发构建

在 GitHub Actions 页面，可以手动触发 workflow 并选择要构建的平台：

1. 进入 GitHub 仓库的 Actions 页面
2. 选择 "Build All Platforms" workflow
3. 点击 "Run workflow"
4. 在下拉菜单中选择平台：
   - `all` - 构建所有平台
   - `windows` - 仅 Windows
   - `macos` - 仅 macOS
   - `android` - 仅 Android

## 示例场景

### 场景 1：快速测试 Android 构建
```bash
git tag v0.0.3-android-test
git push origin v0.0.3-android-test
```
只会触发 Android 构建，节省时间。

### 场景 2：发布正式版本
```bash
git tag v1.0.0
git push origin v1.0.0
```
构建所有平台并创建完整的 Release。

### 场景 3：更新 tag 到最新提交
```bash
# 删除本地 tag
git tag -d v0.0.2

# 创建新 tag
git tag v0.0.2

# 强制推送
git push origin v0.0.2 --force
```

## 注意事项

1. Release 只会在推送 tag 时创建（不包括手动触发）
2. Release 会包含所有成功构建的平台文件
3. 如果某个平台构建失败，Release 仍会创建，但不包含失败平台的文件
4. Tag 名称必须以 `v` 开头才会触发构建
