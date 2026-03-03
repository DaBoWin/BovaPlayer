package com.example.bova_player_flutter.danmaku

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.util.AttributeSet
import android.view.View
import kotlin.math.floor

/**
 * 弹幕渲染视图
 * 60fps 流畅渲染
 */
class DanmakuView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val danmakuList = mutableListOf<Danmaku>()
    private val activeItems = mutableListOf<DanmakuItem>()
    private val scrollTracks = mutableListOf<DanmakuTrack>()
    private val topTracks = mutableListOf<DanmakuTrack>()
    private val bottomTracks = mutableListOf<DanmakuTrack>()
    
    private var config = DanmakuConfig()
    private var currentPosition = 0f // 当前播放位置（秒）
    private var isPlaying = false
    private var lastProcessedIndex = 0
    
    private val paint = Paint().apply {
        isAntiAlias = true
        typeface = Typeface.DEFAULT_BOLD
        setShadowLayer(2f, 1f, 1f, Color.BLACK)
    }
    
    private var lastFrameTime = 0L
    
    /**
     * 设置弹幕列表
     */
    fun setDanmakuList(list: List<Danmaku>) {
        danmakuList.clear()
        danmakuList.addAll(list)
        reset()
    }
    
    /**
     * 设置配置
     */
    fun setConfig(newConfig: DanmakuConfig) {
        config = newConfig
        invalidate()
    }
    
    /**
     * 更新播放位置
     */
    fun updatePosition(position: Float, playing: Boolean) {
        // 检测跳转
        if (kotlin.math.abs(position - currentPosition) > 1.0f) {
            reset()
        }
        
        currentPosition = position
        isPlaying = playing
        
        if (isPlaying) {
            invalidate()
        }
    }
    
    /**
     * 重置状态
     */
    private fun reset() {
        activeItems.clear()
        scrollTracks.clear()
        topTracks.clear()
        bottomTracks.clear()
        lastProcessedIndex = 0
    }
    
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        
        if (!config.enabled || !isPlaying) return
        
        val currentTime = System.currentTimeMillis()
        val deltaTime = if (lastFrameTime == 0L) 0f else (currentTime - lastFrameTime) / 1000f
        lastFrameTime = currentTime
        
        // 添加新弹幕
        addNewDanmaku()
        
        // 更新并绘制弹幕
        val iterator = activeItems.iterator()
        while (iterator.hasNext()) {
            val item = iterator.next()
            item.update(width.toFloat(), deltaTime, config.speed)
            
            if (item.isExpired(width.toFloat())) {
                iterator.remove()
            } else {
                drawDanmaku(canvas, item)
            }
        }
        
        // 继续下一帧
        if (isPlaying) {
            invalidate()
        }
    }
    
    /**
     * 添加新弹幕
     */
    private fun addNewDanmaku() {
        for (i in lastProcessedIndex until danmakuList.size) {
            val danmaku = danmakuList[i]
            
            // 弹幕时间还没到
            if (danmaku.time > currentPosition + 0.1f) break
            
            // 弹幕时间已过
            if (danmaku.time < currentPosition - 0.5f) {
                lastProcessedIndex = i + 1
                continue
            }
            
            // 添加弹幕
            val track = when (danmaku.type) {
                DanmakuType.SCROLL -> findAvailableScrollTrack()
                DanmakuType.TOP -> findAvailableTopTrack()
                DanmakuType.BOTTOM -> findAvailableBottomTrack()
            }
            
            if (track != null) {
                val item = DanmakuItem(danmaku, track)
                activeItems.add(item)
                track.lastItem = item
            }
            
            lastProcessedIndex = i + 1
        }
    }
    
    /**
     * 查找可用的滚动轨道
     * 参考 Flutter 端算法：随机选择可用轨道，让弹幕均匀分布
     */
    private fun findAvailableScrollTrack(): DanmakuTrack? {
        val trackHeight = config.fontSize + 2
        
        // 根据 displayArea 计算显示区域
        val displayHeight = height * config.displayArea
        var maxTracks = floor(displayHeight / trackHeight).toInt()
        
        if (maxTracks <= 0) return null
        if (maxTracks > 50) maxTracks = 50 // 防御性限制
        
        // 收集所有可用轨道的 index
        val availableIndices = mutableListOf<Int>()
        for (i in 0 until maxTracks) {
            availableIndices.add(i)
        }
        
        // 移除不可用的轨道 index
        for (track in scrollTracks) {
            if (track.index < maxTracks) {
                if (!track.isAvailable(width.toFloat())) {
                    availableIndices.remove(track.index)
                } else {
                    // 更新轨道 Y 坐标（防止 fontSize 变化）
                    track.y = track.index * trackHeight
                }
            }
        }
        
        if (availableIndices.isEmpty()) {
            return null
        }
        
        // 随机选择一个可用轨道，让弹幕均匀分布在显示区域
        val targetIndex = availableIndices.random()
        
        // 查找是否已经有该轨道的实例
        val existingTrack = scrollTracks.find { it.index == targetIndex }
        if (existingTrack != null) {
            return existingTrack
        }
        
        // 创建新轨道
        val newTrack = DanmakuTrack(
            index = targetIndex,
            y = targetIndex * trackHeight
        )
        scrollTracks.add(newTrack)
        return newTrack
    }
    
    /**
     * 查找可用的顶部轨道
     */
    private fun findAvailableTopTrack(): DanmakuTrack? {
        val trackHeight = config.fontSize + 10
        val maxTracks = 3
        
        for (track in topTracks) {
            if (track.isAvailableFixed()) {
                return track
            }
        }
        
        if (topTracks.size < maxTracks) {
            val track = DanmakuTrack(
                index = topTracks.size,
                y = topTracks.size * trackHeight
            )
            topTracks.add(track)
            return track
        }
        
        return null
    }
    
    /**
     * 查找可用的底部轨道
     */
    private fun findAvailableBottomTrack(): DanmakuTrack? {
        val trackHeight = config.fontSize + 10
        val maxTracks = 3
        
        for (track in bottomTracks) {
            if (track.isAvailableFixed()) {
                return track
            }
        }
        
        if (bottomTracks.size < maxTracks) {
            val track = DanmakuTrack(
                index = bottomTracks.size,
                y = height - ((bottomTracks.size + 1) * trackHeight)
            )
            bottomTracks.add(track)
            return track
        }
        
        return null
    }
    
    /**
     * 绘制弹幕
     */
    private fun drawDanmaku(canvas: Canvas, item: DanmakuItem) {
        paint.textSize = config.fontSize
        paint.color = item.danmaku.color
        paint.alpha = (config.opacity * 255).toInt()
        
        canvas.drawText(
            item.danmaku.content,
            item.x,
            item.track.y + config.fontSize,
            paint
        )
    }
}

/**
 * 弹幕项
 */
private class DanmakuItem(
    val danmaku: Danmaku,
    val track: DanmakuTrack
) {
    var x = 0f
    var width = 0f
    val startTime = System.currentTimeMillis()
    
    init {
        // 估算文字宽度（粗略估计）
        width = danmaku.content.length * danmaku.fontSize * 0.6f
    }
    
    fun update(screenWidth: Float, deltaTime: Float, speed: Float) {
        when (danmaku.type) {
            DanmakuType.SCROLL -> {
                // 滚动弹幕：15秒滚动完成
                val duration = 15f / speed
                val elapsed = (System.currentTimeMillis() - startTime) / 1000f
                val progress = elapsed / duration
                
                // 从右侧进入，到左侧完全消失
                x = screenWidth - (screenWidth + width) * progress
            }
            DanmakuType.TOP, DanmakuType.BOTTOM -> {
                // 固定弹幕：居中显示
                x = (screenWidth - width) / 2
            }
        }
    }
    
    fun isExpired(screenWidth: Float): Boolean {
        return when (danmaku.type) {
            DanmakuType.SCROLL -> x + width < 0
            DanmakuType.TOP, DanmakuType.BOTTOM -> {
                val elapsed = (System.currentTimeMillis() - startTime) / 1000f
                elapsed > 5f
            }
        }
    }
}

/**
 * 弹幕轨道
 */
private class DanmakuTrack(
    val index: Int,
    var y: Float
) {
    var lastItem: DanmakuItem? = null
    
    fun isAvailable(screenWidth: Float): Boolean {
        val last = lastItem ?: return true
        
        // 上一条弹幕必须移动足够远
        return last.x + last.width < screenWidth - 150
    }
    
    fun isAvailableFixed(): Boolean {
        val last = lastItem ?: return true
        
        // 固定弹幕：上一条显示超过1秒后可以添加新的
        val elapsed = (System.currentTimeMillis() - last.startTime) / 1000f
        return elapsed >= 1f
    }
}
