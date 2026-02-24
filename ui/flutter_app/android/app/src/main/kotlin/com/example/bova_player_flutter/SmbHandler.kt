package com.example.bova_player_flutter

import android.util.Log
import jcifs.CIFSContext
import jcifs.config.PropertyConfiguration
import jcifs.context.BaseContext
import jcifs.smb.NtlmPasswordAuthenticator
import jcifs.smb.SmbFile
import org.json.JSONArray
import org.json.JSONObject
import java.util.Properties

class SmbHandler {
    private var cifsContext: CIFSContext? = null
    private var currentConnection: SmbFile? = null
    private var isConnected = false

    companion object {
        private const val TAG = "SmbHandler"
    }

    fun connect(
        host: String,
        shareName: String,
        username: String,
        password: String,
        domain: String
    ): Boolean {
        return try {
            Log.d(TAG, "连接到 SMB: smb://$host/$shareName")

            // 配置 jCIFS
            val props = Properties()
            props.setProperty("jcifs.smb.client.minVersion", "SMB202")
            props.setProperty("jcifs.smb.client.maxVersion", "SMB311")
            props.setProperty("jcifs.smb.client.responseTimeout", "30000")
            props.setProperty("jcifs.smb.client.connTimeout", "30000")
            
            val config = PropertyConfiguration(props)
            val baseContext = BaseContext(config)

            // 创建认证
            val auth = NtlmPasswordAuthenticator(
                if (domain.isEmpty()) null else domain,
                username,
                password
            )

            cifsContext = baseContext.withCredentials(auth)

            // 连接到共享
            val url = "smb://$host/$shareName/"
            currentConnection = SmbFile(url, cifsContext)

            // 测试连接
            currentConnection?.exists()
            
            isConnected = true
            Log.d(TAG, "SMB 连接成功")
            true
        } catch (e: Exception) {
            Log.e(TAG, "SMB 连接失败", e)
            isConnected = false
            false
        }
    }

    fun disconnect() {
        try {
            currentConnection = null
            cifsContext = null
            isConnected = false
            Log.d(TAG, "SMB 已断开连接")
        } catch (e: Exception) {
            Log.e(TAG, "断开连接错误", e)
        }
    }

    fun listDirectory(path: String): String {
        if (!isConnected || currentConnection == null) {
            throw Exception("SMB 未连接")
        }

        return try {
            Log.d(TAG, "列出目录: $path")

            val dir = if (path.isEmpty() || path == "/") {
                currentConnection!!
            } else {
                SmbFile(currentConnection, path)
            }

            val files = dir.listFiles() ?: emptyArray()
            val jsonArray = JSONArray()

            for (file in files) {
                // 跳过隐藏文件
                if (file.name.startsWith(".")) continue

                val jsonObj = JSONObject()
                jsonObj.put("name", file.name.trimEnd('/'))
                jsonObj.put("path", getRelativePath(file.path))
                jsonObj.put("isDirectory", file.isDirectory)
                jsonObj.put("size", if (file.isFile) file.length() else null)
                jsonObj.put("modifiedTime", file.lastModified())

                jsonArray.put(jsonObj)
            }

            Log.d(TAG, "找到 ${jsonArray.length()} 个项目")
            jsonArray.toString()
        } catch (e: Exception) {
            Log.e(TAG, "列出目录错误", e)
            throw e
        }
    }

    fun getFileUrl(path: String): String {
        if (!isConnected || currentConnection == null) {
            throw Exception("SMB 未连接")
        }

        return try {
            val file = SmbFile(currentConnection, path)
            
            // 返回 SMB URL
            // 注意：Media Kit 可能不直接支持 SMB 协议
            // 这里返回 URL，后续可能需要通过本地代理服务器
            file.url.toString()
        } catch (e: Exception) {
            Log.e(TAG, "获取文件 URL 错误", e)
            throw e
        }
    }

    fun isConnected(): Boolean {
        return isConnected
    }

    private fun getRelativePath(fullPath: String): String {
        // 移除 smb:// 前缀和服务器地址，只保留相对路径
        val parts = fullPath.split("/")
        return if (parts.size > 4) {
            "/" + parts.drop(4).joinToString("/")
        } else {
            "/"
        }
    }
}
