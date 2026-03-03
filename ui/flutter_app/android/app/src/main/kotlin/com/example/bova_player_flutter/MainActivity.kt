package com.example.bova_player_flutter

import android.content.pm.ActivityInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SMB_CHANNEL = "com.bovaplayer/smb"
    private lateinit var smbHandler: SMBHandler
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 注册 MPV 播放器插件
        flutterEngine.plugins.add(MpvPlayerPlugin())
        
        // 注册 SMB Channel
        smbHandler = SMBHandler()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMB_CHANNEL).setMethodCallHandler { call, result ->
            smbHandler.handleMethodCall(call.method, call.arguments as? Map<String, Any>, result)
        }
    }
    
    override fun onResume() {
        super.onResume()
        // 强制竖屏
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
    }
}
