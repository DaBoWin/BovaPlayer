package com.example.bova_player_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 注册 MPV 播放器插件
        flutterEngine.plugins.add(MpvPlayerPlugin())
    }
}
