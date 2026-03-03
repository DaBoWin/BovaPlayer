package com.example.bova_player_flutter.danmaku

import org.json.JSONObject

/**
 * 弹幕数据模型
 */
data class Danmaku(
    val content: String,      // 弹幕内容
    val time: Float,          // 出现时间（秒）
    val type: DanmakuType,    // 弹幕类型
    val color: Int,           // 颜色
    val fontSize: Float = 25f // 字体大小
) {
    companion object {
        /**
         * 从 DanDanPlay API 响应解析弹幕
         * 格式: "p": "0.00,1,16777215,[qq]"
         * 参数: 时间,类型,颜色,用户标识
         */
        fun fromJson(json: JSONObject): Danmaku? {
            try {
                val p = json.getString("p")
                val m = json.getString("m")
                
                val params = p.split(",")
                if (params.size < 3) return null
                
                val time = params[0].toFloatOrNull() ?: return null
                val typeInt = params[1].toIntOrNull() ?: 1
                val colorInt = params[2].toIntOrNull() ?: 0xFFFFFF
                
                val type = when (typeInt) {
                    4 -> DanmakuType.BOTTOM  // 底部
                    5 -> DanmakuType.TOP     // 顶部
                    else -> DanmakuType.SCROLL // 滚动（默认）
                }
                
                // 转换颜色格式（DanDanPlay 使用 RGB 整数）
                val color = 0xFF000000.toInt() or colorInt
                
                return Danmaku(
                    content = m,
                    time = time,
                    type = type,
                    color = color
                )
            } catch (e: Exception) {
                return null
            }
        }
    }
}

/**
 * 弹幕类型
 */
enum class DanmakuType {
    SCROLL,  // 滚动弹幕
    TOP,     // 顶部固定
    BOTTOM   // 底部固定
}

/**
 * 弹幕配置
 */
data class DanmakuConfig(
    var enabled: Boolean = true,
    var opacity: Float = 0.8f,
    var fontSize: Float = 25f,
    var speed: Float = 1.0f,
    var displayArea: Float = 1.0f  // 显示区域（0.0-1.0）
)
