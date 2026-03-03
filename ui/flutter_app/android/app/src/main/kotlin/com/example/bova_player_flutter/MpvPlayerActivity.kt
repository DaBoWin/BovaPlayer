package com.example.bova_player_flutter

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ActivityInfo
import android.graphics.Color
import android.graphics.PorterDuff
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.AudioManager
import android.os.BatteryManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.AttributeSet
import android.util.Log
import android.util.Xml
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView
import `is`.xyz.mpv.BaseMPVView
import `is`.xyz.mpv.MPVLib
import `is`.xyz.mpv.MPVNode
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.Timer
import java.util.TimerTask
import kotlin.math.abs
import com.example.bova_player_flutter.danmaku.MpvPlayerActivityDanmakuExtension

/**
 * 全屏原生 MPV 播放器 Activity
 * - Infuse 风格 UI
 * - 事件驱动字幕加载（file-loaded 事件）
 */
class MpvPlayerActivity : Activity(), MPVLib.EventObserver {

    companion object {
        const val EXTRA_URL = "url"
        const val EXTRA_TITLE = "title"
        const val EXTRA_HEADERS = "headers"
        const val EXTRA_SUBTITLES = "subtitles"
        const val RESULT_POSITION = "position"
        const val RESULT_DURATION = "duration"
        private const val TAG = "MpvPlayerActivity"
    }

    private lateinit var mpvView: ActivityMPVView
    private var controlsVisible = true
    private var isPlaying = false
    private var positionTimer: Timer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var subtitles: ArrayList<HashMap<String, String>>? = null
    private var currentSubtitleIndex = -1
    private var currentSpeed = 1.0
    private var lastBufferPos = 0.0
    private var lastSpeedCheck = System.currentTimeMillis()
    private var networkSpeed = "加载中..."
    private var fileLoaded = false
    private var batteryReceiver: BroadcastReceiver? = null
    
    // 弹幕扩展
    private var danmakuExtension: MpvPlayerActivityDanmakuExtension? = null
    private lateinit var danmakuBtn: TextView

    // 手势控制
    private var gestureStartX = 0f
    private var gestureStartY = 0f
    private var gestureType = GestureType.NONE
    private var isGestureMoved = false
    private var initialBrightness = 0f
    private var initialVolume = 0
    private var initialPosition = 0.0
    private lateinit var audioManager: AudioManager
    private var maxVolume = 0

    enum class GestureType {
        NONE, BRIGHTNESS, VOLUME, SEEK
    }

    // UI 组件
    private lateinit var rootLayout: FrameLayout
    private lateinit var controlsOverlay: FrameLayout
    private lateinit var gestureIndicator: FrameLayout
    private lateinit var gestureIcon: ImageButton
    private lateinit var gestureText: TextView
    private lateinit var gestureProgress: View
    private lateinit var titleInfoText: TextView
    private lateinit var networkSpeedText: TextView
    private lateinit var currentTimeText: TextView
    private lateinit var batteryText: TextView
    private lateinit var batteryFillView: View
    private lateinit var positionText: TextView
    private lateinit var durationText: TextView
    private lateinit var seekBar: SeekBar
    private lateinit var playPauseBtn: ImageButton
    private lateinit var speedBtn: TextView
    private lateinit var subtitleBtn: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 强制横屏
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE

        // 全屏沉浸模式
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_FULLSCREEN or
            View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
            View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
            View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        )

        // 注册电池状态监听
        batteryReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                updateTopRightInfo()
            }
        }
        registerReceiver(batteryReceiver, IntentFilter(Intent.ACTION_BATTERY_CHANGED))

        // 初始化音频管理器
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)

        val url = intent.getStringExtra(EXTRA_URL) ?: run {
            Log.e("ActivityMPVView", "No URL provided")
            finish()
            return
        }
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "视频"

        @Suppress("UNCHECKED_CAST")
        subtitles = intent.getSerializableExtra(EXTRA_SUBTITLES) as? ArrayList<HashMap<String, String>>

        // ===== 创建 UI =====
        rootLayout = FrameLayout(this)
        rootLayout.setBackgroundColor(Color.BLACK)

        // MPV 视频视图
        val parser = resources.getXml(android.R.layout.simple_list_item_1)
        parser.next()
        val attrs = Xml.asAttributeSet(parser)
        mpvView = ActivityMPVView(this, attrs)
        mpvView.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        rootLayout.addView(mpvView)

        // 透明控制器覆盖层
        controlsOverlay = FrameLayout(this)
        controlsOverlay.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        rootLayout.addView(controlsOverlay)

        buildControls(title)

        // 构建手势指示器
        buildGestureIndicator()

        // 设置触摸监听器处理手势
        rootLayout.setOnTouchListener { _, event ->
            handleTouchEvent(event)
        }

        setContentView(rootLayout)

        // 初始化弹幕
        danmakuExtension = MpvPlayerActivityDanmakuExtension(this, rootLayout, title)
        danmakuExtension?.initialize()

        // 初始化 MPV
        try {
            Log.d(TAG, "Starting MPV initialization...")
            Log.d(TAG, "filesDir: ${filesDir.path}")
            Log.d(TAG, "cacheDir: ${cacheDir.path}")
            
            // 清理旧实例
            try { 
                MPVLib.destroy() 
                Log.d(TAG, "Old MPV instance destroyed")
            } catch (e: Exception) {
                Log.w(TAG, "No old MPV instance to destroy: ${e.message}")
            }
            
            // 初始化 MPV
            mpvView.initialize(filesDir.path, cacheDir.path)
            Log.d(TAG, "MPV view initialized")
            
            // 添加观察者
            MPVLib.addObserver(this)
            Log.d(TAG, "MPV observer added")
            
            // 测试 MPV 是否正常工作
            val version = MPVLib.getPropertyString("mpv-version")
            Log.d(TAG, "MPV version: $version")
            Log.d(TAG, "MPV initialized successfully")
            
        } catch (e: UnsatisfiedLinkError) {
            Log.e(TAG, "MPV native library not found", e)
            android.widget.Toast.makeText(this, "MPV 库加载失败: ${e.message}", android.widget.Toast.LENGTH_LONG).show()
            finish()
            return
        } catch (e: Exception) {
            Log.e(TAG, "MPV init failed: ${e.message}", e)
            e.printStackTrace()
            android.widget.Toast.makeText(this, "MPV 初始化失败: ${e.message}", android.widget.Toast.LENGTH_LONG).show()
            finish()
            return
        }

        // 设置 HTTP headers
        @Suppress("UNCHECKED_CAST")
        val headers = intent.getSerializableExtra(EXTRA_HEADERS) as? HashMap<String, String>
        if (headers != null && headers.isNotEmpty()) {
            val headerString = headers.entries.joinToString(",") { "${it.key}: ${it.value}" }
            try {
                MPVLib.setPropertyString("http-header-fields", headerString)
                Log.d(TAG, "HTTP headers set: $headerString")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to set HTTP headers: ${e.message}")
            }
        }

        // 加载并播放
        try {
            Log.d(TAG, "Loading video: $url")
            MPVLib.command("loadfile", url)
            MPVLib.setPropertyBoolean("pause", false)
            isPlaying = true
            Log.d(TAG, "Video load command sent")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load video: ${e.message}", e)
            android.widget.Toast.makeText(this, "视频加载失败: ${e.message}", android.widget.Toast.LENGTH_LONG).show()
            finish()
            return
        }

        startPositionTimer()
        scheduleHideControls()
    }

    // ===== MPV EventObserver =====

    override fun eventProperty(property: String) {}
    override fun eventProperty(property: String, value: Long) {}
    override fun eventProperty(property: String, value: Boolean) {}
    override fun eventProperty(property: String, value: String) {}
    override fun eventProperty(property: String, value: Double) {}
    override fun eventProperty(property: String, value: MPVNode) {}

    override fun event(eventId: Int) {
        // MPV_EVENT_FILE_LOADED = 8
        if (eventId == MPVLib.mpvEventId.MPV_EVENT_FILE_LOADED) {
            // 直接调用，不使用 handler.post
            onFileLoaded()
        }
        // MPV_EVENT_END_FILE = 7
        if (eventId == MPVLib.mpvEventId.MPV_EVENT_END_FILE) {
            Log.d("ActivityMPVView", "MPV: file ended")
        }
    }

    private fun onFileLoaded() {
        if (fileLoaded) return
        fileLoaded = true
        Log.d(TAG, "=== File Loaded Event ===")

        // 必须在主线程中调用 MPVLib 方法，避免崩溃
        runOnUiThread {
            try {
                // 启用字幕显示
                MPVLib.setPropertyString("sub-visibility", "yes")
                
                // 获取当前选中的字幕
                val currentSid = MPVLib.getPropertyInt("sid") ?: 0
                if (currentSid > 0) {
                    currentSubtitleIndex = currentSid
                    Log.d(TAG, "✓ Subtitle auto-selected: id=$currentSid")
                    
                    // 详细检测字幕信息
                    handler.postDelayed({
                        try {
                            val trackCount = MPVLib.getPropertyInt("track-list/count") ?: 0
                            for (i in 0 until trackCount) {
                                val trackType = MPVLib.getPropertyString("track-list/$i/type")
                                if (trackType == "sub") {
                                    val trackId = MPVLib.getPropertyInt("track-list/$i/id") ?: continue
                                    if (trackId == currentSid) {
                                        val codec = MPVLib.getPropertyString("track-list/$i/codec") ?: "unknown"
                                        val lang = MPVLib.getPropertyString("track-list/$i/lang") ?: "unknown"
                                        val title = MPVLib.getPropertyString("track-list/$i/title") ?: ""
                                        val isExternal = MPVLib.getPropertyString("track-list/$i/external-filename") != null
                                        
                                        Log.d(TAG, "📄 Selected Subtitle Info:")
                                        Log.d(TAG, "  - Track ID: $trackId")
                                        Log.d(TAG, "  - Codec: $codec")
                                        Log.d(TAG, "  - Language: $lang")
                                        Log.d(TAG, "  - Title: $title")
                                        Log.d(TAG, "  - External: $isExternal")
                                        
                                        // 获取当前使用的编码
                                        val currentCodepage = MPVLib.getPropertyString("sub-codepage") ?: "unknown"
                                        Log.d(TAG, "  - Current Codepage: $currentCodepage")
                                        
                                        // 获取字幕文本样本（前50个字符）
                                        handler.postDelayed({
                                            try {
                                                val subText = MPVLib.getPropertyString("sub-text") ?: ""
                                                if (subText.isNotEmpty()) {
                                                    Log.d(TAG, "  - Subtitle Sample: ${subText.take(50)}")
                                                    
                                                    // 检测是否乱码（包含大量问号或特殊字符）
                                                    val questionMarkCount = subText.count { it == '?' || it == '�' }
                                                    if (questionMarkCount > subText.length * 0.3) {
                                                        Log.w(TAG, "⚠️ Subtitle may be garbled! Question marks: $questionMarkCount/${subText.length}")
                                                        Log.w(TAG, "💡 Try switching encoding in subtitle menu")
                                                    }
                                                } else {
                                                    Log.d(TAG, "  - No subtitle text yet")
                                                }
                                            } catch (e: Exception) {
                                                Log.e(TAG, "Failed to get subtitle text: ${e.message}")
                                            }
                                        }, 1000)
                                        
                                        break
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to detect subtitle info: ${e.message}")
                        }
                    }, 500)
                } else {
                    Log.d(TAG, "No subtitle selected")
                }

                // 加载外部字幕
                if (!subtitles.isNullOrEmpty()) {
                    subtitles!!.forEachIndexed { idx, sub ->
                        val subUrl = sub["url"] ?: return@forEachIndexed
                        val subTitle = sub["title"] ?: "外部字幕 ${idx + 1}"
                        try {
                            MPVLib.command("sub-add", subUrl, "auto", subTitle)
                            Log.d(TAG, "External subtitle added: $subTitle")
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to add external subtitle: ${e.message}")
                        }
                    }
                }

            } catch (e: Exception) {
                Log.e(TAG, "onFileLoaded failed: ${e.message}", e)
            }
        }
    }

    // ===== UI Construction (Infuse Style) =====

    private fun buildControls(title: String) {
        val dp = resources.displayMetrics.density

        // --- 渐变遮罩：顶部 ---
        val topGradient = View(this).apply {
            val grad = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(0xCC000000.toInt(), 0x00000000)
            )
            background = grad
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                (120 * dp).toInt()
            ).apply { gravity = Gravity.TOP }
        }
        controlsOverlay.addView(topGradient)

        // --- 渐变遮罩：底部 ---
        val bottomGradient = View(this).apply {
            val grad = GradientDrawable(
                GradientDrawable.Orientation.BOTTOM_TOP,
                intArrayOf(0xCC000000.toInt(), 0x00000000)
            )
            background = grad
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                (180 * dp).toInt()
            ).apply { gravity = Gravity.BOTTOM }
        }
        controlsOverlay.addView(bottomGradient)

        // --- 顶部栏 ---
        val topBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding((16 * dp).toInt(), (40 * dp).toInt(), (16 * dp).toInt(), (8 * dp).toInt())
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { gravity = Gravity.TOP }
        }

        // 关闭按钮（圆形半透明背景）
        val closeBtn = makeCircleButton(
            dp = dp,
            sizeDp = 36,
            iconRes = R.drawable.ic_close,
            iconColor = 0xFFFFFFFF.toInt(),
            bgColor = 0x55000000.toInt()
        ) { finishWithResult() }
        topBar.addView(closeBtn)

        // 占位符，让右侧信息靠右
        val spacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, 1, 1f)
        }
        topBar.addView(spacer)

        // 右上角信息容器
        val topRightContainer = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        // 网速（绿色）
        networkSpeedText = TextView(this).apply {
            text = "加载中..."
            setTextColor(0xFF4ADE80.toInt()) // 绿色
            textSize = 12f
            typeface = Typeface.MONOSPACE
        }
        topRightContainer.addView(networkSpeedText)

        // 间隔
        val spacer1 = View(this).apply {
            layoutParams = LinearLayout.LayoutParams((12 * dp).toInt(), 1)
        }
        topRightContainer.addView(spacer1)

        // 当前时间（白色）
        currentTimeText = TextView(this).apply {
            text = "00:00"
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 12f
            typeface = Typeface.MONOSPACE
        }
        topRightContainer.addView(currentTimeText)

        // 间隔
        val spacer2 = View(this).apply {
            layoutParams = LinearLayout.LayoutParams((12 * dp).toInt(), 1)
        }
        topRightContainer.addView(spacer2)

        // 电池图标容器（进度条样式）
        val batteryContainer = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                (36 * dp).toInt(),
                (16 * dp).toInt()
            )
        }

        // 电池外框（白色边框，黑色背景）
        val batteryOutline = View(this).apply {
            val outlineBg = GradientDrawable()
            outlineBg.setColor(0xDD000000.toInt()) // 深色背景
            outlineBg.setStroke((1.2 * dp).toInt(), 0xCCFFFFFF.toInt()) // 白色边框
            outlineBg.cornerRadius = 2 * dp
            background = outlineBg
            layoutParams = FrameLayout.LayoutParams(
                (32 * dp).toInt(),
                (14 * dp).toInt()
            ).apply {
                gravity = Gravity.START or Gravity.CENTER_VERTICAL
            }
        }
        batteryContainer.addView(batteryOutline)

        // 电池正极（小凸起）
        val batteryTip = View(this).apply {
            val tipBg = GradientDrawable()
            tipBg.setColor(0xCCFFFFFF.toInt())
            tipBg.cornerRadius = 1 * dp
            background = tipBg
            layoutParams = FrameLayout.LayoutParams(
                (2 * dp).toInt(),
                (6 * dp).toInt()
            ).apply {
                gravity = Gravity.END or Gravity.CENTER_VERTICAL
                leftMargin = (32 * dp).toInt()
            }
        }
        batteryContainer.addView(batteryTip)

        // 电池填充进度（根据电量百分比填充）
        batteryFillView = View(this).apply {
            val fillBg = GradientDrawable()
            fillBg.setColor(0xFF4ADE80.toInt()) // 默认绿色
            fillBg.cornerRadius = 1.5f * dp
            background = fillBg
            layoutParams = FrameLayout.LayoutParams(
                (28 * dp).toInt(), // 初始宽度，会动态更新
                (10 * dp).toInt()
            ).apply {
                gravity = Gravity.START or Gravity.CENTER_VERTICAL
                leftMargin = (2 * dp).toInt()
            }
        }
        batteryContainer.addView(batteryFillView)

        // 电池百分比文字（显示在电池图标上方）
        batteryText = TextView(this).apply {
            text = "100"
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 8f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setShadowLayer(2f, 0f, 0f, 0xFF000000.toInt()) // 添加阴影增强可读性
            layoutParams = FrameLayout.LayoutParams(
                (32 * dp).toInt(),
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.START or Gravity.CENTER_VERTICAL
            }
        }
        batteryContainer.addView(batteryText)

        topRightContainer.addView(batteryContainer)
        topBar.addView(topRightContainer)

        controlsOverlay.addView(topBar)

        // --- 中间播放控制区（垂直居中） ---
        val centerControls = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { gravity = Gravity.CENTER }
        }

        // 后退 10 秒
        val rewindBtn = makeSeekButton(dp, isForward = false) {
            try {
                val pos = MPVLib.getPropertyDouble("time-pos") ?: 0.0
                MPVLib.command("seek", (pos - 10).coerceAtLeast(0.0).toString(), "absolute")
                scheduleHideControls()
            } catch (_: Exception) {}
        }
        centerControls.addView(rewindBtn)

        // 播放/暂停（居中，稍大）
        val playPauseContainer = makePlayPauseContainer(dp)
        centerControls.addView(playPauseContainer)

        // 前进 10 秒
        val forwardBtn = makeSeekButton(dp, isForward = true) {
            try {
                val pos = MPVLib.getPropertyDouble("time-pos") ?: 0.0
                val dur = MPVLib.getPropertyDouble("duration") ?: 0.0
                MPVLib.command("seek", (pos + 10).coerceAtMost(dur).toString(), "absolute")
                scheduleHideControls()
            } catch (_: Exception) {}
        }
        centerControls.addView(forwardBtn)

        controlsOverlay.addView(centerControls)

        // --- 底部区域 ---
        val bottomContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((24 * dp).toInt(), 0, (24 * dp).toInt(), (20 * dp).toInt())
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { gravity = Gravity.BOTTOM }
        }

        // 行1：左侧标题 + 右侧功能按钮
        val infoAndActionsRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = (8 * dp).toInt() }
        }

        // 左侧：标题
        titleInfoText = TextView(this).apply {
            text = title
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 14f
            typeface = Typeface.DEFAULT_BOLD
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        }
        infoAndActionsRow.addView(titleInfoText)

        // 右侧：功能按钮组
        val actionBtns = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        // 倍速按钮（文字样式）
        speedBtn = TextView(this).apply {
            text = "1.0x"
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 12f
            val bg = GradientDrawable()
            bg.setColor(0x44FFFFFF.toInt())
            bg.cornerRadius = 20 * dp
            background = bg
            setPadding((10 * dp).toInt(), (4 * dp).toInt(), (10 * dp).toInt(), (4 * dp).toInt())
            setOnClickListener { showSpeedMenu() }
        }
        actionBtns.addView(speedBtn)

        val btnMarginLP = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { leftMargin = (10 * dp).toInt() }

        // 字幕按钮 - 文字样式，与倍速按钮一致
        subtitleBtn = TextView(this).apply {
            text = "字幕"
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 12f
            val bg = GradientDrawable()
            bg.setColor(0x44FFFFFF.toInt())
            bg.cornerRadius = 20 * dp
            background = bg
            setPadding((10 * dp).toInt(), (4 * dp).toInt(), (10 * dp).toInt(), (4 * dp).toInt())
            setOnClickListener { showSubtitleMenu() }
            setOnLongClickListener {
                showEncodingMenu()
                true
            }
        }
        subtitleBtn.layoutParams = btnMarginLP
        actionBtns.addView(subtitleBtn)

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

        infoAndActionsRow.addView(actionBtns)
        bottomContainer.addView(infoAndActionsRow)

        // 行2：进度条区域
        val progressRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        positionText = TextView(this).apply {
            text = "00:00"
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 12f
            typeface = Typeface.MONOSPACE
        }
        progressRow.addView(positionText)

        seekBar = buildSeekBar(dp)
        progressRow.addView(seekBar)

        durationText = TextView(this).apply {
            text = "00:00"
            setTextColor(0x88FFFFFF.toInt())
            textSize = 12f
            typeface = Typeface.MONOSPACE
        }
        progressRow.addView(durationText)

        bottomContainer.addView(progressRow)
        controlsOverlay.addView(bottomContainer)
    }

    // ===== 手势指示器 =====

    private fun buildGestureIndicator() {
        val dp = resources.displayMetrics.density

        gestureIndicator = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { gravity = Gravity.CENTER }
            visibility = View.GONE
        }

        val indicatorContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            val bg = GradientDrawable()
            bg.setColor(0xEE1C1C1E.toInt()) // 深色背景，与菜单一致
            bg.cornerRadius = 16 * dp
            background = bg
            setPadding((24 * dp).toInt(), (20 * dp).toInt(), (24 * dp).toInt(), (20 * dp).toInt())
        }

        // 图标容器（圆形背景）
        val iconContainer = FrameLayout(this).apply {
            val bg = GradientDrawable()
            bg.shape = GradientDrawable.OVAL
            bg.setColor(0x44FFFFFF.toInt()) // 半透明白色背景
            background = bg
            val sizePx = (56 * dp).toInt()
            layoutParams = LinearLayout.LayoutParams(sizePx, sizePx)
        }

        gestureIcon = ImageButton(this).apply {
            setBackgroundColor(Color.TRANSPARENT)
            setColorFilter(0xFFFFFFFF.toInt(), PorterDuff.Mode.SRC_IN)
            scaleType = android.widget.ImageView.ScaleType.CENTER_INSIDE
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setPadding((12 * dp).toInt(), (12 * dp).toInt(), (12 * dp).toInt(), (12 * dp).toInt())
        }
        iconContainer.addView(gestureIcon)
        indicatorContainer.addView(iconContainer)

        val spacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                (12 * dp).toInt()
            )
        }
        indicatorContainer.addView(spacer)

        gestureText = TextView(this).apply {
            textSize = 18f
            setTextColor(0xFFFFFFFF.toInt())
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        indicatorContainer.addView(gestureText)

        val progressContainer = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                (140 * dp).toInt(),
                (3 * dp).toInt()
            ).apply { topMargin = (10 * dp).toInt() }
            val bg = GradientDrawable()
            bg.setColor(0x33FFFFFF.toInt())
            bg.cornerRadius = 1.5f * dp
            background = bg
        }

        gestureProgress = View(this).apply {
            val progressBg = GradientDrawable()
            progressBg.setColor(0xFF4ADE80.toInt()) // 绿色进度条
            progressBg.cornerRadius = 1.5f * dp
            background = progressBg
            layoutParams = FrameLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT)
        }
        progressContainer.addView(gestureProgress)
        indicatorContainer.addView(progressContainer)

        gestureIndicator.addView(indicatorContainer)
        rootLayout.addView(gestureIndicator)
    }

    // ===== 手势处理 =====

    private fun handleTouchEvent(event: MotionEvent): Boolean {
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                gestureStartX = event.x
                gestureStartY = event.y
                gestureType = GestureType.NONE
                isGestureMoved = false
                
                // 记录初始状态
                try {
                    initialBrightness = Settings.System.getInt(
                        contentResolver,
                        Settings.System.SCREEN_BRIGHTNESS
                    ) / 255f
                } catch (e: Exception) {
                    initialBrightness = 0.5f
                }
                initialVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                initialPosition = MPVLib.getPropertyDouble("time-pos") ?: 0.0
                
                return true
            }
            
            MotionEvent.ACTION_MOVE -> {
                val deltaX = event.x - gestureStartX
                val deltaY = event.y - gestureStartY
                
                // 判断手势类型
                if (gestureType == GestureType.NONE && (abs(deltaX) > 20 || abs(deltaY) > 20)) {
                    isGestureMoved = true
                    gestureType = if (abs(deltaX) > abs(deltaY)) {
                        GestureType.SEEK
                    } else {
                        if (gestureStartX < resources.displayMetrics.widthPixels / 2) {
                            GestureType.BRIGHTNESS
                        } else {
                            GestureType.VOLUME
                        }
                    }
                }
                
                when (gestureType) {
                    GestureType.BRIGHTNESS -> handleBrightnessGesture(deltaY)
                    GestureType.VOLUME -> handleVolumeGesture(deltaY)
                    GestureType.SEEK -> handleSeekGesture(deltaX)
                    else -> {}
                }
                
                return true
            }
            
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                // 如果没有移动，视为点击
                if (!isGestureMoved) {
                    toggleControls()
                } else {
                    // 执行手势结束操作
                    if (gestureType == GestureType.SEEK) {
                        try {
                            MPVLib.command("seek", initialPosition.toString(), "absolute")
                        } catch (_: Exception) {}
                    }
                    
                    // 隐藏指示器
                    handler.postDelayed({
                        gestureIndicator.visibility = View.GONE
                    }, 500)
                }
                
                gestureType = GestureType.NONE
                isGestureMoved = false
                return true
            }
        }
        
        return false
    }

    private fun handleBrightnessGesture(deltaY: Float) {
        val change = -deltaY / 500f
        val newBrightness = (initialBrightness + change).coerceIn(0f, 1f)
        
        // 设置屏幕亮度
        val layoutParams = window.attributes
        layoutParams.screenBrightness = newBrightness
        window.attributes = layoutParams
        
        // 更新指示器
        gestureIcon.setImageResource(R.drawable.ic_brightness)
        gestureText.text = "${(newBrightness * 100).toInt()}%"
        
        // 更新进度条
        val progressParams = gestureProgress.layoutParams as FrameLayout.LayoutParams
        progressParams.width = (140 * resources.displayMetrics.density * newBrightness).toInt()
        gestureProgress.layoutParams = progressParams
        
        // 根据亮度改变进度条颜色
        val progressBg = gestureProgress.background as GradientDrawable
        progressBg.setColor(0xFFFBBF24.toInt()) // 黄色（亮度）
        
        gestureIndicator.visibility = View.VISIBLE
    }

    private fun handleVolumeGesture(deltaY: Float) {
        val change = (-deltaY / 500f * maxVolume).toInt()
        val newVolume = (initialVolume + change).coerceIn(0, maxVolume)
        
        // 设置音量
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, newVolume, 0)
        
        // 更新指示器
        val volumePercent = (newVolume.toFloat() / maxVolume * 100).toInt()
        gestureIcon.setImageResource(
            when {
                newVolume == 0 -> R.drawable.ic_volume_mute
                volumePercent < 50 -> R.drawable.ic_volume_low
                else -> R.drawable.ic_volume_high
            }
        )
        gestureText.text = "$volumePercent%"
        
        // 更新进度条
        val progressParams = gestureProgress.layoutParams as FrameLayout.LayoutParams
        progressParams.width = (140 * resources.displayMetrics.density * newVolume / maxVolume).toInt()
        gestureProgress.layoutParams = progressParams
        
        // 根据音量改变进度条颜色
        val progressBg = gestureProgress.background as GradientDrawable
        progressBg.setColor(
            if (newVolume == 0) 0xFFEF4444.toInt() // 红色（静音）
            else 0xFF4ADE80.toInt() // 绿色（有声音）
        )
        
        gestureIndicator.visibility = View.VISIBLE
    }

    private fun handleSeekGesture(deltaX: Float) {
        try {
            val duration = MPVLib.getPropertyDouble("duration") ?: 0.0
            if (duration <= 0) return
            
            // 全屏宽度 = 180秒
            val seekChange = (deltaX / resources.displayMetrics.widthPixels) * 180
            val newPosition = (initialPosition + seekChange).coerceIn(0.0, duration)
            initialPosition = newPosition
            
            // 更新指示器
            gestureIcon.setImageResource(
                if (seekChange > 0) R.drawable.ic_forward
                else R.drawable.ic_rewind
            )
            val minutes = (newPosition / 60).toInt()
            val seconds = (newPosition % 60).toInt()
            gestureText.text = String.format("%02d:%02d", minutes, seconds)
            
            // 更新进度条
            val progressParams = gestureProgress.layoutParams as FrameLayout.LayoutParams
            progressParams.width = (140 * resources.displayMetrics.density * newPosition / duration).toInt()
            gestureProgress.layoutParams = progressParams
            
            // 进度条颜色
            val progressBg = gestureProgress.background as GradientDrawable
            progressBg.setColor(0xFF4ADE80.toInt()) // 绿色
            
            gestureIndicator.visibility = View.VISIBLE
        } catch (_: Exception) {}
    }

    /** 圆形背景按钮 */
    private fun makeCircleButton(
        dp: Float,
        sizeDp: Int,
        iconRes: Int,
        iconColor: Int,
        bgColor: Int,
        onClick: () -> Unit
    ): ImageButton {
        return ImageButton(this).apply {
            setImageResource(iconRes)
            setColorFilter(iconColor, PorterDuff.Mode.SRC_IN)
            setBackgroundColor(Color.TRANSPARENT)
            val bg = GradientDrawable()
            bg.setColor(bgColor)
            bg.shape = GradientDrawable.OVAL
            background = bg
            val sizePx = (sizeDp * dp).toInt()
            layoutParams = LinearLayout.LayoutParams(sizePx, sizePx)
            scaleType = android.widget.ImageView.ScaleType.CENTER_INSIDE
            setPadding((6 * dp).toInt(), (6 * dp).toInt(), (6 * dp).toInt(), (6 * dp).toInt())
            setOnClickListener { onClick() }
        }
    }

    /** 后退/前进 10 秒 按钮（带 "10" 标签） */
    private fun makeSeekButton(dp: Float, isForward: Boolean, onClick: () -> Unit): FrameLayout {
        val sizePx = (60 * dp).toInt()
        val container = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(sizePx, sizePx).apply {
                if (isForward) leftMargin = (40 * dp).toInt()
                else rightMargin = (40 * dp).toInt()
            }
            val bg = GradientDrawable()
            bg.setColor(0x55000000.toInt())
            bg.shape = GradientDrawable.OVAL
            background = bg
            setOnClickListener { onClick() }
        }

        val iconRes = if (isForward) R.drawable.ic_forward else R.drawable.ic_rewind
        val icon = android.widget.ImageView(this).apply {
            setImageResource(iconRes)
            setColorFilter(0xFFFFFFFF.toInt(), PorterDuff.Mode.SRC_IN)
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            scaleType = android.widget.ImageView.ScaleType.CENTER_INSIDE
            setPadding((14 * dp).toInt(), (14 * dp).toInt(), (14 * dp).toInt(), (14 * dp).toInt())
        }
        container.addView(icon)

        val label = TextView(this).apply {
            text = "10"
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 10f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER_HORIZONTAL
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { gravity = Gravity.CENTER_HORIZONTAL or Gravity.BOTTOM; bottomMargin = (8 * dp).toInt() }
        }
        container.addView(label)

        return container
    }

    /** 播放/暂停按钮（大圆形） */
    private fun makePlayPauseContainer(dp: Float): FrameLayout {
        val sizePx = (72 * dp).toInt()
        val container = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(sizePx, sizePx)
            val bg = GradientDrawable()
            bg.setColor(0x77000000.toInt())
            bg.shape = GradientDrawable.OVAL
            background = bg
        }

        playPauseBtn = ImageButton(this).apply {
            setImageResource(R.drawable.ic_pause)
            setColorFilter(0xFFFFFFFF.toInt(), PorterDuff.Mode.SRC_IN)
            setBackgroundColor(Color.TRANSPARENT)
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            scaleType = android.widget.ImageView.ScaleType.CENTER_INSIDE
            setPadding((16 * dp).toInt(), (16 * dp).toInt(), (16 * dp).toInt(), (16 * dp).toInt())
            setOnClickListener { togglePlayPause() }
        }
        container.addView(playPauseBtn)
        return container
    }

    /** 进度条 */
    private fun buildSeekBar(dp: Float): SeekBar {
        return SeekBar(this).apply {
            max = 1000
            progress = 0
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                leftMargin = (10 * dp).toInt()
                rightMargin = (10 * dp).toInt()
            }

            // 超薄进度条 (2dp height)
            val trackHeight = (2 * dp).toInt()
            minHeight = trackHeight
            maxHeight = trackHeight

            // 背景轨道 (半透明白)
            val bgDrawable = GradientDrawable()
            bgDrawable.setColor(0x44FFFFFF.toInt())
            bgDrawable.cornerRadius = 1 * dp
            bgDrawable.setSize(0, trackHeight)

            // 已播进度 (纯白)
            val progressFill = GradientDrawable()
            progressFill.setColor(0xFFFFFFFF.toInt())
            progressFill.cornerRadius = 1 * dp
            progressFill.setSize(0, trackHeight)

            val layerDrawable = android.graphics.drawable.LayerDrawable(arrayOf(
                android.graphics.drawable.ClipDrawable(bgDrawable, Gravity.LEFT, android.graphics.drawable.ClipDrawable.HORIZONTAL),
                android.graphics.drawable.ClipDrawable(progressFill, Gravity.LEFT, android.graphics.drawable.ClipDrawable.HORIZONTAL)
            ))
            layerDrawable.setId(0, android.R.id.background)
            layerDrawable.setId(1, android.R.id.progress)
            progressDrawable = layerDrawable

            // Thumb：小白色圆点 (10dp)
            val thumbShape = GradientDrawable()
            thumbShape.shape = GradientDrawable.OVAL
            thumbShape.setColor(0xFFFFFFFF.toInt())
            val thumbSizePx = (10 * dp).toInt()
            thumbShape.setSize(thumbSizePx, thumbSizePx)
            thumb = thumbShape
            thumbOffset = thumbSizePx / 2
            splitTrack = false

            setPadding((6 * dp).toInt(), 0, (6 * dp).toInt(), 0)

            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(bar: SeekBar?, progress: Int, fromUser: Boolean) {
                    if (fromUser) {
                        try {
                            val duration = MPVLib.getPropertyDouble("duration") ?: 0.0
                            val seekPos = (progress / 1000.0) * duration
                            MPVLib.command("seek", seekPos.toString(), "absolute")
                        } catch (_: Exception) {}
                    }
                }
                override fun onStartTrackingTouch(bar: SeekBar?) {}
                override fun onStopTrackingTouch(bar: SeekBar?) { scheduleHideControls() }
            })
        }
    }

    // ===== Playback Control =====

    private fun togglePlayPause() {
        try {
            isPlaying = !isPlaying
            MPVLib.setPropertyBoolean("pause", !isPlaying)
            playPauseBtn.setImageResource(
                if (isPlaying) R.drawable.ic_pause
                else R.drawable.ic_play
            )
            scheduleHideControls()
        } catch (_: Exception) {}
    }

    private fun toggleControls() {
        if (controlsVisible) {
            controlsOverlay.animate().alpha(0f).setDuration(250).withEndAction {
                controlsOverlay.visibility = View.GONE
                controlsOverlay.alpha = 1f
            }.start()
        } else {
            controlsOverlay.alpha = 0f
            controlsOverlay.visibility = View.VISIBLE
            controlsOverlay.animate().alpha(1f).setDuration(250).start()
            scheduleHideControls()
        }
        controlsVisible = !controlsVisible
    }

    private var hideControlsRunnable: Runnable? = null

    private fun scheduleHideControls() {
        hideControlsRunnable?.let { handler.removeCallbacks(it) }
        hideControlsRunnable = Runnable {
            if (isPlaying && controlsVisible) {
                controlsOverlay.animate().alpha(0f).setDuration(250).withEndAction {
                    controlsOverlay.visibility = View.GONE
                    controlsOverlay.alpha = 1f
                }.start()
                controlsVisible = false
            }
        }
        handler.postDelayed(hideControlsRunnable!!, 4000)
    }

    // ===== Position Timer =====

    private fun startPositionTimer() {
        positionTimer?.cancel()
        positionTimer = Timer()
        positionTimer?.schedule(object : TimerTask() {
            override fun run() {
                try {
                    val pos = MPVLib.getPropertyDouble("time-pos") ?: 0.0
                    val dur = MPVLib.getPropertyDouble("duration") ?: 0.0
                    updateNetworkSpeed(pos)
                    handler.post {
                        positionText.text = formatTime(pos)
                        durationText.text = formatTime(dur)
                        if (dur > 0) seekBar.progress = ((pos / dur) * 1000).toInt()
                        updateTopRightInfo()
                        // 更新弹幕位置
                        danmakuExtension?.updatePosition(pos.toFloat(), isPlaying)
                    }
                } catch (_: Exception) {}
            }
        }, 0, 500)
    }

    private fun updateTopRightInfo() {
        try {
            val dp = resources.displayMetrics.density
            
            // 更新网速（绿色）
            networkSpeedText.text = networkSpeed
            
            // 更新当前时间（白色）
            val currentTime = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
            currentTimeText.text = currentTime
            
            // 更新电池电量
            val batteryStatus = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val level = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            val batteryPct = if (level >= 0 && scale > 0) {
                ((level / scale.toFloat()) * 100).toInt()
            } else {
                100
            }
            
            // 更新电池百分比文字
            batteryText.text = batteryPct.toString()
            
            // 根据电量改变填充颜色和宽度
            val batteryColor = when {
                batteryPct <= 20 -> 0xFFEF4444.toInt() // 红色
                batteryPct <= 50 -> 0xFFFBBF24.toInt() // 黄色
                else -> 0xFF4ADE80.toInt() // 绿色
            }
            
            // 更新填充条的颜色
            val fillBg = batteryFillView.background as GradientDrawable
            fillBg.setColor(batteryColor)
            
            // 更新填充条的宽度（根据电量百分比）
            val maxFillWidth = (28 * dp).toInt() // 最大填充宽度
            val fillWidth = (maxFillWidth * batteryPct / 100f).toInt().coerceAtLeast((2 * dp).toInt())
            val fillParams = batteryFillView.layoutParams as FrameLayout.LayoutParams
            fillParams.width = fillWidth
            batteryFillView.layoutParams = fillParams
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update top right info: ${e.message}")
        }
    }

    private fun updateNetworkSpeed(currentPos: Double) {
        try {
            // 如果视频还没开始播放，显示"加载中..."
            if (currentPos < 0.1 && !fileLoaded) {
                networkSpeed = "加载中..."
                return
            }
            
            val now = System.currentTimeMillis()
            val timeDiff = (now - lastSpeedCheck) / 1000.0
            if (timeDiff >= 1.0) {
                val cacheEnd = MPVLib.getPropertyDouble("demuxer-cache-time") ?: 0.0
                val bufferDiff = cacheEnd - lastBufferPos
                networkSpeed = if (bufferDiff > 0) {
                    val estimatedBitrate = 8000.0
                    val downloadedBytes = (bufferDiff * estimatedBitrate * 1000) / 8
                    formatSpeed(downloadedBytes / timeDiff)
                } else "0 KB/s"
                lastBufferPos = cacheEnd
                lastSpeedCheck = now
            }
        } catch (_: Exception) {
            networkSpeed = "-- KB/s"
        }
    }

    private fun formatSpeed(bytesPerSecond: Double): String = when {
        bytesPerSecond < 1024 -> "${bytesPerSecond.toInt()} B/s"
        bytesPerSecond < 1024 * 1024 -> "${String.format("%.1f", bytesPerSecond / 1024)} KB/s"
        else -> "${String.format("%.2f", bytesPerSecond / (1024 * 1024))} MB/s"
    }

    // ===== Menus =====

    private fun showSubtitleMenu() {
        try {
            val trackCount = MPVLib.getPropertyInt("track-list/count") ?: 0
            val subtitleTracks = mutableListOf<Pair<Int, String>>()

            for (i in 0 until trackCount) {
                val trackType = MPVLib.getPropertyString("track-list/$i/type")
                if (trackType == "sub") {
                    val trackId = MPVLib.getPropertyInt("track-list/$i/id") ?: continue
                    val trackTitle = MPVLib.getPropertyString("track-list/$i/title") ?: ""
                    val trackLang = MPVLib.getPropertyString("track-list/$i/lang") ?: ""
                    val isExternal = MPVLib.getPropertyString("track-list/$i/external-filename") != null

                    val displayName = when {
                        trackTitle.isNotEmpty() -> if (isExternal) "[外] $trackTitle" else trackTitle
                        trackLang.isNotEmpty() -> "字幕 ($trackLang)"
                        else -> "字幕 $trackId"
                    }
                    subtitleTracks.add(Pair(trackId, displayName))
                }
            }

            val allSubtitles = listOf(Pair(0, "关闭")) + subtitleTracks
            val currentSid = MPVLib.getPropertyInt("sid") ?: 0
            val currentIndex = allSubtitles.indexOfFirst { it.first == currentSid }.coerceAtLeast(0)

            showDarkBottomSheet("字幕", allSubtitles, currentIndex) { selected ->
                try {
                    MPVLib.setPropertyInt("sid", selected.first)
                    if (selected.first == 0) {
                        MPVLib.setPropertyString("sub-visibility", "no")
                    } else {
                        MPVLib.setPropertyString("sub-visibility", "yes")
                        currentSubtitleIndex = selected.first
                    }
                } catch (e: Exception) {
                    Log.e("ActivityMPVView", "Subtitle switch failed: ${e.message}")
                }
            }
        } catch (e: Exception) {
            Log.e("ActivityMPVView", "showSubtitleMenu failed: ${e.message}")
        }
    }

    private fun showSpeedMenu() {
        val speeds = arrayOf("0.5x", "0.75x", "1.0x", "1.25x", "1.5x", "2.0x")
        val speedValues = arrayOf(0.5, 0.75, 1.0, 1.25, 1.5, 2.0)
        val currentIndex = speedValues.indexOf(currentSpeed)
        val items = speedValues.mapIndexed { i, v -> Pair(i, speeds[i]) }

        showDarkBottomSheet("倍速", items, currentIndex) { selected ->
            try {
                currentSpeed = speedValues[selected.first]
                MPVLib.setPropertyDouble("speed", currentSpeed)
                speedBtn.text = speeds[selected.first]
            } catch (e: Exception) {
                Log.e("ActivityMPVView", "Speed change failed: ${e.message}")
            }
        }
    }
    
    private fun showEncodingMenu() {
        val encodings = listOf(
            Pair("auto", "自动检测"),
            Pair("utf8", "UTF-8"),
            Pair("utf8:utf8-broken", "UTF-8 (修复损坏)"),
            Pair("enca:zh:utf8", "中文自动检测"),
            Pair("+cp936", "GBK/GB2312 (简体)"),
            Pair("+big5", "Big5 (繁体)"),
            Pair("+gbk", "GBK"),
            Pair("+gb18030", "GB18030"),
            Pair("latin1", "Latin-1"),
            Pair("iso-8859-1", "ISO-8859-1")
        )
        
        val currentCodepage = try {
            MPVLib.getPropertyString("sub-codepage") ?: "auto"
        } catch (_: Exception) {
            "auto"
        }
        val currentIndex = encodings.indexOfFirst { it.first == currentCodepage }.coerceAtLeast(0)
        
        showDarkBottomSheet("字幕编码", encodings, currentIndex) { selected ->
            try {
                Log.d("ActivityMPVView", "🔄 Changing subtitle encoding to: ${selected.first}")
                MPVLib.setPropertyString("sub-codepage", selected.first)
                
                // 重新加载字幕以应用新编码
                val currentSid = MPVLib.getPropertyInt("sid") ?: 0
                if (currentSid > 0) {
                    MPVLib.command("sub-reload")
                    Log.d("ActivityMPVView", "✓ Subtitle reloaded with encoding: ${selected.first}")
                    
                    // 延迟检查字幕文本
                    handler.postDelayed({
                        val subText = MPVLib.getPropertyString("sub-text") ?: ""
                        Log.d("ActivityMPVView", "📄 New subtitle text: ${subText.take(50)}")
                    }, 500)
                }
            } catch (e: Exception) {
                Log.e("ActivityMPVView", "❌ Encoding change failed: ${e.message}")
            }
        }
    }

    /** 通用暗色底部弹出选择菜单 */
    private fun <T> showDarkBottomSheet(
        title: String,
        items: List<Pair<T, String>>,
        selectedIndex: Int,
        onSelect: (Pair<T, String>) -> Unit
    ) {
        val dp = resources.displayMetrics.density

        // 全屏半透明遮罩
        val overlay = FrameLayout(this)
        overlay.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        overlay.setBackgroundColor(0x88000000.toInt())
        rootLayout.addView(overlay)

        // 底部面板
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val bg = GradientDrawable()
            bg.setColor(0xEE1C1C1E.toInt())
            bg.cornerRadii = floatArrayOf(16*dp, 16*dp, 16*dp, 16*dp, 0f, 0f, 0f, 0f)
            background = bg
            setPadding(0, (12 * dp).toInt(), 0, (24 * dp).toInt())
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { gravity = Gravity.BOTTOM }
        }

        // 标题行
        val titleRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding((20 * dp).toInt(), (8 * dp).toInt(), (20 * dp).toInt(), (12 * dp).toInt())
        }
        val titleTv = TextView(this).apply {
            text = title
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        }
        titleRow.addView(titleTv)

        val closeMenuBtn = TextView(this).apply {
            text = "✕"
            setTextColor(0x99FFFFFF.toInt())
            textSize = 18f
            setPadding((8 * dp).toInt(), (4 * dp).toInt(), (8 * dp).toInt(), (4 * dp).toInt())
            setOnClickListener { rootLayout.removeView(overlay) }
        }
        titleRow.addView(closeMenuBtn)
        panel.addView(titleRow)

        // 分割线
        val divider = View(this).apply {
            setBackgroundColor(0x33FFFFFF.toInt())
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 1)
        }
        panel.addView(divider)

        // 滚动列表
        val scrollView = android.widget.ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                // 最多占屏幕 60% 高度
                val maxH = (resources.displayMetrics.heightPixels * 0.6).toInt()
                height = ViewGroup.LayoutParams.WRAP_CONTENT
            }
            isVerticalScrollBarEnabled = true
        }

        val listContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, (4 * dp).toInt(), 0, 0)
        }

        items.forEachIndexed { idx, item ->
            val isSelected = idx == selectedIndex
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding((20 * dp).toInt(), (14 * dp).toInt(), (20 * dp).toInt(), (14 * dp).toInt())
                if (isSelected) {
                    setBackgroundColor(0x22FFFFFF.toInt())
                }
                isClickable = true
                isFocusable = true
                setOnClickListener {
                    onSelect(item)
                    rootLayout.removeView(overlay)
                }
            }

            // 选中指示圆点
            if (isSelected) {
                val dot = View(this).apply {
                    val dotBg = GradientDrawable()
                    dotBg.shape = GradientDrawable.OVAL
                    dotBg.setColor(0xFF4ADE80.toInt())
                    background = dotBg
                    layoutParams = LinearLayout.LayoutParams((8 * dp).toInt(), (8 * dp).toInt()).apply {
                        rightMargin = (12 * dp).toInt()
                    }
                }
                row.addView(dot)
            } else {
                val spacer = View(this).apply {
                    layoutParams = LinearLayout.LayoutParams((20 * dp).toInt(), 1)
                }
                row.addView(spacer)
            }

            val itemText = TextView(this).apply {
                text = item.second
                setTextColor(if (isSelected) 0xFFFFFFFF.toInt() else 0xBBFFFFFF.toInt())
                textSize = 14f
                if (isSelected) typeface = Typeface.DEFAULT_BOLD
            }
            row.addView(itemText)
            listContainer.addView(row)
        }

        scrollView.addView(listContainer)
        panel.addView(scrollView)
        overlay.addView(panel)

        // 点击遮罩关闭
        overlay.setOnClickListener { rootLayout.removeView(overlay) }
        panel.setOnClickListener { /* 拦截，不关闭 */ }
    }

    // ===== Helpers =====

    private fun formatTime(seconds: Double): String {
        val totalSec = seconds.toInt()
        val h = totalSec / 3600
        val m = (totalSec % 3600) / 60
        val s = totalSec % 60
        return if (h > 0) String.format("%02d:%02d:%02d", h, m, s)
        else String.format("%02d:%02d", m, s)
    }
    
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
        
        val titleText = TextView(this).apply {
            text = "⚙️ 弹幕设置"
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
            text = "共 ${danmakuExtension?.getDanmakuList()?.size ?: 0} 条弹幕"
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
        val seekBar = android.widget.SeekBar(this@MpvPlayerActivity).apply {
            this.max = 100
            this.progress = ((initialValue - min) / (max - min) * 100).toInt()
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = (8 * dp).toInt() }
            
            setOnSeekBarChangeListener(object : android.widget.SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(seekBar: android.widget.SeekBar?, progressValue: Int, fromUser: Boolean) {
                    val newValue = min + (progressValue / 100f) * (max - min)
                    valueText.text = formatSliderValue(label, newValue)
                    if (fromUser) {
                        onValueChange(newValue)
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
        
        val bg = danmakuBtn.background as GradientDrawable
        if (config.enabled) {
            bg.setColor(0xFF4ADE80.toInt()) // 绿色（开启）
            danmakuBtn.setTextColor(0xFF000000.toInt()) // 黑色文字
        } else {
            bg.setColor(0x44FFFFFF.toInt()) // 半透明白色（关闭）
            danmakuBtn.setTextColor(0xFFFFFFFF.toInt()) // 白色文字
        }
    }

    private fun finishWithResult() {
        try {
            val pos = MPVLib.getPropertyDouble("time-pos") ?: 0.0
            val dur = MPVLib.getPropertyDouble("duration") ?: 0.0
            val result = Intent().apply {
                putExtra(RESULT_POSITION, (pos * 1000).toLong())
                putExtra(RESULT_DURATION, (dur * 1000).toLong())
            }
            setResult(RESULT_OK, result)
        } catch (_: Exception) {
            setResult(RESULT_CANCELED)
        }
        finish()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() = finishWithResult()

    override fun onDestroy() {
        positionTimer?.cancel()
        positionTimer = null
        hideControlsRunnable?.let { handler.removeCallbacks(it) }
        
        // 注销电池监听
        batteryReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to unregister battery receiver: ${e.message}")
            }
        }
        
        // 清理弹幕
        danmakuExtension?.destroy()
        danmakuExtension = null
        
        try {
            MPVLib.removeObserver(this)
            MPVLib.setPropertyBoolean("pause", true)
            MPVLib.command("stop")
            Thread.sleep(100)
            MPVLib.destroy()
            Log.d("ActivityMPVView", "MPV destroyed")
        } catch (e: Exception) {
            Log.e("ActivityMPVView", "MPV cleanup error: ${e.message}")
        }
        super.onDestroy()
    }
}

/**
 * MPV View for standalone Activity
 */
class ActivityMPVView(context: Context, attributes: AttributeSet) : BaseMPVView(context, attributes) {

    override fun initOptions() {
        // 视频渲染
        MPVLib.setOptionString("vo", "gpu")
        MPVLib.setOptionString("gpu-context", "android")
        MPVLib.setOptionString("opengl-es", "yes")
        MPVLib.setOptionString("hwdec", "mediacodec-copy")
        MPVLib.setOptionString("hwdec-codecs", "all")

        // 音频配置
        MPVLib.setOptionString("ao", "audiotrack,opensles")
        MPVLib.setOptionString("audio-channels", "auto")
        MPVLib.setOptionString("audio-samplerate", "48000")
        MPVLib.setOptionString("audio-buffer", "1.0")
        MPVLib.setOptionString("volume", "100")
        MPVLib.setOptionString("volume-max", "100")

        // 字幕基础配置
        MPVLib.setOptionString("sub-visibility", "yes")
        MPVLib.setOptionString("sub-auto", "all")
        
        // 字符编码 - 优先中文编码检测
        MPVLib.setOptionString("sub-codepage", "enca:zh:utf8")
        MPVLib.setOptionString("sub-fallback", "utf8")
        
        // 字幕样式 - 使用 Android 系统中文字体
        // Noto Sans CJK 是 Android 系统自带的中文字体
        MPVLib.setOptionString("sub-font", "Noto Sans CJK SC")
        MPVLib.setOptionString("sub-fonts-dir", "/system/fonts")
        MPVLib.setOptionString("sub-font-size", "52")
        MPVLib.setOptionString("sub-color", "#FFFFFFFF")
        MPVLib.setOptionString("sub-border-color", "#FF000000")
        MPVLib.setOptionString("sub-border-size", "3.2")
        MPVLib.setOptionString("sub-shadow-offset", "2")
        MPVLib.setOptionString("sub-shadow-color", "#80000000")
        MPVLib.setOptionString("sub-spacing", "0.5")
        MPVLib.setOptionString("sub-scale", "1.0")

        // SRT/SUBRIP 字幕特殊配置
        MPVLib.setOptionString("sub-ass", "yes")
        MPVLib.setOptionString("sub-ass-override", "scale")
        MPVLib.setOptionString("sub-fix-timing", "yes")
        MPVLib.setOptionString("sub-forced-only", "no")
        MPVLib.setOptionString("embeddedfonts", "no")
        MPVLib.setOptionString("sub-clear-on-seek", "no")

        // 网络配置
        MPVLib.setOptionString("tls-verify", "no")
        MPVLib.setOptionString("network-timeout", "120")
        MPVLib.setOptionString("http-header-fields", "")

        // 缓存配置
        MPVLib.setOptionString("cache", "yes")
        MPVLib.setOptionString("cache-secs", "30")
        MPVLib.setOptionString("demuxer-max-bytes", "150M")
        MPVLib.setOptionString("demuxer-max-back-bytes", "50M")
        MPVLib.setOptionString("stream-buffer-size", "8M")
        MPVLib.setOptionString("demuxer-readahead-secs", "10")

        // 性能
        MPVLib.setOptionString("vd-lavc-threads", "4")
        MPVLib.setOptionString("ad-lavc-threads", "2")

        MPVLib.setOptionString("msg-level", "all=info")
    }

    override fun postInitOptions() {
        // 字幕选择由 MpvPlayerActivity 的 EventObserver (file-loaded) 负责
        android.util.Log.d("ActivityMPVView", "postInitOptions called")
    }

    override fun observeProperties() {}
}
