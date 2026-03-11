# BovaPlayer UI 设计系统 - 快速开始

## 5 分钟快速上手

### 1. 导入设计系统

```dart
// 在你的页面顶部导入
import 'package:bova_player_flutter/core/theme/design_system.dart';
import 'package:bova_player_flutter/core/theme/app_theme.dart';
import 'package:bova_player_flutter/core/widgets/bova_button.dart';
import 'package:bova_player_flutter/core/widgets/bova_card.dart';
import 'package:bova_player_flutter/core/widgets/bova_text_field.dart';
```

### 2. 应用主题

在 `main.dart` 中：

```dart
MaterialApp(
  title: 'BovaPlayer',
  theme: AppTheme.lightTheme,  // 浅色主题
  darkTheme: AppTheme.darkTheme,  // 深色主题（播放器用）
  // ...
)
```

### 3. 使用组件

#### 按钮
```dart
// 主要按钮
BovaButton(
  text: '登录',
  onPressed: () {
    // 处理点击
  },
)

// 次要按钮
BovaButton(
  text: '取消',
  style: BovaButtonStyle.secondary,
  onPressed: () {},
)

// 带图标的按钮
BovaButton(
  text: '添加',
  icon: Icons.add,
  onPressed: () {},
)

// 加载状态
BovaButton(
  text: '提交中',
  isLoading: true,
  onPressed: null,
)
```

#### 输入框
```dart
BovaTextField(
  label: '邮箱',
  hint: '请输入邮箱地址',
  prefixIcon: Icons.email,
  controller: _emailController,
)
```

#### 卡片
```dart
BovaCard(
  onTap: () {
    // 处理点击
  },
  child: Column(
    children: [
      Text('标题'),
      Text('内容'),
    ],
  ),
)
```

#### 媒体卡片
```dart
BovaMediaCard(
  imageUrl: 'https://...',
  title: '电影标题',
  subtitle: '2024 · 动作',
  onTap: () {
    // 打开详情
  },
)
```

### 4. 使用颜色

```dart
Container(
  color: DesignSystem.neutral50,  // 背景色
  child: Text(
    'Hello',
    style: TextStyle(
      color: DesignSystem.neutral900,  // 文字颜色
      fontSize: DesignSystem.textBase,  // 字体大小
      fontWeight: DesignSystem.weightSemibold,  // 字重
    ),
  ),
)
```

### 5. 使用间距

```dart
Padding(
  padding: EdgeInsets.all(DesignSystem.space4),  // 16px
  child: Column(
    children: [
      Text('标题'),
      SizedBox(height: DesignSystem.space2),  // 8px
      Text('内容'),
    ],
  ),
)
```

### 6. 响应式布局

```dart
// 判断设备类型
if (DesignSystem.isMobile(context)) {
  // 移动端布局
  return SingleColumnLayout();
} else if (DesignSystem.isTablet(context)) {
  // 平板布局
  return TwoColumnLayout();
} else {
  // 桌面端布局
  return MultiColumnLayout();
}

// 响应式网格
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: DesignSystem.isMobile(context) ? 2 : 4,
    childAspectRatio: 0.7,
    crossAxisSpacing: DesignSystem.space3,
    mainAxisSpacing: DesignSystem.space3,
  ),
  itemBuilder: (context, index) {
    return BovaMediaCard(...);
  },
)
```

---

## 常用代码片段

### 页面结构
```dart
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignSystem.neutral50,
      appBar: AppBar(
        title: Text('页面标题'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            DesignSystem.isMobile(context) 
                ? DesignSystem.space4 
                : DesignSystem.space6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 页面内容
            ],
          ),
        ),
      ),
    );
  }
}
```

### 表单页面
```dart
Form(
  key: _formKey,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      BovaTextField(
        label: '用户名',
        hint: '请输入用户名',
        prefixIcon: Icons.person,
        controller: _usernameController,
      ),
      SizedBox(height: DesignSystem.space4),
      BovaTextField(
        label: '密码',
        hint: '请输入密码',
        prefixIcon: Icons.lock,
        obscureText: true,
        controller: _passwordController,
      ),
      SizedBox(height: DesignSystem.space6),
      BovaButton(
        text: '提交',
        onPressed: _handleSubmit,
        isFullWidth: true,
      ),
    ],
  ),
)
```

### 列表页面
```dart
ListView.separated(
  itemCount: items.length,
  separatorBuilder: (context, index) => Divider(
    color: DesignSystem.neutral200,
    height: 1,
  ),
  itemBuilder: (context, index) {
    return BovaCard(
      onTap: () {
        // 处理点击
      },
      child: ListTile(
        title: Text(items[index].title),
        subtitle: Text(items[index].subtitle),
      ),
    );
  },
)
```

### 网格页面
```dart
GridView.builder(
  padding: EdgeInsets.all(DesignSystem.space4),
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: DesignSystem.isMobile(context) ? 2 : 4,
    childAspectRatio: 0.7,
    crossAxisSpacing: DesignSystem.space3,
    mainAxisSpacing: DesignSystem.space3,
  ),
  itemCount: items.length,
  itemBuilder: (context, index) {
    return BovaMediaCard(
      imageUrl: items[index].imageUrl,
      title: items[index].title,
      subtitle: items[index].subtitle,
      onTap: () {
        // 打开详情
      },
    );
  },
)
```

---

## 迁移现有页面

### 步骤 1：更新导入
```dart
// 添加新的导入
import 'package:bova_player_flutter/core/theme/design_system.dart';
import 'package:bova_player_flutter/core/widgets/bova_button.dart';
// ...
```

### 步骤 2：替换颜色
```dart
// 旧代码
Container(
  color: Color(0xFFF5F5F5),
  child: Text(
    'Hello',
    style: TextStyle(color: Color(0xFF1F2937)),
  ),
)

// 新代码
Container(
  color: DesignSystem.neutral50,
  child: Text(
    'Hello',
    style: TextStyle(color: DesignSystem.neutral900),
  ),
)
```

### 步骤 3：替换组件
```dart
// 旧代码
ElevatedButton(
  onPressed: () {},
  child: Text('按钮'),
)

// 新代码
BovaButton(
  text: '按钮',
  onPressed: () {},
)
```

### 步骤 4：添加响应式
```dart
// 旧代码
Padding(
  padding: EdgeInsets.all(16),
  child: ...,
)

// 新代码
Padding(
  padding: EdgeInsets.all(
    DesignSystem.isMobile(context) 
        ? DesignSystem.space4 
        : DesignSystem.space6,
  ),
  child: ...,
)
```

---

## 常见问题

### Q: 如何自定义按钮颜色？
A: 目前按钮使用设计系统的颜色。如果需要特殊颜色，可以使用 Container + GestureDetector 自定义。

### Q: 如何添加新的颜色？
A: 在 `design_system.dart` 中添加新的颜色常量，保持命名规范。

### Q: 如何处理深色模式？
A: 播放器页面使用 `AppTheme.darkTheme`，其他页面使用 `AppTheme.lightTheme`。

### Q: 如何优化性能？
A: 
1. 使用 `const` 构造函数
2. 避免在 `build` 中创建新对象
3. 使用 `ListView.builder` 而不是 `ListView`
4. 只动画 `transform` 和 `opacity`

---

## 下一步

1. 查看 `UI_DESIGN_SYSTEM.md` 了解完整的设计系统
2. 查看 `MOBILE_ADAPTATION_GUIDE.md` 了解移动端适配
3. 查看 `login_page_redesign.dart` 了解完整示例
4. 开始重构你的第一个页面！

---

## 获取帮助

- 查看设计系统文档：`UI_DESIGN_SYSTEM.md`
- 查看实施计划：`UI_REDESIGN_IMPLEMENTATION_PLAN.md`
- 查看示例代码：`login_page_redesign.dart`
- 参考现有组件：`lib/core/widgets/`

---

**记住**：保持一致性是关键。所有新代码都应该使用设计系统中定义的颜色、间距、圆角等。
