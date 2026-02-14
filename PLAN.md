Project NovaPlayer（代号：BovaPlayer）— 项目开发与架构设计方案
版本：v0.1（架构蓝图草案）
作者角色：拥有15+年经验的媒体播放器架构师
目标平台：Windows / macOS / Linux / Android / iOS / tvOS / Android TV / web（实验性）/ VR（后续阶段）

1. 项目概述（Vision & Differentiation）
统一体验（Unified Experience）
一套核心 + 多端外壳，UI一致、交互一致、媒体库一致。
无缝整合本地、NAS、媒体服务器（Emby/Jellyfin/Plex）、云盘（Drive/OneDrive/Aliyun Drive）。
性能怪兽（Performance Beast）
硬件解码优先，软解兜底。面向 8K/120fps/HDR10+/Dolby Vision。
现代渲染管线（Vulkan/Metal/D3D12），端到端色彩管理 + 高质量后处理。
智能聚合（Intelligent Aggregation）
多源聚合、元数据刮削、版本管理、智能播放列表。
双向同步播放历史/观看进度。
开放生态（Open Ecosystem）
安全且强大的插件系统（Lua/JS/Python 可选），可扩展数据源、滤镜、字幕、皮肤。
官方插件市场与签名机制，自动更新与权限治理。
核心竞争力：

“内核即平台”与“渲染即能力”：以跨平台的多媒体内核为中心，统一编解码、渲染、音频与字幕；以现代 GPU 管线与色彩管理为“画质与低延迟”的压舱石。
“数据聚合 + 智能库 + 开放插件”：将播放器从单一播放工具提升为“个人媒体操作系统”。
2. 技术栈选型（Tech Stack）
核心语言与框架
核心内核：Rust（首选）或 C++20
Rust 理由：内存安全、现代并发、FFI 友好；可与 FFmpeg、libass、libplacebo 等 C 库对接；适合打造高可靠“长寿命”内核。
如团队当前 C++ 积累更强，可选 C++20 并通过 GSL/Span/Smart Pointers 规范化内存与错误管理。
媒体解码：FFmpeg（最新 LTS 分支，启用 AV1/HEVC/VP9/Opus/TrueHD 等）
硬件解码：D3D11VA/DXVA2（Windows），VideoToolbox（macOS/iOS/tvOS），VA-API/VDPAU（Linux），MediaCodec（Android）
渲染管线：libplacebo + wgpu（优先）/Vulkan 直连 + 平台后端（D3D12/Metal）
理由：libplacebo 提供高质量 tone-mapping/缩放/色彩管理，与 mpv 等成熟玩家同源；wgpu 屏蔽后端差异（Vulkan/Metal/DX12），跨平台友好。
音频系统
解码：FFmpeg
输出抽象：自研 AudioSink + 平台后端（WASAPI/CoreAudio/ALSA/PulseAudio/AAudio）
Passthrough：WASAPI（bitstream/exclusive），CoreAudio（HDMI），ALSA IEC958/HDMI；按设备能力协商
字幕系统
文本与特效：libass（ASS/SSA）
图形字幕：PGS/VobSub 栅格化管线（GPU 混合/合成路径）
文本 shaping：HarfBuzz
在线字幕：OpenSubtitles 等 API；AI 翻译（可选：本地 LLM 插件或云端）
数据与媒体库
数据库：SQLite（FTS5 索引）为默认；可选 PostgreSQL（远程/多用户场景）
本地扫描与监控：cross-platform file watcher（inotify/FSEvents/ReadDirectoryChangesW）
媒体服务器：Emby/Jellyfin/Plex 官方/非官方 SDK + GraphQL/REST
云存储：优先集成 rclone（统一适配层）+ 针对主流云盘的原生 API 插件
刮削：TMDB/TheTVDB/IMDb/anidb 多源融合，文件名/路径/MediaInfo/哈希识别
UI/UX 层
UI 框架：Flutter（首选）或 Qt/QML（备选）
Flutter 理由：跨端一致性佳，移动/TV 生态成熟；通过 platform channel + external texture 与内核渲染整合；Impeller 渲染器成熟中。
Qt/QML 理由：桌面/嵌入式性能与成熟度高，Native 集成更直接；但移动与 TV 生态不如 Flutter。
VR/AR：后续通过 OpenXR 前端（Unity/Unreal/Flutter Impeller WebXR 实验）
插件系统
语言：Lua（首选，轻量高性能，安全容器易做）+ JS（QuickJS/Deno, 可选）+ Python（PyO3/多进程沙箱，可选）
沙箱：进程隔离 + 权限声明 + 能力边界（Capabilities）+ IPC（gRPC/Flatbuffers/Cap’n Proto）
工程与工具
构建：Rust（cargo）/CMake（C++），跨平台 CI（GitHub Actions）
打包：Windows MSIX/MSI，macOS .app + notarization，Linux AppImage/Snap/Flatpak，Android App Bundle，iOS/tvOS IPA
崩溃收集：Sentry/Crashpad
遥测（可选/严格隐私）：匿名设备与性能指标，用户可完全关闭
3. 软件架构图（High-Level Architecture）
mermaid
flowchart LR
  subgraph UI[UI Layer - Flutter/Qt/QML]
    PV[Player View]
    LV[Library View]
    Settings[Settings & Theming]
    ExtMgr[Plugin Manager UI]
  end

  subgraph Core[Core Engine (Rust/C++ - Headless)]
    subgraph Playback[Playback Subsystem]
      Demux[Demux/FFmpeg]
      HWDec[HW Decode Adapters]
      SWDec[SW Decode/FFmpeg]
      AVSync[Clock & AV Sync]
      Filters[Video/Audio Filters]
      SubSys[Subtitle Pipeline (libass/PGS)]
    end

    subgraph Render[Render Pipeline]
      GraphAPI[wgpu/Vulkan/Metal/D3D12 Abstraction]
      Placebo[libplacebo: Tone-map/Scale/Color]
      Shaders[User Shaders]
      VSync[Swap & Present]
    end

    subgraph Audio[Audio Output]
      Mix[Mixer/EQ/Normalization]
      Passthrough[HDMI Passthrough]
      AOut[WASAPI/CoreAudio/ALSA/AAudio]
    end

    subgraph Data[Data & Library]
      Scan[Indexer/Watchers]
      Scrape[Metadata Scrapers]
      DB[(SQLite + FTS5)]
      Sync[Sync: Emby/Jellyfin/Plex]
      Cloud[Cloud: rclone/APIs]
      Cache[HTTP Cache/Chunk Cache]
    end

    subgraph Plugins[Plugins & Ext]
      Host[Plugin Host & Sandbox]
      API[Stable API Surface]
      Store[Plugin Store/Update]
    end

    IPC[IPC/FFI: Platform Channels/gRPC]
    Telemetry[Crash/Perf/Logs]
  end

  UI <--> IPC
  IPC <--> Core
  Playback --> Render
  Playback --> Audio
  Playback --> SubSys
  Data <--> Core
  Plugins <--> Core
  SubSys --> Render
数据流关键点：

UI 通过 IPC/FFI 调用 Core 的 use-cases（播放、浏览、搜索、设置、插件管理）。
Core 的 Playback 统一调度解复用、解码、同步，向 Render/Audio/Subtitles 输出。
Data 层提供媒体索引、刮削、同步与缓存服务，供 UI 与 Playback 查询与订阅。
Plugins 以沙箱运行，通过稳定 API 访问可授权的子系统能力。
4. 各模块详细设计（Deep Dive）
4.1 播放核心引擎（Core Engine）
解码策略
优先硬解：按平台能力动态选择（D3D11VA/VideoToolbox/VA-API/MediaCodec），同时提供能力检测与黑名单（edge case 机型规避）。
智能 fallback：硬解失败或不支持时自动软解（FFmpeg），支持并行探测、无缝切换。
高规格支持：AV1（硬解优先，软解使用 dav1d）、HEVC、VP9；高帧率（120fps+）与高位深（10/12bit）管线贯通。
ISO/蓝光/DVD：
ISO mount 虚拟文件系统 + FFmpeg/bluray 库支持导航数据读取；
菜单导航：基于 libbluray（BD-J 复杂度高，初期支持 BD-Lite，后续逐步完善）；DVD 菜单以 VM 引擎实现。
渲染管线（Rendering Pipeline）
后端抽象：首选 wgpu，将 Vulkan/Metal/D3D12 统一在一套 API 下；如需极致性能可在特定平台下引入专用后端分支优化。
色彩管理：
libplacebo 提供端到端色彩转换与 tone-mapping：
HDR10/HDR10+/HLG/Dolby Vision（Profile 管理，优先支持 Profile 5/8.1，可配置偏好）
SD(HDR) <-> SDR tone-map（Hable/Reinhard/Mobile-optimized），场景参考/显示参考选择
裁剪与 gamut mapping；ICC/EDID 读取与显示校准支持
后处理：
缩放：Lanczos/Spline36/FSR/NIS/Anime4K/NNEDI3（插件化，按 GPU 选择）
降噪/锐化：bilateral/temporal（可选）/unsharp-mask；用户可加载自定义着色器（GLSL/HLSL/WGSL 统一转换）
帧插（后续）：SVP/FFmpeg-vf/厂商 SDK（谨慎引入，延迟与抖动控制）
低延迟路径：直通呈现、智能缓冲、呈现时间戳预测、VSync 同步策略（VRR/G-Sync/FreeSync 探测）
音频系统
解码：多声道/高采样率支持；bit-exact 路径；dither 与重采样（soxr）
Passthrough/Bitstream：
能力协商：EDID/OS 能力查询；自动/手动策略；HDMI handshake 监控
支持：AC3/EAC3/DTS/DTS-HD/TrueHD/Atmos（封装检测与容错）
音效：10/31 段 EQ、响度归一化（EBU R128）、声道映射/Downmix、延迟补偿
字幕系统
格式：SRT/ASS/SSA/PGS/VobSub/TTML/WebVTT
渲染：libass 独立渲染器，GPU 合成；高 DPI、精准排版；复杂特效兼容性测试矩阵
智能功能：在线搜索/下载，时间轴微调/偏移，AI 翻译（可与插件系统集成），多字幕轨动态切换与样式覆盖
4.2 数据源与媒体库（Data & Library）
多源聚合
本地：递归扫描 + 增量索引；文件系统监控（平台特定后端）；媒体指纹（哈希 + MediaInfo）
网络：SMB/NFS/WebDAV 原生支持；连接配置与凭证管理加密
媒体服务器：Emby/Jellyfin/Plex 双向同步观看状态、收藏、播放列表；离线缓存策略
云存储：rclone 统一适配 + 主流云原生插件；分块拉流、范围请求；“边播边缓存”策略（可配置）
元数据刮削与管理
识别：基于文件名（正则 + 规则库）、目录结构、媒体标签、哈希；冲突分辨（交互式修正）
数据源融合：TMDB/TheTVDB/IMDb/anidb 多源取最优（评分/别名/演员合并）；本地化优先策略
版本管理：同一影片多个版本（分辨率/剪辑版/音轨/封装），建立版本实体并聚合展示
数据库：SQLite + FTS5（标题/演员/导演/系列/标签）；按需建立物化视图/索引
缓存：海报/背景图/人脸图缓存；预取策略（瀑布流视图滚动预测）
流式播放与缓存
DASH/HLS 原生支持；range requests；多 CDN 切换策略
局部缓存：LRU + 温度模型；可配置磁盘/内存占用上限；离线下载与完整文件校验
4.3 用户界面与体验（UI/UX）
界面框架
Flutter 首选：单代码库覆盖移动/桌面/TV，强 UI 表达力与生态；Native 渲染通过 PlatformChannel + ExternalTexture 接入 GPU 帧。
Qt/QML 作为桌面与嵌入式备选（若团队已有深厚 Qt 资产）。
两种模式
播放器模式（Player View）
极简 HUD，手势/快捷键丰富；信息层（码率/色彩/帧率/音轨/字幕/HDR 标识）一键可见
弹性控制条与弹幕/注释（可选）；截图/片段导出/Marker 与书签
媒体库模式（Library View）
海报墙/系列/季集/演员卡片；强筛选（类型/年份/分辨率/版本/标签）
智能播放列表（最近添加/未看完/最高评分/家庭友好/儿童模式）
个性化
主题引擎：颜色/字体/圆角/布局密度；动态壁纸；动画时序可调
键鼠/手柄/遥控器/触控统一输入映射；用户快捷宏（链式命令）
无障碍：屏幕阅读器、对比度模式、字幕可读性预设
4.4 插件与扩展系统（Plugins & Extensions）
API 设计原则
稳定、版本化（SemVer），后向兼容；能力最小化（最小权限集）；异步与事件驱动
插件类型
数据源插件：云盘/流媒体/服务器协议
媒体处理：视频/音频滤镜、着色器包、后处理链
字幕：供应商适配、智能匹配器、翻译器
UI：主题/皮肤、信息面板、可视化器
运行与安全
Lua（内置，轻量高效）；JS（QuickJS/Deno，选配）；Python（隔离进程）
权限模型：文件系统访问、网络、库写入、渲染访问、音频访问等需声明并审批
沙箱：进程隔离 + 安全 IPC；超时/资源配额/审计日志
插件市场
官方签名与哈希校验；版本通道（稳定/测试/实验）
自动更新与回滚；评分与兼容性矩阵；隐私与权限披露 UI
5. 开发路线图（Roadmap）
v0.1 内核原型（8-10 周）
基本媒体解复用/解码（FFmpeg）+ 渲染（wgpu + libplacebo）
音频输出（WASAPI/CoreAudio/ALSA/AAudio）+ 基本同步
Flutter/Qt 外壳原型，播放视图可跑通 file://
v0.2 硬件加速与字幕（6-8 周）
D3D11VA/VideoToolbox/VA-API/MediaCodec 接入，动态能力检测
libass 集成，SRT/ASS/PGS，基本样式与 GPU 合成
播放列表、基础键鼠/遥控器映射
v0.3 渲染进阶与音频特性（8-10 周）
HDR10/SDR tone-mapping，基础色彩管理；FSR/NIS 缩放
EQ/响度归一化/声道映射；WASAPI 独占/bitstream（阶段性）
崩溃收集/诊断面板/统计 OSD
v0.4 媒体库与刮削（10-12 周）
本地索引器 + FSEvents/inotify/WinFS 监控；SQLite + FTS5
TMDB/TheTVDB 刮削；多版本聚合；海报墙 UI v1
Emby/Jellyfin/Plex 同步（观看状态双向）
v0.5 云与缓存（8-10 周）
rclone 集成；云盘拉流 + 范围请求；边播边缓存 + 离线下载
HLS/DASH 播放优化；网络适配器与速率控制
v0.6 插件系统（10-12 周）
Lua 插件 Host + 权限系统；插件商店 MVP；主题插件
选配 JS 插件支持（QuickJS）
v0.7 画质与高级音频（8-12 周）
HDR10+/HLG；Dolby Vision Profiles（5/8.1 优先，合规策略）
DTS-HD/TrueHD/Atmos passthrough 完整协商路径
v0.8 跨端打磨与稳定性（持续）
Android TV / tvOS / Windows / macOS / Linux 一致性细节
性能与功耗优化，冷启动与 Seek RT 优化
v1.0 正式发布
稳定 API、完善测试矩阵（格式/平台/设备）
文档、插件生态上线、隐私合规与本地化完善
6. 主要挑战与解决方案（Challenges & Mitigations）
硬件解码兼容性碎片化
解决：设备能力探测 + 黑名单机制；双通道解码预热；降级策略与用户可选项；自动收集失败签名，CI 回归集成
HDR/Dolby Vision 的一致性与合规
解决：libplacebo 色彩流程为基线；DV 以合规 Profile 支持，优先增强层忽略策略或解码器 SDK；提供“创作者意图”与“增强观感”双模式
跨平台渲染与 UI 性能
解决：渲染与 UI 严格分离；GPU 帧通过外部纹理/零拷贝路径；对 Flutter 进行平台通道批处理与异步化；必要时平台专用后端优化
音频 Bitstream 与设备协商
解决：EDID/OS 能力探测 + 回退 PCM 路径；显式提示用户设置；独占模式的可靠切换与失败恢复
云与网络不稳定性
解决：多源策略、断点续传、局部缓存与温度淘汰；CDN 切换；超时/重试/指数回退；带宽自适应
插件安全与稳定
解决：强权限模型、进程隔离、资源配额、签名与商店审核；崩溃隔离与自动禁用；审计日志与“只读模式”
数据库一致性与扩展
解决：迁移脚本与版本化 schema；写放大控制；FTS 索引策略与 VACUUM 维护；远端库采用 PostgreSQL 可选方案
7. 核心子系统的关键接口与抽象（概述）
播放控制（Core API）
open(url, options) -> media_handle
play/pause/stop/seek(time, flags)
select_track(type, id)（audio/subtitle/video variant）
set_property(key, value)/get_property(key)
事件：on_state_change/on_error/on_stats/on_media_info
渲染接口
get_video_frame(surface_request) -> gpu_texture_handle
set_tone_map(mode, params)、set_scaler(type, params)
push_shader(shader_package)
音频接口
set_passthrough(enabled, formats_pref)、set_eq(profile)、set_loudness(mode)
数据/媒体库接口
scan(paths)、query(criteria)、get_artwork(id, size)、sync(server_profile)
插件 API（Lua）
生命周期：init(), on_event(e), dispose()
能力：http.fetch, db.query, player.get/set, subtitle.search/download, ui.panel/register
权限：清单声明 + 审批，运行期可见
8. 代码库结构（建议）
repo/
  core/                    # Rust/C++ 核心
    av/                    # 解复用/解码/同步
    render/                # 渲染抽象 & libplacebo 集成
    audio/                 # 输出/混音/均衡器/直通
    subs/                  # 字幕管线
    io/                    # FS/网络/缓存
    data/                  # 索引/刮削/数据库
    plugins/               # 插件宿主/沙箱/API
    ipc/                   # FFI/IPC 层（platform channel/gRPC/Flatbuffers）
    utils/                 # 公共工具/日志/遥测
  ui/
    flutter_app/           # Flutter 前端（各端 Runner）
    qt_shell/              # 备选 Qt 外壳（桌面）
  third_party/             # FFmpeg/libass/libplacebo/wgpu/harfbuzz/soxr/...
  docs/                    # 设计与规范/贡献指南/插件 API 文档
  tools/                   # 打包/CI/CD 脚本
  tests/
    media_matrix/          # 覆盖多格式/多规格的测试资产描述
    e2e/                   # 端到端自动化
9. 质量保障与性能（QA & Perf）
测试矩阵
格式矩阵（容器/编码/位深/帧率/HDR/DV）
平台矩阵（OS 版本/驱动/GPU/音频设备）
回归集：已知问题资产库 + 自动化用例（seek 抖动、音画同步、字幕时基、切轨）
性能指标
启动时间、首帧时间、seek 时间、中位和 P95 掉帧率、渲染耗时分布、CPU/GPU 占用、功耗
诊断工具
OSD 实时统计、Trace 导出（perfetto/ETW）、GPU 标记（debug markers）、日志等级策略
隐私与合规
遥测默认关闭或首次启动明确选择；GDPR/CCPA 合规
10. 人员与协作（People & Process）
小组划分
Core（解码/渲染/音频/字幕）
Data（扫描/刮削/DB/云/服务器）
UI（Flutter/TV/桌面/主题）
Plugins（宿主/安全/商店）
DevOps（CI/CD/打包/崩溃/遥测）
工程规约
Rust：clippy + rustfmt；C++：clang-tidy + sanitizers
提交门禁：格式矩阵冒烟 + 单测 + 基准
代码审查：render/audio 关键路径双人 CR
11. 里程碑交付物（Deliverables）
架构实现文档（本文件 + 接口规范 + 模块边界）
最小可用播放器（v0.1）：本地文件 4K 播放 + 基本字幕 + 基础 OSD
性能基线报告（v0.3）：8K/HDR/120fps 指标与机型列表
媒体库与同步（v0.4-v0.5）：海报墙与云/服务器打通
插件生态（v0.6+）：商店上线，首批官方插件（OpenSubtitles、TMDB 刮削、FSR 着色器包、DLNA）
12. 总结
Project NovaPlayer（BovaPlayer）以“跨平台统一内核 + 现代渲染 + 智能聚合 + 开放生态”为核心策略，采用 Rust/C++ 与 FFmpeg/libplacebo/wgpu 等成熟技术，构建面向未来的超高性能、极致体验的播放器平台。通过严谨的模块化、强大的插件系统与完善的质量保障流程，我们将持续提升画质、降低延迟、拓展数据源与生态，成为用户数字影音生活的唯一入口。

如需，我可以继续输出：

更详细的接口定义（IDL/FFI 原型）
初始仓库骨架（目录与构建脚本）
v0.1 的任务分解与估算（Sprint 计划）
插件 API 初版（Lua/JS 示例）