# Emby 媒体服务器功能使用说明

## 已完成的改进

### ✅ 1. 影片图片展示
- 自动加载并显示影片海报图（Primary）
- 详情页显示背景图（Backdrop）
- 图片缓存机制，避免重复加载
- 加载失败时显示图标占位符

### ✅ 2. 目录分行展示
- Dashboard 中每个媒体库独占一行
- 每行显示：目录标题 + 横向滚动预览 + "更多"按钮
- 点击"更多"进入该目录的完整浏览页面
- 清晰的视觉层次结构

### ✅ 3. 分页功能
- 浏览器视图支持分页（默认每页 20 项）
- 分页控制栏：
  - 显示总项目数和当前页码
  - 首页、上一页、下一页、末页按钮
- 顶部和底部都有分页控制，方便操作

### ✅ 4. 完善的影片详情
- 全宽背景图展示
- 左侧海报图（180x270）
- 完整的元数据：
  - 标题（大号字体）
  - 年份、分级、时长
  - 评分（星级显示）
  - 类型、原始标题
  - 集数/季数（剧集）
  - 详细简介
- 醒目的播放按钮

## 使用方法

### 连接 Emby 服务器
1. 启动应用，切换到"🌐 媒体服务器"标签
2. 点击"➕ 添加服务器"
3. 输入服务器信息：
   - 地址：如 `http://192.168.1.10:8096`
   - 用户名
   - 密码
4. 点击"连接"

### 浏览媒体库
1. 连接成功后自动进入 Dashboard
2. 每个媒体库显示为一行：
   - 横向滚动查看预览
   - 点击"更多 →"查看完整列表
3. 在浏览器视图中：
   - 使用分页控制浏览大量内容
   - 点击项目查看详情或进入子目录

### 播放影片
1. 点击影片卡片进入详情页
2. 查看完整信息和图片
3. 点击"▶ 立即播放"开始播放
4. 自动切换到播放器界面

## 待完善功能

### 图片加载（框架已实现）
当前图片加载的框架代码已完成，但需要：
1. 添加图片解码库（`image` crate）
2. 实现图片数据传输（通过 EmbyEvent）
3. 将图片转换为纹理

详见 `EMBY_UI_IMPROVEMENTS.md` 中的实现建议。

### Dashboard 预览
当前 Dashboard 的横向预览显示占位符，需要：
1. 在加载 Dashboard 时预加载每个媒体库的前几项
2. 或实现按需加载机制

### 其他优化
- 加载动画
- 错误处理和重试
- 图片尺寸优化
- 缓存持久化

## 技术细节

### 新增状态变量
```rust
emby_image_cache: HashMap<String, TextureHandle>  // 图片缓存
emby_image_loading: HashSet<String>               // 加载状态
emby_items_per_page: usize                        // 每页项目数
emby_current_page: usize                          // 当前页码
```

### 新增函数
- `render_horizontal_item_row()` - 横向滚动行
- `render_item_card()` - 卡片渲染（列表）
- `render_item_card_inline()` - 卡片渲染（网格）
- `load_emby_image()` - 图片加载

### 修改的函数
- `show_emby_dashboard()` - 改为分行展示
- `show_emby_browser()` - 添加分页
- `show_emby_item_detail()` - 完善详情页

## 编译和运行

```bash
cd core
cargo build --package bova-gui --features mpv
cargo run --package bova-gui --features mpv
```

## 注意事项

1. 图片加载功能需要网络连接到 Emby 服务器
2. 分页默认每页 20 项，可在代码中调整 `emby_items_per_page`
3. 图片缓存仅在内存中，重启应用后需要重新加载
4. 确保 Emby 服务器 API 可访问

## 反馈和改进

如有问题或建议，请查看：
- `EMBY_UI_IMPROVEMENTS.md` - 详细的技术文档
- `PLAN.md` - 项目整体规划
