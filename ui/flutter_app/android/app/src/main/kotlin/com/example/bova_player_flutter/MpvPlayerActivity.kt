package com.example.bova_player_flutter

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PorterDuff
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.util.Log
import android.util.Xml
import android.view.Gravity
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
import java.util.Timer
import java.util.TimerTask

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
    private var networkSpeed = "-- KB/s"
    private var fileLoaded = false

    // UI 组件
    private lateinit var rootLayout: FrameLayout
    private lateinit var controlsOverlay: FrameLayout
    private lateinit var titleInfoText: TextView
    private lateinit var networkSpeedInfo: TextView
    private lateinit var positionText: TextView
    private lateinit var durationText: TextView
    private lateinit var seekBar: SeekBar
    private lateinit var playPauseBtn: ImageButton
    private lateinit var speedBtn: TextView
    private lateinit var subtitleBtn: ImageButton

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

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

        // 点击切换控制器
        rootLayout.setOnClickListener { toggleControls() }

        setContentView(rootLayout)

        // 初始化 MPV
        try {
            try { MPVLib.destroy() } catch (_: Exception) {}
            mpvView.initialize(filesDir.path, cacheDir.path)
            MPVLib.addObserver(this)
            Log.d("ActivityMPVView", "MPV initialized")
        } catch (e: Exception) {
            Log.e("ActivityMPVView", "MPV init failed: ${e.message}", e)
            finish()
            return
        }

        // 设置 HTTP headers
        @Suppress("UNCHECKED_CAST")
        val headers = intent.getSerializableExtra(EXTRA_HEADERS) as? HashMap<String, String>
        if (headers != null && headers.isNotEmpty()) {
            val headerString = headers.entries.joinToString(",") { "${it.key}: ${it.value}" }
            MPVLib.setPropertyString("http-header-fields", headerString)
        }

        // 加载并播放
        MPVLib.command("loadfile", url)
        MPVLib.setPropertyBoolean("pause", false)
        isPlaying = true

        Log.d("ActivityMPVView", "Video loading: $url")

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
            handler.post { onFileLoaded() }
        }
        // MPV_EVENT_END_FILE = 7
        if (eventId == MPVLib.mpvEventId.MPV_EVENT_END_FILE) {
            Log.d("ActivityMPVView", "MPV: file ended")
        }
    }

    private fun onFileLoaded() {
        if (fileLoaded) return
        fileLoaded = true
        Log.d("ActivityMPVView", "=== File Loaded Event: starting subtitle selection ===")

        try {
            MPVLib.setPropertyString("sub-visibility", "yes")
            val trackCount = MPVLib.getPropertyInt("track-list/count") ?: 0
            Log.d("ActivityMPVView", "Total tracks: $trackCount")

            var subtitleFound = false

            // 优先选择中文字幕
            for (i in 0 until trackCount) {
                val trackType = MPVLib.getPropertyString("track-list/$i/type")
                if (trackType == "sub") {
                    val trackId = MPVLib.getPropertyInt("track-list/$i/id") ?: continue
                    val trackLang = MPVLib.getPropertyString("track-list/$i/lang") ?: ""
                    val trackTitle = MPVLib.getPropertyString("track-list/$i/title") ?: ""

                    Log.d("ActivityMPVView", "Subtitle track #$i: id=$trackId, lang=$trackLang, title=$trackTitle")

                    if (trackLang.contains("zh") || trackLang.contains("chi") ||
                        trackTitle.contains("中文", ignoreCase = true) ||
                        trackTitle.contains("简体", ignoreCase = true) ||
                        trackTitle.contains("繁体", ignoreCase = true) ||
                        trackTitle.contains("Chinese", ignoreCase = true) ||
                        trackTitle.contains("Simplified", ignoreCase = true) ||
                        trackTitle.contains("Traditional", ignoreCase = true)) {

                        MPVLib.setPropertyInt("sid", trackId)
                        MPVLib.setPropertyString("sub-visibility", "yes")
                        currentSubtitleIndex = trackId
                        subtitleFound = true
                        Log.d("ActivityMPVView", "✓ Chinese subtitle selected: id=$trackId")
                        break
                    }
                }
            }

            // 没有中文字幕，选第一个字幕轨道
            if (!subtitleFound) {
                for (i in 0 until trackCount) {
                    val trackType = MPVLib.getPropertyString("track-list/$i/type")
                    if (trackType == "sub") {
                        val trackId = MPVLib.getPropertyInt("track-list/$i/id") ?: continue
                        MPVLib.setPropertyInt("sid", trackId)
                        MPVLib.setPropertyString("sub-visibility", "yes")
                        currentSubtitleIndex = trackId
                        subtitleFound = true
                        Log.d("ActivityMPVView", "✓ First subtitle selected: id=$trackId")
                        break
                    }
                }
            }

            // 加载外部字幕
            if (!subtitles.isNullOrEmpty()) {
                // 如果已有内嵌字幕，外部字幕以 auto 模式添加（不覆盖已选）
                val mode = if (subtitleFound) "auto" else "select"
                subtitles!!.forEachIndexed { idx, sub ->
                    val subUrl = sub["url"] ?: return@forEachIndexed
                    val subTitle = sub["title"] ?: "外部字幕 ${idx + 1}"
                    try {
                        MPVLib.command("sub-add", subUrl, mode, subTitle)
                        Log.d("ActivityMPVView", "External subtitle added: $subTitle ($subUrl)")
                    } catch (e: Exception) {
                        Log.e("ActivityMPVView", "Failed to add external subtitle: ${e.message}")
                    }
                }
            }

            val finalSid = MPVLib.getPropertyInt("sid") ?: 0
            val finalVis = MPVLib.getPropertyString("sub-visibility") ?: "no"
            Log.d("ActivityMPVView", "Final subtitle state: sid=$finalSid, visibility=$finalVis")

        } catch (e: Exception) {
            Log.e("ActivityMPVView", "Subtitle selection failed: ${e.message}", e)
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
            iconRes = android.R.drawable.ic_menu_close_clear_cancel,
            iconColor = 0xFFFFFFFF.toInt(),
            bgColor = 0x55000000.toInt()
        ) { finishWithResult() }
        topBar.addView(closeBtn)

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

        // 左侧：标题 + 网速
        val leftInfo = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        }

        titleInfoText = TextView(this).apply {
            text = title
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 14f
            typeface = Typeface.DEFAULT_BOLD
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
        }
        leftInfo.addView(titleInfoText)

        networkSpeedInfo = TextView(this).apply {
            text = networkSpeed
            setTextColor(0xAAFFFFFF.toInt())
            textSize = 12f
        }
        leftInfo.addView(networkSpeedInfo)
        infoAndActionsRow.addView(leftInfo)

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

        // 字幕按钮 - 单击选择字幕，长按选择编码
        subtitleBtn = makeCircleButton(
            dp = dp,
            sizeDp = 34,
            iconRes = android.R.drawable.ic_menu_sort_by_size,
            iconColor = 0xFFFFFFFF.toInt(),
            bgColor = 0x44FFFFFF.toInt()
        ) { showSubtitleMenu() }
        subtitleBtn.layoutParams = btnMarginLP
        subtitleBtn.setOnLongClickListener {
            showEncodingMenu()
            true
        }
        actionBtns.addView(subtitleBtn)

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

        val iconRes = if (isForward) android.R.drawable.ic_media_ff else android.R.drawable.ic_media_rew
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
            setImageResource(android.R.drawable.ic_media_pause)
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
                if (isPlaying) android.R.drawable.ic_media_pause
                else android.R.drawable.ic_media_play
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
                        networkSpeedInfo.text = networkSpeed
                    }
                } catch (_: Exception) {}
            }
        }, 0, 500)
    }

    private fun updateNetworkSpeed(currentPos: Double) {
        try {
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
        
        // 字符编码 - 使用自动检测，优先中文
        MPVLib.setOptionString("sub-codepage", "auto")
        MPVLib.setOptionString("sub-fallback", "utf8")
        
        // 字幕样式 - 使用Roboto字体
        MPVLib.setOptionString("sub-font", "Roboto")
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
        MPVLib.setOptionString("sub-ass-override", "force")  // 强制使用自定义样式
        MPVLib.setOptionString("sub-ass-force-style", "FontName=Roboto,FontSize=48,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,Outline=2.5,Shadow=1")
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
