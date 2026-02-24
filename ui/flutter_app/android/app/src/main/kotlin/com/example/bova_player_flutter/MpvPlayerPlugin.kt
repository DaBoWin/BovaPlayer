package com.example.bova_player_flutter

import android.content.Context
import android.view.View
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import `is`.xyz.mpv.MPVLib
import `is`.xyz.mpv.MPVView

/**
 * MPV Android 播放器插件
 * 集成 mpv-android 库，支持所有音视频格式
 */
class MpvPlayerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var mpvView: MPVView? = null
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
                    mpvView = view
                    // 如果已经有 URL，立即加载
                    currentUrl?.let { url ->
                        loadVideo(url, currentHttpHeaders)
                    }
                }
            )
    }

    private fun loadVideo(url: String, httpHeaders: Map<String, String>?) {
        try {
            android.util.Log.d("MpvPlayerPlugin", "Loading video: $url")
            
            // 设置 HTTP headers
            if (httpHeaders != null && httpHeaders.isNotEmpty()) {
                val headerString = httpHeaders.entries.joinToString(",") { "${it.key}: ${it.value}" }
                MPVLib.setOptionString("http-header-fields", headerString)
            }
            
            // 加载视频
            MPVLib.command(arrayOf("loadfile", url))
            
            android.util.Log.d("MpvPlayerPlugin", "Video loaded successfully")
        } catch (e: Exception) {
            android.util.Log.e("MpvPlayerPlugin", "Failed to load video: ${e.message}", e)
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
                    
                    // 保存 URL 和 headers
                    currentUrl = url
                    currentHttpHeaders = httpHeaders
                    
                    // 如果 MPVView 已经创建，立即加载视频
                    mpvView?.let {
                        loadVideo(url, httpHeaders)
                    }
                    
                    result.success(null)
                } catch (e: Exception) {
                    android.util.Log.e("MpvPlayerPlugin", "Init error: ${e.message}", e)
                    result.error("INIT_ERROR", "Failed to initialize MPV: ${e.message}", null)
                }
            }
            "play" -> {
                try {
                    mpvView?.let {
                        MPVLib.command(arrayOf("set", "pause", "no"))
                        result.success(null)
                    } ?: result.error("NOT_INITIALIZED", "MPV not initialized", null)
                } catch (e: Exception) {
                    result.error("PLAY_ERROR", "Failed to play: ${e.message}", null)
                }
            }
            "pause" -> {
                try {
                    mpvView?.let {
                        MPVLib.command(arrayOf("set", "pause", "yes"))
                        result.success(null)
                    } ?: result.error("NOT_INITIALIZED", "MPV not initialized", null)
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
                    mpvView?.let {
                        MPVLib.command(arrayOf("seek", (position / 1000.0).toString(), "absolute"))
                        result.success(null)
                    } ?: result.error("NOT_INITIALIZED", "MPV not initialized", null)
                } catch (e: Exception) {
                    result.error("SEEK_ERROR", "Failed to seek: ${e.message}", null)
                }
            }
            "getPosition" -> {
                try {
                    mpvView?.let {
                        val pos = MPVLib.getPropertyDouble("time-pos") ?: 0.0
                        result.success((pos * 1000).toInt())
                    } ?: result.success(0)
                } catch (e: Exception) {
                    result.success(0)
                }
            }
            "getDuration" -> {
                try {
                    mpvView?.let {
                        val duration = MPVLib.getPropertyDouble("duration") ?: 0.0
                        result.success((duration * 1000).toInt())
                    } ?: result.success(0)
                } catch (e: Exception) {
                    result.success(0)
                }
            }
            "dispose" -> {
                try {
                    mpvView?.let {
                        MPVLib.command(arrayOf("quit"))
                        mpvView = null
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
        mpvView = null
        currentUrl = null
        currentHttpHeaders = null
    }
}

/**
 * MPV View Factory
 */
class MpvViewFactory(
    private val context: Context,
    private val onViewCreated: (MPVView) -> Unit = {}
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val platformView = MpvPlatformView(context)
        onViewCreated(platformView.getMpvView())
        return platformView
    }
}

/**
 * MPV Platform View
 */
class MpvPlatformView(context: Context) : PlatformView {
    private val mpvView: MPVView = MPVView(context, null)

    init {
        // 初始化 MPV
        mpvView.initialize(context.applicationInfo.dataDir)
        
        // 配置 MPV 选项
        configureMpv()
        
        android.util.Log.d("MpvPlatformView", "MPV initialized successfully")
    }

    fun getMpvView(): MPVView {
        return mpvView
    }

    private fun configureMpv() {
        try {
            // 硬件解码（优先使用，失败时自动回退到软件解码）
            MPVLib.setOptionString("hwdec", "mediacodec-copy")
            MPVLib.setOptionString("hwdec-codecs", "all")
            
            // 音频配置 - 支持所有格式包括 TrueHD
            MPVLib.setOptionString("audio-channels", "stereo")
            MPVLib.setOptionString("audio-samplerate", "48000")
            MPVLib.setOptionString("audio-fallback-to-null", "yes")
            MPVLib.setOptionString("ad-lavc-downmix", "yes")
            
            // 字幕配置 - 支持所有格式包括 PGS
            MPVLib.setOptionString("sub-auto", "fuzzy")
            MPVLib.setOptionString("sub-codepage", "utf8")
            MPVLib.setOptionString("sub-font-size", "55")
            
            // 网络配置
            MPVLib.setOptionString("cache", "yes")
            MPVLib.setOptionString("cache-secs", "10")
            MPVLib.setOptionString("demuxer-max-bytes", "50M")
            MPVLib.setOptionString("demuxer-max-back-bytes", "20M")
            
            // 网络超时
            MPVLib.setOptionString("network-timeout", "60")
            MPVLib.setOptionString("stream-buffer-size", "4M")
            
            // TLS 配置
            MPVLib.setOptionString("tls-verify", "no")
            
            // 视频输出
            MPVLib.setOptionString("vo", "gpu")
            MPVLib.setOptionString("gpu-context", "android")
            
            // 日志
            MPVLib.setOptionString("msg-level", "all=info")
            
            android.util.Log.d("MpvPlatformView", "MPV configured successfully")
            
        } catch (e: Exception) {
            android.util.Log.e("MpvPlatformView", "Failed to configure MPV: ${e.message}", e)
        }
    }

    override fun getView(): View {
        return mpvView
    }

    override fun dispose() {
        try {
            MPVLib.command(arrayOf("quit"))
            android.util.Log.d("MpvPlatformView", "MPV disposed")
        } catch (e: Exception) {
            android.util.Log.e("MpvPlatformView", "Failed to dispose MPV: ${e.message}", e)
        }
    }
}
