package com.example.bova_player_flutter.danmaku

import android.content.Context
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * 弹幕控制器
 * 负责加载和管理弹幕数据
 */
class DanmakuController(private val context: Context) {
    companion object {
        private const val TAG = "DanmakuController"
        private const val PREFS_NAME = "danmaku_prefs"
    }
    
    private val apiService = DanmakuApiService()
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    
    var config = DanmakuConfig(
        enabled = prefs.getBoolean("enabled", true),
        opacity = prefs.getFloat("opacity", 0.8f),
        fontSize = prefs.getFloat("fontSize", 25f),
        speed = prefs.getFloat("speed", 1.0f),
        displayArea = prefs.getFloat("displayArea", 1.0f)
    )
        private set
    
    private var danmakuList = emptyList<Danmaku>()
    private var currentEpisodeId: Int? = null
    private var currentVideoTitle: String? = null
    
    /**
     * 加载弹幕（通过文件名匹配）
     */
    suspend fun loadDanmakuByFileName(fileName: String): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                Log.d(TAG, "========================================")
                Log.d(TAG, "[弹幕] 原始标题: $fileName")
                
                // 1. 搜索匹配
                val matches = apiService.searchMatch(fileName)
                
                if (matches.isEmpty()) {
                    Log.d(TAG, "[弹幕] ❌ 未找到匹配")
                    Log.d(TAG, "========================================")
                    return@withContext false
                }
                
                // 2. 使用第一个匹配结果
                val match = matches.first()
                currentEpisodeId = match.episodeId
                currentVideoTitle = match.animeTitle.ifEmpty { match.episodeTitle }
                
                Log.d(TAG, "[弹幕] ✅ 匹配成功: $currentVideoTitle")
                Log.d(TAG, "[弹幕] 剧集ID: $currentEpisodeId")
                
                // 3. 获取弹幕
                val list = apiService.getDanmaku(match.episodeId)
                
                if (list.isEmpty()) {
                    Log.d(TAG, "[弹幕] ⚠️  暂无弹幕")
                    Log.d(TAG, "========================================")
                    return@withContext false
                }
                
                danmakuList = list
                
                Log.d(TAG, "[弹幕] ✅ 加载成功: ${list.size} 条弹幕")
                Log.d(TAG, "[弹幕] 弹幕开关: ${if (config.enabled) "开启" else "关闭"}")
                Log.d(TAG, "========================================")
                
                true
            } catch (e: Exception) {
                Log.e(TAG, "[弹幕] ❌ 加载失败: ${e.message}", e)
                Log.d(TAG, "========================================")
                false
            }
        }
    }
    
    /**
     * 获取弹幕列表
     */
    fun getDanmakuList(): List<Danmaku> = danmakuList
    
    /**
     * 切换弹幕开关
     */
    fun toggleEnabled() {
        config = config.copy(enabled = !config.enabled)
        saveConfig()
    }
    
    /**
     * 设置透明度
     */
    fun setOpacity(opacity: Float) {
        config = config.copy(opacity = opacity.coerceIn(0f, 1f))
        saveConfig()
    }
    
    /**
     * 设置字体大小
     */
    fun setFontSize(fontSize: Float) {
        config = config.copy(fontSize = fontSize.coerceIn(12f, 48f))
        saveConfig()
    }
    
    /**
     * 设置速度
     */
    fun setSpeed(speed: Float) {
        config = config.copy(speed = speed.coerceIn(0.5f, 2.0f))
        saveConfig()
    }
    
    /**
     * 设置显示区域
     */
    fun setDisplayArea(area: Float) {
        config = config.copy(displayArea = area.coerceIn(0.25f, 1.0f))
        saveConfig()
    }
    
    /**
     * 保存配置
     */
    private fun saveConfig() {
        prefs.edit().apply {
            putBoolean("enabled", config.enabled)
            putFloat("opacity", config.opacity)
            putFloat("fontSize", config.fontSize)
            putFloat("speed", config.speed)
            putFloat("displayArea", config.displayArea)
            apply()
        }
    }
    
    /**
     * 获取当前视频标题
     */
    fun getCurrentVideoTitle(): String? = currentVideoTitle
    
    /**
     * 是否有弹幕
     */
    fun hasDanmaku(): Boolean = danmakuList.isNotEmpty()
}
