package com.example.bova_player_flutter.danmaku

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/**
 * 弹幕 API 服务
 * 调用 DanDanPlay API 获取弹幕数据
 */
class DanmakuApiService {
    companion object {
        private const val TAG = "DanmakuApiService"
        private const val BASE_URL = "https://danmuapi-sandy-six.vercel.app/bova"
        private const val TIMEOUT = 10000 // 10秒超时
    }
    
    /**
     * 搜索匹配视频
     * @param fileName 视频文件名或标题
     * @return 匹配结果列表
     */
    suspend fun searchMatch(fileName: String): List<MatchResult> = withContext(Dispatchers.IO) {
        try {
            val cleanedFileName = cleanFileName(fileName)
            val encodedFileName = URLEncoder.encode(cleanedFileName, "UTF-8")
            val urlString = "$BASE_URL/api/v2/match"
            
            Log.d(TAG, "🔍 搜索弹幕: $cleanedFileName")
            Log.d(TAG, "📡 请求 URL: $urlString")
            
            val url = URL(urlString)
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.connectTimeout = TIMEOUT
            connection.readTimeout = TIMEOUT
            connection.doOutput = true
            
            // 发送 POST 数据
            val postData = JSONObject().apply {
                put("fileName", cleanedFileName)
            }
            connection.outputStream.use { os ->
                os.write(postData.toString().toByteArray())
            }
            
            val responseCode = connection.responseCode
            Log.d(TAG, "📡 响应状态: $responseCode")
            
            if (responseCode == HttpURLConnection.HTTP_OK) {
                val response = connection.inputStream.bufferedReader().use { it.readText() }
                Log.d(TAG, "📡 响应内容: ${response.take(200)}")
                
                val jsonResponse = JSONObject(response)
                val matches = jsonResponse.optJSONArray("matches") ?: JSONArray()
                
                val results = mutableListOf<MatchResult>()
                for (i in 0 until matches.length()) {
                    val match = matches.getJSONObject(i)
                    results.add(MatchResult(
                        episodeId = match.getInt("episodeId"),
                        animeTitle = match.optString("animeTitle", ""),
                        episodeTitle = match.optString("episodeTitle", "")
                    ))
                }
                
                Log.d(TAG, "✅ 找到 ${results.size} 个匹配")
                results
            } else {
                val errorBody = connection.errorStream?.bufferedReader()?.use { it.readText() } ?: ""
                Log.e(TAG, "❌ HTTP 错误: $responseCode, $errorBody")
                emptyList()
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ 搜索失败: ${e.message}", e)
            emptyList()
        }
    }
    
    /**
     * 获取弹幕数据
     * @param episodeId 剧集 ID
     * @return 弹幕列表
     */
    suspend fun getDanmaku(episodeId: Int): List<Danmaku> = withContext(Dispatchers.IO) {
        try {
            val urlString = "$BASE_URL/api/v2/comment/$episodeId?format=json"
            Log.d(TAG, "📥 获取弹幕: episodeId=$episodeId")
            Log.d(TAG, "📡 请求 URL: $urlString")
            
            val url = URL(urlString)
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = TIMEOUT
            connection.readTimeout = TIMEOUT
            
            val responseCode = connection.responseCode
            Log.d(TAG, "📡 响应状态: $responseCode")
            
            if (responseCode == HttpURLConnection.HTTP_OK) {
                val response = connection.inputStream.bufferedReader().use { it.readText() }
                
                val jsonResponse = JSONObject(response)
                val count = jsonResponse.optInt("count", 0)
                val comments = jsonResponse.optJSONArray("comments") ?: JSONArray()
                
                Log.d(TAG, "📥 弹幕总数: $count")
                
                val danmakuList = mutableListOf<Danmaku>()
                for (i in 0 until comments.length()) {
                    val comment = comments.getJSONObject(i)
                    Danmaku.fromJson(comment)?.let { danmakuList.add(it) }
                }
                
                // 按时间排序
                danmakuList.sortBy { it.time }
                
                Log.d(TAG, "✅ 解析成功: ${danmakuList.size} 条弹幕")
                danmakuList
            } else {
                val errorBody = connection.errorStream?.bufferedReader()?.use { it.readText() } ?: ""
                Log.e(TAG, "❌ HTTP 错误: $responseCode, $errorBody")
                emptyList()
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ 获取弹幕失败: ${e.message}", e)
            emptyList()
        }
    }
    
    /**
     * 清理文件名，提高匹配成功率
     */
    private fun cleanFileName(fileName: String): String {
        var cleaned = fileName
        
        // 检查是否已包含季集信息
        val hasSeasonEpisode = Regex("S\\d+E\\d+", RegexOption.IGNORE_CASE).containsMatchIn(cleaned)
        
        if (hasSeasonEpisode) {
            // 只移除技术信息
            cleaned = cleanFileNameSimple(cleaned)
        } else {
            // 完整清理
            cleaned = cleanFileNameFull(cleaned)
        }
        
        return cleaned.trim()
    }
    
    private fun cleanFileNameSimple(fileName: String): String {
        var cleaned = fileName
        
        // 移除文件扩展名
        cleaned = cleaned.replace(Regex("\\.(mp4|mkv|avi|mov|flv|wmv|webm)$", RegexOption.IGNORE_CASE), "")
        
        // 移除年份
        cleaned = cleaned.replace(Regex("\\(?\\d{4}\\)?"), "")
        
        // 移除技术信息
        cleaned = cleaned.replace(Regex("\\b(4K|2160p|1080p|720p|480p|360p)\\b", RegexOption.IGNORE_CASE), "")
        cleaned = cleaned.replace(Regex("\\b(HEVC|H\\.?264|H\\.?265|x264|x265|AVC|VP9|AV1)\\b", RegexOption.IGNORE_CASE), "")
        cleaned = cleaned.replace(Regex("\\b(AAC|AC3|DTS|TrueHD|FLAC|Atmos|DDP|DD\\+?|5\\.1|7\\.1)\\b", RegexOption.IGNORE_CASE), "")
        cleaned = cleaned.replace(Regex("\\b(HDR|HDR10|HDR10\\+|Dolby Vision|DV|SDR)\\b", RegexOption.IGNORE_CASE), "")
        cleaned = cleaned.replace(Regex("\\b(WEB-?DL|WEBRip|BluRay|BDRip|DVDRip|HDTV|WEB)\\b", RegexOption.IGNORE_CASE), "")
        
        // 移除制作组信息
        cleaned = cleaned.replace(Regex("\\[.*?\\]"), "")
        cleaned = cleaned.replace(Regex("\\(.*?(字幕组|Sub|Rip|组|简|繁|中字|内封|外挂).*?\\)", RegexOption.IGNORE_CASE), "")
        
        // 标准化季集格式
        cleaned = cleaned.replace(Regex("s(\\d+)e(\\d+)", RegexOption.IGNORE_CASE)) { matchResult ->
            val season = matchResult.groupValues[1].padStart(2, '0')
            val episode = matchResult.groupValues[2].padStart(2, '0')
            "S${season}E$episode"
        }
        
        // 清理分隔符
        cleaned = cleaned.replace(Regex("[_\\.\\-]+"), " ")
        cleaned = cleaned.replace(Regex("\\s+"), " ")
        
        return cleaned
    }
    
    private fun cleanFileNameFull(fileName: String): String {
        var cleaned = fileName
        
        // 移除文件扩展名
        cleaned = cleaned.replace(Regex("\\.(mp4|mkv|avi|mov|flv|wmv|webm)$", RegexOption.IGNORE_CASE), "")
        
        // 提取季集信息
        val seasonEpisodeMatch = Regex("s(\\d+)e(\\d+)", RegexOption.IGNORE_CASE).find(cleaned)
        val seasonEpisode = seasonEpisodeMatch?.let {
            val season = it.groupValues[1].padStart(2, '0')
            val episode = it.groupValues[2].padStart(2, '0')
            "S${season}E$episode"
        }
        
        // 移除制作组信息
        cleaned = cleaned.replace(Regex("\\[.*?\\]"), "")
        cleaned = cleaned.replace(Regex("\\(.*?(字幕组|Sub|Rip|组|简|繁|中字|内封|外挂).*?\\)", RegexOption.IGNORE_CASE), "")
        
        // 移除年份
        cleaned = cleaned.replace(Regex("\\(?\\d{4}\\)?"), "")
        
        // 移除技术信息
        cleaned = cleaned.replace(Regex("\\b(4K|2160p|1080p|720p|480p|360p)\\b", RegexOption.IGNORE_CASE), "")
        cleaned = cleaned.replace(Regex("\\b(HEVC|H\\.?264|H\\.?265|x264|x265|AVC|VP9|AV1)\\b", RegexOption.IGNORE_CASE), "")
        cleaned = cleaned.replace(Regex("\\b(AAC|AC3|DTS|TrueHD|FLAC|Atmos|DDP|DD\\+?|5\\.1|7\\.1)\\b", RegexOption.IGNORE_CASE), "")
        cleaned = cleaned.replace(Regex("\\b(HDR|HDR10|HDR10\\+|Dolby Vision|DV|SDR)\\b", RegexOption.IGNORE_CASE), "")
        cleaned = cleaned.replace(Regex("\\b(WEB-?DL|WEBRip|BluRay|BDRip|DVDRip|HDTV|WEB)\\b", RegexOption.IGNORE_CASE), "")
        
        // 移除季集信息（稍后重新添加）
        cleaned = cleaned.replace(Regex("s\\d+e\\d+", RegexOption.IGNORE_CASE), "")
        
        // 清理分隔符
        cleaned = cleaned.replace(Regex("[_\\.\\-]+"), " ")
        cleaned = cleaned.replace(Regex("\\s+"), " ")
        cleaned = cleaned.trim()
        
        // 提取中文名称
        val chineseMatch = Regex("[\\u4e00-\\u9fa5]+(?:[\\u4e00-\\u9fa5\\s]*[\\u4e00-\\u9fa5]+)*").find(cleaned)
        val finalName = chineseMatch?.value ?: cleaned
        
        // 添加季集信息
        return if (seasonEpisode != null) {
            "$finalName $seasonEpisode"
        } else {
            finalName
        }
    }
}

/**
 * 匹配结果
 */
data class MatchResult(
    val episodeId: Int,
    val animeTitle: String,
    val episodeTitle: String
)
