package com.example.bova_player_flutter.danmaku

import android.util.Log
import android.view.ViewGroup
import android.widget.FrameLayout
import com.example.bova_player_flutter.MpvPlayerActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/**
 * MPV 播放器弹幕扩展
 * 为 MpvPlayerActivity 添加弹幕功能
 */
class MpvPlayerActivityDanmakuExtension(
    private val activity: MpvPlayerActivity,
    private val rootLayout: FrameLayout,
    private val videoTitle: String
) {
    companion object {
        private const val TAG = "MpvDanmakuExtension"
    }
    
    private val danmakuController = DanmakuController(activity)
    private val danmakuView = DanmakuView(activity)
    private val scope = CoroutineScope(Dispatchers.Main + Job())
    
    /**
     * 初始化弹幕
     */
    fun initialize() {
        // 添加弹幕视图到根布局
        danmakuView.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        // 添加到索引 1，在 MPV 视图（索引 0）之上，在控制器（索引 2）之下
        rootLayout.addView(danmakuView, 1)
        
        Log.d(TAG, "弹幕视图已添加到布局，层级: ${rootLayout.indexOfChild(danmakuView)}")
        
        // 加载弹幕数据
        loadDanmaku()
    }
    
    /**
     * 加载弹幕
     */
    private fun loadDanmaku() {
        scope.launch {
            try {
                val success = danmakuController.loadDanmakuByFileName(videoTitle)
                if (success) {
                    val danmakuList = danmakuController.getDanmakuList()
                    danmakuView.setDanmakuList(danmakuList)
                    danmakuView.setConfig(danmakuController.config)
                    Log.d(TAG, "✅ 弹幕加载成功: ${danmakuList.size} 条")
                } else {
                    Log.d(TAG, "⚠️  未找到弹幕")
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ 弹幕加载失败: ${e.message}", e)
            }
        }
    }
    
    /**
     * 更新播放位置
     */
    fun updatePosition(position: Float, isPlaying: Boolean) {
        danmakuView.updatePosition(position, isPlaying)
    }
    
    /**
     * 切换弹幕开关
     */
    fun toggleDanmaku() {
        danmakuController.toggleEnabled()
        danmakuView.setConfig(danmakuController.config)
    }
    
    /**
     * 获取弹幕配置
     */
    fun getConfig(): DanmakuConfig = danmakuController.config
    
    /**
     * 设置透明度
     */
    fun setOpacity(opacity: Float) {
        danmakuController.setOpacity(opacity)
        danmakuView.setConfig(danmakuController.config)
    }
    
    /**
     * 设置字体大小
     */
    fun setFontSize(fontSize: Float) {
        danmakuController.setFontSize(fontSize)
        danmakuView.setConfig(danmakuController.config)
    }
    
    /**
     * 设置速度
     */
    fun setSpeed(speed: Float) {
        danmakuController.setSpeed(speed)
        danmakuView.setConfig(danmakuController.config)
    }
    
    /**
     * 设置显示区域
     */
    fun setDisplayArea(area: Float) {
        danmakuController.setDisplayArea(area)
        danmakuView.setConfig(danmakuController.config)
    }
    
    /**
     * 获取弹幕列表
     */
    fun getDanmakuList(): List<Danmaku> = danmakuController.getDanmakuList()
    
    /**
     * 是否有弹幕
     */
    fun hasDanmaku(): Boolean = danmakuController.hasDanmaku()
    
    /**
     * 获取当前视频标题
     */
    fun getCurrentVideoTitle(): String? = danmakuController.getCurrentVideoTitle()
    
    /**
     * 清理资源
     */
    fun destroy() {
        rootLayout.removeView(danmakuView)
    }
}
