package com.example.bova_player_flutter

import android.content.Context
import android.util.AttributeSet
import android.util.Xml
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import `is`.xyz.mpv.BaseMPVView
import `is`.xyz.mpv.MPVLib
import org.xmlpull.v1.XmlPullParser

/**
 * MPV Android 播放器插件
 * 基于 mpvKt 的 BaseMPVView
 */
class MpvPlayerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var platformView: MpvPlatformView? = null
    private var currentUrl: String? = null
    private var currentHttpHeaders: Map<String, String>? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.bovaplayer/mpv")
        channel.setMethodCallHandler(this)

        // 注册 Platform View
        flutterPluginBinding
            .platformViewRegistry
            .registerViewFactory(
                "com.bovaplayer/mpv_view",
                MpvViewFactory(context) { view ->
                    platformView = view
                    // 设置初始化完成回调
                    view.setOnInitializedCallback {
                        android.util.Log.d("MpvPlayerPlugin", "MPV initialized callback received")
                        // 如果已经有 URL，立即加载
                        currentUrl?.let { url ->
                            loadVideo(url, currentHttpHeaders)
                        }
                    }
                }
            )
    }

    private fun loadVideo(url: String, httpHeaders: Map<String, String>?) {
        try {
            android.util.Log.d("MpvPlayerPlugin", "Loading video: $url")
            
            val view = platformView
            if (view == null || !view.isInitialized()) {
                android.util.Log.e("MpvPlayerPlugin", "MPV not initialized yet, will load when ready")
                return
            }
            
            // 设置 HTTP headers
            if (httpHeaders != null && httpHeaders.isNotEmpty()) {
                val headerString = httpHeaders.entries.joinToString(",") { "${it.key}: ${it.value}" }
                MPVLib.setPropertyString("http-header-fields", headerString)
            }
            
            // 加载视频
            MPVLib.command("loadfile", url)
            
            // 自动播放
            MPVLib.setPropertyBoolean("pause", false)
            
            android.util.Log.d("MpvPlayerPlugin", "Video loaded and playing")
            
            // 通知 Flutter 端 MPV 已就绪
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                channel.invokeMethod("onMpvReady", null)
            }
        } catch (e: Exception) {
            android.util.Log.e("MpvPlayerPlugin", "Failed to load video: ${e.message}", e)
            // 通知 Flutter 端发生错误
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                channel.invokeMethod("onError", "加载视频失败: ${e.message}")
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                try {
                    val url = call.argument<String>("url")
                    val title = call.argument<String>("title")
                    val httpHeaders = call.argument<Map<String, String>>("httpHeaders")
                    val subtitles = call.argument<List<Map<String, String>>>("subtitles")

                    if (url == null) {
                        result.error("INVALID_ARGUMENT", "URL is required", null)
                        return
                    }

                    android.util.Log.d("MpvPlayerPlugin", "Initialize called with URL: $url")
                    android.util.Log.d("MpvPlayerPlugin", "platformView is null: ${platformView == null}")
                    android.util.Log.d("MpvPlayerPlugin", "platformView initialized: ${platformView?.isInitialized()}")
                    
                    // 保存 URL 和 headers
                    currentUrl = url
                    currentHttpHeaders = httpHeaders
                    
                    // 如果 MPV 已经初始化，立即加载视频
                    if (platformView?.isInitialized() == true) {
                        android.util.Log.d("MpvPlayerPlugin", "MPV already initialized, loading video immediately")
                        loadVideo(url, httpHeaders)
                    } else {
                        android.util.Log.d("MpvPlayerPlugin", "MPV not yet initialized, will load when ready")
                    }
                    
                    result.success(null)
                } catch (e: Exception) {
                    android.util.Log.e("MpvPlayerPlugin", "Init error: ${e.message}", e)
                    result.error("INIT_ERROR", "Failed to initialize MPV: ${e.message}", null)
                }
            }
            "play" -> {
                try {
                    if (platformView?.isInitialized() == true) {
                        MPVLib.setPropertyBoolean("pause", false)
                        result.success(null)
                    } else {
                        result.error("NOT_INITIALIZED", "MPV not initialized", null)
                    }
                } catch (e: Exception) {
                    result.error("PLAY_ERROR", "Failed to play: ${e.message}", null)
                }
            }
            "pause" -> {
                try {
                    if (platformView?.isInitialized() == true) {
                        MPVLib.setPropertyBoolean("pause", true)
                        result.success(null)
                    } else {
                        result.error("NOT_INITIALIZED", "MPV not initialized", null)
                    }
                } catch (e: Exception) {
                    result.error("PAUSE_ERROR", "Failed to pause: ${e.message}", null)
                }
            }
            "seek" -> {
                try {
                    val position = call.argument<Int>("position")
                    if (position == null) {
                        result.error("INVALID_ARGUMENT", "Position is required", null)
                        return
                    }
                    if (platformView?.isInitialized() == true) {
                        MPVLib.command("seek", (position / 1000.0).toString(), "absolute")
                        result.success(null)
                    } else {
                        result.error("NOT_INITIALIZED", "MPV not initialized", null)
                    }
                } catch (e: Exception) {
                    result.error("SEEK_ERROR", "Failed to seek: ${e.message}", null)
                }
            }
            "getPosition" -> {
                try {
                    if (platformView?.isInitialized() == true) {
                        val pos = MPVLib.getPropertyDouble("time-pos") ?: 0.0
                        result.success((pos * 1000).toInt())
                    } else {
                        result.success(0)
                    }
                } catch (e: Exception) {
                    result.success(0)
                }
            }
            "getDuration" -> {
                try {
                    if (platformView?.isInitialized() == true) {
                        val duration = MPVLib.getPropertyDouble("duration") ?: 0.0
                        result.success((duration * 1000).toInt())
                    } else {
                        result.success(0)
                    }
                } catch (e: Exception) {
                    result.success(0)
                }
            }
            "setVolume" -> {
                try {
                    val volume = call.argument<Int>("volume") ?: 100
                    if (platformView?.isInitialized() == true) {
                        MPVLib.setPropertyInt("volume", volume)
                    }
                    result.success(null)
                } catch (e: Exception) {
                    result.success(null)
                }
            }
            "setSpeed" -> {
                try {
                    val speed = call.argument<Double>("speed") ?: 1.0
                    if (platformView?.isInitialized() == true) {
                        MPVLib.setPropertyDouble("speed", speed)
                    }
                    result.success(null)
                } catch (e: Exception) {
                    result.success(null)
                }
            }
            "loadSubtitle" -> {
                try {
                    val url = call.argument<String>("url")
                    if (url != null && platformView?.isInitialized() == true) {
                        MPVLib.command("sub-add", url, "select")
                    }
                    result.success(null)
                } catch (e: Exception) {
                    result.success(null)
                }
            }
            "setSubtitle" -> {
                try {
                    val index = call.argument<Int>("index") ?: -1
                    if (platformView?.isInitialized() == true) {
                        if (index < 0) {
                            MPVLib.setPropertyString("sid", "no")
                        } else {
                            MPVLib.setPropertyInt("sid", index + 1) // MPV 从 1 开始
                        }
                    }
                    result.success(null)
                } catch (e: Exception) {
                    result.success(null)
                }
            }
            "dispose" -> {
                try {
                    if (platformView?.isInitialized() == true) {
                        // 停止播放但不销毁 MPV（PlatformView 会处理销毁）
                        try {
                            MPVLib.command("stop")
                        } catch (_: Exception) {}
                    }
                    currentUrl = null
                    currentHttpHeaders = null
                    result.success(null)
                } catch (e: Exception) {
                    result.error("DISPOSE_ERROR", "Failed to dispose: ${e.message}", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        platformView = null
        currentUrl = null
        currentHttpHeaders = null
    }
}

/**
 * MPV View Factory
 */
class MpvViewFactory(
    private val context: Context,
    private val onViewCreated: (MpvPlatformView) -> Unit = {}
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val platformView = MpvPlatformView(context)
        onViewCreated(platformView)
        return platformView
    }
}

/**
 * 自定义 MPV View，继承自 BaseMPVView
 */
class CustomMPVView(context: Context, attributes: AttributeSet) : BaseMPVView(context, attributes) {
    
    // 实现抽象方法：初始化选项
    override fun initOptions() {
        // 视频输出配置
        MPVLib.setOptionString("vo", "gpu")
        MPVLib.setOptionString("gpu-context", "android")
        MPVLib.setOptionString("opengl-es", "yes")
        MPVLib.setOptionString("hwdec", "mediacodec-copy")
        MPVLib.setOptionString("hwdec-codecs", "all")
        
        // 强制使用 8-bit 渲染（修复模拟器 GFXSTREAM 的 rgba16f FBO 不支持问题）
        MPVLib.setOptionString("gpu-dumb-mode", "auto")
        MPVLib.setOptionString("dither-depth", "8")
        MPVLib.setOptionString("fbo-format", "rgba8")
        MPVLib.setOptionString("correct-downscaling", "no")
        MPVLib.setOptionString("sigmoid-upscaling", "no")
        MPVLib.setOptionString("hdr-compute-peak", "no")
        
        // 音频配置
        MPVLib.setOptionString("audio-channels", "stereo")
        MPVLib.setOptionString("audio-samplerate", "48000")
        MPVLib.setOptionString("audio-fallback-to-null", "yes")
        MPVLib.setOptionString("ad-lavc-downmix", "yes")
        
        // 字幕配置
        MPVLib.setOptionString("sub-auto", "fuzzy")
        MPVLib.setOptionString("sub-codepage", "utf8")
        MPVLib.setOptionString("sub-font-size", "55")
        
        // TLS / 网络配置
        MPVLib.setOptionString("tls-verify", "no")
        MPVLib.setOptionString("network-timeout", "60")
        MPVLib.setOptionString("cache", "yes")
        MPVLib.setOptionString("cache-secs", "30")
        MPVLib.setOptionString("demuxer-max-bytes", "150M")
        MPVLib.setOptionString("demuxer-max-back-bytes", "50M")
        MPVLib.setOptionString("stream-buffer-size", "8M")
        
        // 日志（info 级别，减少噪音）
        MPVLib.setOptionString("msg-level", "all=info")
    }
    
    // 实现抽象方法：初始化后的选项
    override fun postInitOptions() {
        // 可以在这里设置初始化后的选项
    }
    
    // 实现抽象方法：观察属性
    override fun observeProperties() {
        // 可以在这里观察 MPV 属性变化
    }
}

/**
 * MPV Platform View
 * 每次创建都确保 MPV 干净初始化
 */
class MpvPlatformView(private val appContext: Context) : PlatformView {
    private val mpvView: CustomMPVView
    private var mpvInitialized = false
    private var onInitializedCallback: (() -> Unit)? = null

    init {
        val parser = appContext.resources.getXml(android.R.layout.simple_list_item_1)
        parser.next()
        val attrs = Xml.asAttributeSet(parser)
        
        mpvView = CustomMPVView(appContext, attrs)
        
        // 先尝试销毁旧的 MPV 实例（如果存在）
        try {
            MPVLib.destroy()
            android.util.Log.d("MpvPlatformView", "Destroyed previous MPV instance")
        } catch (e: Exception) {
            android.util.Log.d("MpvPlatformView", "No previous MPV to destroy: ${e.message}")
        }
        
        // 干净初始化
        try {
            mpvView.initialize(appContext.filesDir.path, appContext.cacheDir.path)
            mpvInitialized = true
            android.util.Log.d("MpvPlatformView", "MPV initialized successfully")
        } catch (e: Exception) {
            android.util.Log.e("MpvPlatformView", "MPV init failed: ${e.message}", e)
        }
        
        if (mpvInitialized) {
            onInitializedCallback?.invoke()
        }
    }
    
    fun isInitialized(): Boolean = mpvInitialized
    
    fun setOnInitializedCallback(callback: () -> Unit) {
        onInitializedCallback = callback
        if (mpvInitialized) callback()
    }

    override fun getView(): android.view.View = mpvView

    override fun dispose() {
        try {
            if (mpvInitialized) {
                mpvInitialized = false
                // 完全销毁 MPV，这样下次创建 PlatformView 时可以干净初始化
                try { MPVLib.command("stop") } catch (_: Exception) {}
                try { MPVLib.destroy() } catch (_: Exception) {}
                android.util.Log.d("MpvPlatformView", "MPV fully destroyed")
            }
        } catch (e: Exception) {
            android.util.Log.e("MpvPlatformView", "Failed to dispose MPV: ${e.message}", e)
        }
    }
}
