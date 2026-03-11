# BovaPlayer

> 一个面向个人媒体场景的跨平台播放器与媒体中枢。  
> 统一播放、发现、媒体库与多源接入体验，尽量减少“找资源”和“开始播放”之间的阻力。

[![Release](https://img.shields.io/github/v/release/DaBoWin/BovaPlayer)](https://github.com/DaBoWin/BovaPlayer/releases)
[![Stars](https://img.shields.io/github/stars/DaBoWin/BovaPlayer?style=flat)](https://github.com/DaBoWin/BovaPlayer/stargazers)
[![License](https://img.shields.io/github/license/DaBoWin/BovaPlayer)](https://github.com/DaBoWin/BovaPlayer)

## 项目定位

BovaPlayer 不是单纯的本地播放器，也不是单一媒体服务器客户端。  
它正在被打造成一个统一入口，用来串联：

- 本地文件播放
- Emby 媒体服务器
- SMB / FTP 网络媒体源
- TMDB 驱动的内容发现
- 账号、同步与跨设备恢复

目标很直接：

- 更快从“看到内容”进入“开始播放”
- 不在多个工具之间来回切换
- 桌面端和移动端保持同一套品牌语言与核心体验

## 核心特性

### 播放

- 支持 macOS / Windows / Android
- 支持本地与网络媒体播放
- 支持播放进度记忆、续播、字幕处理
- 桌面端支持独立播放器窗口
- 针对服务器与网络源做了播放链路优化

### 播放内核

- `MDK`：用于独立播放器窗口与部分桌面播放链路
- `MPV / media_kit`：用于 Flutter 内的通用播放能力

也就是说，当前项目是 **MDK + MPV 双修架构**，不是单一播放器内核。

### 媒体源

- Emby 媒体源管理与媒体库浏览
- SMB / FTP 网络连接管理
- 首页 Discover 内容与本地媒体源匹配
- 快捷播放直达，不必强制先进入媒体库页

### 产品层

- 统一设计系统与桌面 / 移动双壳层
- Supabase 账号、同步、订阅能力
- TMDB 内容发现、搜索与海报数据
- Windows 自定义标题栏与窗口控制

## 平台状态

| 平台 | 状态 | 说明 |
| --- | --- | --- |
| macOS | 可用 | 当前本地开发主平台 |
| Windows | 可用 | 支持桌面壳层、自定义窗口控制 |
| Android | 可用 | 已适配移动壳层与触屏布局 |

## 项目结构

```text
.
├── ui/flutter_app/        # 主应用代码（当前核心）
├── docs/                  # 长期有效文档
├── scripts/               # 本地辅助脚本
├── .github/workflows/     # CI 构建与发布
└── core/                  # 早期 Rust 试验区 / 历史遗留模块
```

## 快速开始

### 1. 准备环境变量

```bash
cp ui/flutter_app/.env.example ui/flutter_app/.env
```

至少补齐这些配置：

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `TMDB_READ_ACCESS_TOKEN` 或 `TMDB_API_KEY`

### 2. 本地运行

macOS:

```bash
./scripts/run_macos.sh
```

Android:

```bash
cd ui/flutter_app
flutter run -d <device-id>
```

Windows:

```bash
cd ui/flutter_app
flutter run -d windows
```

## 本地构建

统一入口：

```bash
./scripts/build_local.sh macos
./scripts/build_local.sh android
./scripts/build_local.sh windows
```

说明：

- `macos` 只能在 macOS 上构建
- `windows` 需要在 Windows 上构建
- Android 需要 Flutter 与 Android SDK

## 发布构建

GitHub Actions 会在 tag 推送后自动构建并打包发布。

常规版本：

```bash
git tag v0.6.0
git push origin v0.6.0
```

按平台过滤的 tag 规则见：

- [开发说明](docs/development.md)

## 文档导航

- [开发说明](docs/development.md)
- [设计系统](docs/design-system.md)
- [问题排查](docs/troubleshooting.md)
- [路线图](ROADMAP.md)

## 当前演进方向

最近几轮主要集中在：

- 首页 Discover 到播放器的快速播放链路优化
- Emby 匹配与跨设备媒体源恢复
- Android / Windows UI 兼容与一致性
- 桌面窗口控制与双播放器链路梳理
- 文档、脚本与仓库结构清理

## 项目状态

BovaPlayer 处于持续迭代中，当前重点是把“多源媒体入口 + 快速播放 + 跨平台体验”打磨完整，而不是停留在演示级播放器。
