package com.example.bova_player_flutter

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import jcifs.CIFSContext
import jcifs.config.PropertyConfiguration
import jcifs.context.BaseContext
import jcifs.smb.NtlmPasswordAuthenticator
import jcifs.smb.SmbFile
import java.io.ByteArrayOutputStream
import java.util.Properties
import java.util.concurrent.Executors

class SMBHandler {
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    
    private var cifsContext: CIFSContext? = null
    private var smbFile: SmbFile? = null
    private var connectionInfo: ConnectionInfo? = null
    
    companion object {
        private const val TAG = "SMBHandler"
    }
    
    data class ConnectionInfo(
        val host: String,
        val port: Int,
        val username: String,
        val password: String,
        val shareName: String,
        val workgroup: String
    )
    
    fun handleMethodCall(
        method: String,
        arguments: Map<String, Any>?,
        result: MethodChannel.Result
    ) {
        when (method) {
            "connect" -> connect(arguments, result)
            "disconnect" -> disconnect(result)
            "listDirectory" -> listDirectory(arguments, result)
            "readFile" -> readFile(arguments, result)
            else -> result.notImplemented()
        }
    }
    
    private fun connect(arguments: Map<String, Any>?, result: MethodChannel.Result) {
        executor.execute {
            try {
                val host = arguments?.get("host") as? String
                val port = arguments?.get("port") as? Int ?: 445
                val username = arguments?.get("username") as? String
                val password = arguments?.get("password") as? String
                val shareName = arguments?.get("shareName") as? String
                val workgroup = arguments?.get("workgroup") as? String ?: "WORKGROUP"
                
                if (host == null || username == null || password == null || shareName == null) {
                    mainHandler.post { 
                        result.error("INVALID_ARGS", "Missing required arguments", null) 
                    }
                    return@execute
                }
                
                Log.d(TAG, "连接到 SMB: $host:$port/$shareName")
                
                // 配置 jcifs-ng
                val props = Properties().apply {
                    setProperty("jcifs.smb.client.minVersion", "SMB202")
                    setProperty("jcifs.smb.client.maxVersion", "SMB311")
                    setProperty("jcifs.smb.client.responseTimeout", "30000")
                    setProperty("jcifs.smb.client.connTimeout", "30000")
                    setProperty("jcifs.smb.client.soTimeout", "30000")
                    setProperty("jcifs.resolveOrder", "DNS")
                }
                
                val config = PropertyConfiguration(props)
                val baseContext = BaseContext(config)
                
                // 创建认证
                val auth = NtlmPasswordAuthenticator(workgroup, username, password)
                cifsContext = baseContext.withCredentials(auth)
                
                // 构建 SMB URL
                val url = "smb://$host:$port/$shareName/"
                smbFile = SmbFile(url, cifsContext!!)
                
                // 测试连接（尝试列出根目录）
                smbFile?.exists()
                
                // 保存连接信息
                connectionInfo = ConnectionInfo(host, port, username, password, shareName, workgroup)
                
                Log.d(TAG, "SMB 连接成功")
                mainHandler.post { result.success(true) }
            } catch (e: Exception) {
                Log.e(TAG, "SMB 连接失败", e)
                mainHandler.post { 
                    result.error("CONNECT_ERROR", "连接失败: ${e.message}", null) 
                }
            }
        }
    }
    
    private fun disconnect(result: MethodChannel.Result) {
        executor.execute {
            try {
                smbFile = null
                cifsContext = null
                connectionInfo = null
                Log.d(TAG, "SMB 断开连接")
                mainHandler.post { result.success(true) }
            } catch (e: Exception) {
                Log.e(TAG, "SMB 断开连接失败", e)
                mainHandler.post { 
                    result.error("DISCONNECT_ERROR", e.message, null) 
                }
            }
        }
    }
    
    private fun listDirectory(arguments: Map<String, Any>?, result: MethodChannel.Result) {
        executor.execute {
            try {
                if (smbFile == null || cifsContext == null) {
                    mainHandler.post { 
                        result.error("NOT_CONNECTED", "未连接到 SMB 服务器", null) 
                    }
                    return@execute
                }
                
                val path = arguments?.get("path") as? String ?: "/"
                Log.d(TAG, "列出目录: $path")
                
                // 构建完整路径
                val fullPath = if (path == "/" || path.isEmpty()) {
                    smbFile!!.path
                } else {
                    val cleanPath = path.trim('/').replace("//", "/")
                    "${smbFile!!.path}$cleanPath/"
                }
                
                val dirFile: SmbFile = SmbFile(fullPath, cifsContext!!)
                
                if (!dirFile.exists()) {
                    mainHandler.post { 
                        result.error("PATH_NOT_FOUND", "路径不存在: $path", null) 
                    }
                    return@execute
                }
                
                if (!dirFile.isDirectory()) {
                    mainHandler.post { 
                        result.error("NOT_DIRECTORY", "不是目录: $path", null) 
                    }
                    return@execute
                }
                
                // 列出文件 - 使用 listFiles() 方法
                val fileList = mutableListOf<Map<String, Any>>()
                val files: Array<SmbFile>? = dirFile.listFiles()
                
                if (files != null) {
                    for (file in files) {
                        try {
                            val fileName = file.name.trimEnd('/')
                            val filePath = if (path.endsWith("/")) {
                                "$path$fileName"
                            } else {
                                "$path/$fileName"
                            }
                            
                            fileList.add(mapOf(
                                "name" to fileName,
                                "path" to filePath,
                                "isDirectory" to file.isDirectory(),
                                "size" to file.length(),
                                "modified" to file.lastModified()
                            ))
                        } catch (e: Exception) {
                            Log.w(TAG, "获取文件信息失败", e)
                        }
                    }
                }
                
                Log.d(TAG, "找到 ${fileList.size} 个文件/目录")
                mainHandler.post { result.success(fileList) }
            } catch (e: Exception) {
                Log.e(TAG, "列出目录失败", e)
                mainHandler.post { 
                    result.error("LIST_ERROR", "列出目录失败: ${e.message}", null) 
                }
            }
        }
    }
    
    private fun readFile(arguments: Map<String, Any>?, result: MethodChannel.Result) {
        executor.execute {
            try {
                if (smbFile == null || cifsContext == null) {
                    mainHandler.post { 
                        result.error("NOT_CONNECTED", "未连接到 SMB 服务器", null) 
                    }
                    return@execute
                }
                
                val path = arguments?.get("path") as? String
                val start = (arguments?.get("start") as? Number)?.toLong()
                val end = (arguments?.get("end") as? Number)?.toLong()
                
                if (path == null) {
                    mainHandler.post { 
                        result.error("INVALID_ARGS", "Missing path", null) 
                    }
                    return@execute
                }
                
                Log.d(TAG, "读取文件: $path (range: $start-$end)")
                
                // 构建完整路径
                val cleanPath = path.trim('/').replace("//", "/")
                val fullPath = "${smbFile!!.path}$cleanPath"
                val file: SmbFile = SmbFile(fullPath, cifsContext!!)
                
                if (!file.exists()) {
                    mainHandler.post { 
                        result.error("FILE_NOT_FOUND", "文件不存在: $path", null) 
                    }
                    return@execute
                }
                
                if (file.isDirectory()) {
                    mainHandler.post { 
                        result.error("IS_DIRECTORY", "是目录，不是文件: $path", null) 
                    }
                    return@execute
                }
                
                val totalSize = file.length()
                
                // 读取文件内容
                val inputStream = file.openInputStream()
                val data = if (start != null || end != null) {
                    // 读取指定范围
                    val startPos = start ?: 0L
                    val endPos = end ?: (totalSize - 1)
                    val length = (endPos - startPos + 1).toInt()
                    
                    inputStream.skip(startPos)
                    val buffer = ByteArray(length)
                    var totalRead = 0
                    while (totalRead < length) {
                        val read = inputStream.read(buffer, totalRead, length - totalRead)
                        if (read == -1) break
                        totalRead += read
                    }
                    buffer.copyOf(totalRead)
                } else {
                    // 读取整个文件
                    val outputStream = ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    var bytesRead: Int
                    while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                        outputStream.write(buffer, 0, bytesRead)
                    }
                    outputStream.toByteArray()
                }
                
                inputStream.close()
                
                Log.d(TAG, "读取文件成功: ${data.size} 字节 / $totalSize 总大小")
                
                mainHandler.post {
                    result.success(mapOf(
                        "data" to data,
                        "totalSize" to totalSize
                    ))
                }
            } catch (e: Exception) {
                Log.e(TAG, "读取文件失败", e)
                mainHandler.post { 
                    result.error("READ_ERROR", "读取文件失败: ${e.message}", null) 
                }
            }
        }
    }
}
