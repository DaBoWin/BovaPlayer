# Android MPV 播放器弹幕集成指南

## 已创建的文件

1. `danmaku/DanmakuModel.kt` - 弹幕数据模型
2. `danmaku/DanmakuApiService.kt` - 弹幕 API 服务
3. `danmaku/DanmakuView.kt` - 弹幕渲染视图
4. `danmaku/DanmakuController.kt` - 弹幕控制器
5. `danmaku/MpvPlayerActivityDanmakuExtension.kt` - MPV 播放器弹幕扩展

## 需要修改 MpvPlayerActivity.kt

### 1. 添加导入（文件顶部）

```kotlin
import com.example.bova_player_flutter.danmaku.MpvPlayerActivityDanmakuExtension
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
```

### 2. 添加成员变量（在 class MpvPlayerActivity 中）

在 `private var batteryReceiver: BroadcastReceiver? = null` 后面添加：

```kotlin
// 弹幕扩展
private var danmakuExtension: MpvPlayerActivityDanmakuExtension? = null
private lateinit var danmakuBtn: TextView
```

### 3. 初始化弹幕（在 onCreate 方法中）

在 `setContentView(rootLayout)` 后面添加：

```kotlin
// 初始化弹幕
danmakuExtension = MpvPlayerActivityDanmakuExtension(this, rootLayout, title)
danmakuExtension?.initialize()
```

### 4. 添加弹幕按钮（在 buildControls 方法中）

在字幕按钮后面添加弹幕按钮。找到这段代码：

```kotlin
subtitleBtn.layoutParams = btnMarginLP
actionBtns.addView(subtitleBtn)
```

在它后面添加：

```kotlin
// 弹幕按钮
danmakuBtn = TextView(this).apply {
    text = "弹幕"
    setTextColor(0xFFFFFFFF.toInt())
    textSize = 12f
    val bg = GradientDrawable()
    bg.setColor(0x44FFFFFF.toInt())
    bg.cornerRadius = 20 * dp
    background = bg
    setPadding((10 * dp).toInt(), (4 * dp).toInt(), (10 * dp).toInt(), (4 * dp).toInt())
    setOnClickListener { 
        danmakuExtension?.toggleDanmaku()
        updateDanmakuButtonState()
    }
    setOnLongClickListener {
        showDanmakuSettingsMenu()
        true
    }
}
danmakuBtn.layoutParams = btnMarginLP
actionBtns.addView(danmakuBtn)
```

### 5. 更新播放位置（在 startPositionTimer 方法中）

在 `handler.post { ... }` 块中添加：

```kotlin
// 更新弹幕位置
danmakuExtension?.updatePosition(pos.toFloat(), isPlaying)
```

### 6. 添加弹幕设置菜单方法（在 class 中添加新方法）

```kotlin
private fun showDanmakuSettingsMenu() {
    val extension = danmakuExtension ?: return
    if (!extension.hasDanmaku()) {
        android.widget.Toast.makeText(this, "暂无弹幕", android.widget.Toast.LENGTH_SHORT).show()
        return
    }
    
    val dp = resources.displayMetrics.density
    val config = extension.getConfig()
    
    // 创建设置面板
    val overlay = FrameLayout(this)
    overlay.layoutParams = FrameLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.MATCH_PARENT
    )
    overlay.setBackgroundColor(0x88000000.toInt())
    rootLayout.addView(overlay)
    
    val panel = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        val bg = GradientDrawable()
        bg.setColor(0xEE1C1C1E.toInt())
        bg.cornerRadius = 12 * dp
        background = bg
        setPadding((20 * dp).toInt(), (20 * dp).toInt(), (20 * dp).toInt(), (20 * dp).toInt())
        layoutParams = FrameLayout.LayoutParams(
            (320 * dp).toInt(),
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { gravity = Gravity.CENTER }
    }
    
    // 标题
    val titleRow = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
    }
    
    val titleIcon = android.widget.ImageView(this).apply {
        setImageResource(R.drawable.ic_settings)
        setColorFilter(0xFFFFFFFF.toInt(), PorterDuff.Mode.SRC_IN)
        layoutParams = LinearLayout.LayoutParams((20 * dp).toInt(), (20 * dp).toInt()).apply {
            rightMargin = (8 * dp).toInt()
        }
    }
    titleRow.addView(titleIcon)
    
    val titleText = TextView(this).apply {
        text = "弹幕设置"
        setTextColor(0xFFFFFFFF.toInt())
        textSize = 18f
        typeface = Typeface.DEFAULT_BOLD
        layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
    }
    titleRow.addView(titleText)
    
    val closeBtn = TextView(this).apply {
        text = "✕"
        setTextColor(0x99FFFFFF.toInt())
        textSize = 18f
        setPadding((8 * dp).toInt(), (4 * dp).toInt(), (8 * dp).toInt(), (4 * dp).toInt())
        setOnClickListener { rootLayout.removeView(overlay) }
    }
    titleRow.addView(closeBtn)
    panel.addView(titleRow)
    
    // 分隔线
    val divider1 = View(this).apply {
        setBackgroundColor(0x33FFFFFF.toInt())
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 1).apply {
            topMargin = (16 * dp).toInt()
            bottomMargin = (16 * dp).toInt()
        }
    }
    panel.addView(divider1)
    
    // 透明度滑块
    addSliderSetting(panel, "透明度", config.opacity, 0f, 1f, dp) { value ->
        extension.setOpacity(value)
    }
    
    // 字体大小滑块
    addSliderSetting(panel, "字体大小", config.fontSize, 12f, 48f, dp) { value ->
        extension.setFontSize(value)
    }
    
    // 速度滑块
    addSliderSetting(panel, "弹幕速度", config.speed, 0.5f, 2.0f, dp) { value ->
        extension.setSpeed(value)
    }
    
    // 显示区域滑块
    addSliderSetting(panel, "显示区域", config.displayArea, 0.25f, 1.0f, dp) { value ->
        extension.setDisplayArea(value)
    }
    
    // 弹幕信息
    val infoContainer = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        val bg = GradientDrawable()
        bg.setColor(0x22FFFFFF.toInt())
        bg.cornerRadius = 8 * dp
        background = bg
        setPadding((12 * dp).toInt(), (12 * dp).toInt(), (12 * dp).toInt(), (12 * dp).toInt())
        layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { topMargin = (16 * dp).toInt() }
    }
    
    val videoTitle = TextView(this).apply {
        text = extension.getCurrentVideoTitle() ?: "未知视频"
        setTextColor(0xFFFFFFFF.toInt())
        textSize = 14f
        typeface = Typeface.DEFAULT_BOLD
    }
    infoContainer.addView(videoTitle)
    
    val danmakuCount = TextView(this).apply {
        text = "共 ${extension.getDanmakuList().size} 条弹幕"
        setTextColor(0xBBFFFFFF.toInt())
        textSize = 12f
        layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { topMargin = (4 * dp).toInt() }
    }
    infoContainer.addView(danmakuCount)
    panel.addView(infoContainer)
    
    overlay.addView(panel)
    overlay.setOnClickListener { rootLayout.removeView(overlay) }
    panel.setOnClickListener { /* 拦截 */ }
}

private fun addSliderSetting(
    parent: LinearLayout,
    label: String,
    initialValue: Float,
    min: Float,
    max: Float,
    dp: Float,
    onValueChange: (Float) -> Unit
) {
    val container = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { bottomMargin = (12 * dp).toInt() }
    }
    
    // 标签和值
    val labelRow = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
    }
    
    val labelText = TextView(this).apply {
        text = label
        setTextColor(0xFFFFFFFF.toInt())
        textSize = 14f
        layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
    }
    labelRow.addView(labelText)
    
    val valueText = TextView(this).apply {
        text = formatSliderValue(label, initialValue)
        setTextColor(0xBBFFFFFF.toInt())
        textSize = 14f
    }
    labelRow.addView(valueText)
    container.addView(labelRow)
    
    // 滑块
    val seekBar = android.widget.SeekBar(this).apply {
        max = 100
        progress = ((initialValue - min) / (max - min) * 100).toInt()
        layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { topMargin = (8 * dp).toInt() }
        
        setOnSeekBarChangeListener(object : android.widget.SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: android.widget.SeekBar?, progress: Int, fromUser: Boolean) {
                val value = min + (progress / 100f) * (max - min)
                valueText.text = formatSliderValue(label, value)
                if (fromUser) {
                    onValueChange(value)
                }
            }
            override fun onStartTrackingTouch(seekBar: android.widget.SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: android.widget.SeekBar?) {}
        })
    }
    container.addView(seekBar)
    
    parent.addView(container)
}

private fun formatSliderValue(label: String, value: Float): String {
    return when (label) {
        "透明度" -> "${(value * 100).toInt()}%"
        "字体大小" -> "${value.toInt()}"
        "弹幕速度" -> "${String.format("%.1f", value)}x"
        "显示区域" -> when {
            value >= 0.95f -> "全屏"
            value >= 0.65f -> "3/4屏"
            value >= 0.4f -> "半屏"
            else -> "1/4屏"
        }
        else -> value.toString()
    }
}

private fun updateDanmakuButtonState() {
    val extension = danmakuExtension ?: return
    val config = extension.getConfig()
    val dp = resources.displayMetrics.density
    
    val bg = danmakuBtn.background as GradientDrawable
    if (config.enabled) {
        bg.setColor(0xFF4ADE80.toInt()) // 绿色（开启）
        danmakuBtn.setTextColor(0xFF000000.toInt()) // 黑色文字
    } else {
        bg.setColor(0x44FFFFFF.toInt()) // 半透明白色（关闭）
        danmakuBtn.setTextColor(0xFFFFFFFF.toInt()) // 白色文字
    }
}
```

### 7. 清理资源（在 onDestroy 方法中）

在 `super.onDestroy()` 前面添加：

```kotlin
// 清理弹幕
danmakuExtension?.destroy()
danmakuExtension = null
```

## 完成！

完成以上修改后，Android MPV 播放器就具备了完整的弹幕功能：

- ✅ 自动加载弹幕
- ✅ 60fps 流畅渲染
- ✅ 弹幕开关按钮
- ✅ 长按打开设置面板
- ✅ 可调节透明度、字体大小、速度、显示区域
- ✅ 配置持久化保存

弹幕按钮位于字幕按钮旁边，点击切换开关，长按打开设置面板。
