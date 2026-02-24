package com.example.bova_player_flutter

import android.app.Activity
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

/**
 * MPV Player Plugin
 * 通过启动原生 Activity 来播放视频，避免 Flutter AndroidView 的 SurfaceView 合成问题
 */
class MpvPlayerPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.bovaplayer/mpv")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                // 从 Flutter 接收参数，启动原生 Activity 播放
                val url = call.argument<String>("url")
                val title = call.argument<String>("title") ?: "视频"
                val httpHeaders = call.argument<Map<String, String>>("httpHeaders")
                val subtitles = call.argument<List<Map<String, String>>>("subtitles")
                
                if (url == null) {
                    result.error("NO_URL", "URL is required", null)
                    return
                }
                
                val currentActivity = activity
                if (currentActivity == null) {
                    result.error("NO_ACTIVITY", "Activity not available", null)
                    return
                }
                
                val intent = Intent(currentActivity, MpvPlayerActivity::class.java).apply {
                    putExtra(MpvPlayerActivity.EXTRA_URL, url)
                    putExtra(MpvPlayerActivity.EXTRA_TITLE, title)
                    if (httpHeaders != null) {
                        putExtra(MpvPlayerActivity.EXTRA_HEADERS, HashMap(httpHeaders))
                    }
                    if (subtitles != null) {
                        val subtitleList = ArrayList<HashMap<String, String>>()
                        subtitles.forEach { sub ->
                            val map = HashMap<String, String>()
                            sub.forEach { (key, value) ->
                                map[key] = value.toString()
                            }
                            subtitleList.add(map)
                        }
                        putExtra(MpvPlayerActivity.EXTRA_SUBTITLES, subtitleList)
                    }
                }
                
                currentActivity.startActivity(intent)
                
                android.util.Log.d("MpvPlayerPlugin", "Launched MpvPlayerActivity for: $url")
                
                // 通知 Flutter 已启动
                result.success(null)
                
                // 延迟发送 onMpvReady，让 Flutter 知道播放器已打开
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    channel.invokeMethod("onMpvReady", null)
                }, 500)
            }
            "dispose" -> {
                result.success(null)
            }
            "getPosition" -> {
                result.success(0L)
            }
            "getDuration" -> {
                result.success(0L)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
    
    // ActivityAware 接口
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }
    
    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }
    
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }
    
    override fun onDetachedFromActivity() {
        activity = null
    }
}
