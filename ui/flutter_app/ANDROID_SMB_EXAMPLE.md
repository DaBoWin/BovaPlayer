# Android SMB 使用示例

## 📱 代码示例

### 1. 基本连接示例

```dart
import 'package:flutter/services.dart';

class SMBExample {
  static const MethodChannel _channel = MethodChannel('com.bovaplayer/smb');
  
  // 连接到 SMB 服务器
  Future<bool> connectToSMB() async {
    try {
      final result = await _channel.invokeMethod('connect', {
        'host': '192.168.1.100',      // NAS IP 地址
        'port': 445,                   // SMB 端口
        'username': 'admin',           // 用户名
        'password': 'password123',     // 密码
        'shareName': 'movies',         // 共享名称
        'workgroup': 'WORKGROUP',      // 工作组
      });
      
      print('连接结果: $result');
      return result == true;
    } catch (e) {
      print('连接失败: $e');
      return false;
    }
  }
  
  // 列出目录
  Future<List<Map<String, dynamic>>> listDirectory(String path) async {
    try {
      final result = await _channel.invokeMethod('listDirectory', {
        'path': path,
      });
      
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('列出目录失败: $e');
      return [];
    }
  }
  
  // 读取文件
  Future<Map<String, dynamic>?> readFile(String path, {int? start, int? end}) async {
    try {
      final result = await _channel.invokeMethod('readFile', {
        'path': path,
        'start': start,
        'end': end,
      });
      
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('读取文件失败: $e');
      return null;
    }
  }
  
  // 断开连接
  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
      print('已断开连接');
    } catch (e) {
      print('断开连接失败: $e');
    }
  }
}
```

### 2. 完整使用流程

```dart
void main() async {
  final smb = SMBExample();
  
  // 1. 连接
  print('正在连接...');
  final connected = await smb.connectToSMB();
  
  if (!connected) {
    print('连接失败');
    return;
  }
  
  print('连接成功！');
  
  // 2. 列出根目录
  print('\n列出根目录:');
  final rootFiles = await smb.listDirectory('/');
  for (final file in rootFiles) {
    final type = file['isDirectory'] ? '📁' : '📄';
    final size = file['size'];
    print('$type ${file['name']} ($size bytes)');
  }
  
  // 3. 进入子目录
  if (rootFiles.isNotEmpty && rootFiles[0]['isDirectory']) {
    final subDir = rootFiles[0]['path'];
    print('\n进入目录: $subDir');
    final subFiles = await smb.listDirectory(subDir);
    for (final file in subFiles) {
      print('  - ${file['name']}');
    }
  }
  
  // 4. 读取文件（前 1024 字节）
  final videoFile = rootFiles.firstWhere(
    (f) => !f['isDirectory'] && f['name'].endsWith('.mp4'),
    orElse: () => {},
  );
  
  if (videoFile.isNotEmpty) {
    print('\n读取文件: ${videoFile['name']}');
    final data = await smb.readFile(videoFile['path'], start: 0, end: 1023);
    if (data != null) {
      print('读取了 ${data['data'].length} 字节');
      print('文件总大小: ${data['totalSize']} 字节');
    }
  }
  
  // 5. 断开连接
  print('\n断开连接...');
  await smb.disconnect();
  print('完成！');
}
```

### 3. 在 Flutter Widget 中使用

```dart
class SMBBrowserWidget extends StatefulWidget {
  @override
  _SMBBrowserWidgetState createState() => _SMBBrowserWidgetState();
}

class _SMBBrowserWidgetState extends State<SMBBrowserWidget> {
  final SMBExample _smb = SMBExample();
  List<Map<String, dynamic>> _files = [];
  String _currentPath = '/';
  bool _isLoading = false;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _connect();
  }
  
  Future<void> _connect() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final connected = await _smb.connectToSMB();
      if (connected) {
        await _loadDirectory('/');
      } else {
        setState(() {
          _error = '连接失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '连接错误: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadDirectory(String path) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final files = await _smb.listDirectory(path);
      setState(() {
        _files = files;
        _currentPath = path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载目录失败: $e';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.red)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _connect,
              child: Text('重试'),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        final isDirectory = file['isDirectory'] as bool;
        
        return ListTile(
          leading: Icon(
            isDirectory ? Icons.folder : Icons.insert_drive_file,
            color: isDirectory ? Colors.amber : Colors.blue,
          ),
          title: Text(file['name']),
          subtitle: isDirectory 
            ? null 
            : Text('${(file['size'] / 1024 / 1024).toStringAsFixed(2)} MB'),
          onTap: () {
            if (isDirectory) {
              _loadDirectory(file['path']);
            } else {
              // 播放文件
              _playFile(file);
            }
          },
        );
      },
    );
  }
  
  void _playFile(Map<String, dynamic> file) {
    // 实现播放逻辑
    print('播放文件: ${file['name']}');
  }
  
  @override
  void dispose() {
    _smb.disconnect();
    super.dispose();
  }
}
```

## 🔧 配置说明

### 1. 确保依赖已添加

在 `android/app/build.gradle.kts` 中：

```kotlin
dependencies {
    // SMB 支持
    implementation("eu.agno3.jcifs:jcifs-ng:2.1.10")
}
```

### 2. 确保权限已配置

在 `android/app/src/main/AndroidManifest.xml` 中：

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### 3. 注册 Method Channel

在 `MainActivity.kt` 中：

```kotlin
class MainActivity : FlutterActivity() {
    private val SMB_CHANNEL = "com.bovaplayer/smb"
    private lateinit var smbHandler: SMBHandler
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        smbHandler = SMBHandler()
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, 
            SMB_CHANNEL
        ).setMethodCallHandler { call, result ->
            smbHandler.handleMethodCall(call.method, call.arguments as? Map<String, Any>, result)
        }
    }
}
```

## 📊 API 参考

### connect

连接到 SMB 服务器。

**参数**:
- `host` (String): 服务器 IP 地址或主机名
- `port` (int): 端口号，默认 445
- `username` (String): 用户名
- `password` (String): 密码
- `shareName` (String): 共享名称
- `workgroup` (String): 工作组，默认 "WORKGROUP"

**返回**: `bool` - 连接是否成功

**示例**:
```dart
final success = await _channel.invokeMethod('connect', {
  'host': '192.168.1.100',
  'port': 445,
  'username': 'admin',
  'password': 'password',
  'shareName': 'movies',
  'workgroup': 'WORKGROUP',
});
```

### listDirectory

列出目录内容。

**参数**:
- `path` (String): 目录路径，如 "/" 或 "/subfolder"

**返回**: `List<Map<String, dynamic>>` - 文件列表

每个文件对象包含:
- `name` (String): 文件名
- `path` (String): 完整路径
- `isDirectory` (bool): 是否为目录
- `size` (int): 文件大小（字节）
- `modified` (int): 最后修改时间（毫秒时间戳）

**示例**:
```dart
final files = await _channel.invokeMethod('listDirectory', {
  'path': '/',
});
```

### readFile

读取文件内容。

**参数**:
- `path` (String): 文件路径
- `start` (int, 可选): 起始字节位置
- `end` (int, 可选): 结束字节位置

**返回**: `Map<String, dynamic>`
- `data` (Uint8List): 文件数据
- `totalSize` (int): 文件总大小

**示例**:
```dart
// 读取整个文件
final result = await _channel.invokeMethod('readFile', {
  'path': '/video.mp4',
});

// 读取部分文件（Range 请求）
final result = await _channel.invokeMethod('readFile', {
  'path': '/video.mp4',
  'start': 0,
  'end': 1023,  // 读取前 1KB
});
```

### disconnect

断开 SMB 连接。

**参数**: 无

**返回**: `bool` - 是否成功断开

**示例**:
```dart
await _channel.invokeMethod('disconnect');
```

## 🐛 错误处理

所有方法都可能抛出 `PlatformException`，包含以下错误代码：

| 错误代码 | 说明 | 解决方案 |
|---------|------|---------|
| `INVALID_ARGS` | 参数无效 | 检查必需参数是否提供 |
| `CONNECT_ERROR` | 连接失败 | 检查网络、IP、端口、凭据 |
| `NOT_CONNECTED` | 未连接 | 先调用 connect |
| `PATH_NOT_FOUND` | 路径不存在 | 检查路径是否正确 |
| `NOT_DIRECTORY` | 不是目录 | 确认路径指向目录 |
| `FILE_NOT_FOUND` | 文件不存在 | 检查文件路径 |
| `IS_DIRECTORY` | 是目录不是文件 | 不能读取目录 |
| `LIST_ERROR` | 列出目录失败 | 检查权限和路径 |
| `READ_ERROR` | 读取文件失败 | 检查权限和文件状态 |
| `DISCONNECT_ERROR` | 断开连接失败 | 通常可以忽略 |

**错误处理示例**:
```dart
try {
  final result = await _channel.invokeMethod('connect', params);
} on PlatformException catch (e) {
  switch (e.code) {
    case 'INVALID_ARGS':
      print('参数错误: ${e.message}');
      break;
    case 'CONNECT_ERROR':
      print('连接失败: ${e.message}');
      break;
    default:
      print('未知错误: ${e.code} - ${e.message}');
  }
}
```

## 💡 最佳实践

### 1. 连接管理
```dart
class SMBConnectionManager {
  bool _isConnected = false;
  
  Future<bool> ensureConnected() async {
    if (_isConnected) return true;
    
    _isConnected = await connect();
    return _isConnected;
  }
  
  Future<void> safeDisconnect() async {
    if (_isConnected) {
      await disconnect();
      _isConnected = false;
    }
  }
}
```

### 2. 错误重试
```dart
Future<T?> retryOperation<T>(
  Future<T> Function() operation, {
  int maxRetries = 3,
  Duration delay = const Duration(seconds: 1),
}) async {
  for (int i = 0; i < maxRetries; i++) {
    try {
      return await operation();
    } catch (e) {
      if (i == maxRetries - 1) rethrow;
      await Future.delayed(delay);
    }
  }
  return null;
}
```

### 3. 超时处理
```dart
Future<T?> withTimeout<T>(
  Future<T> future, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  try {
    return await future.timeout(timeout);
  } on TimeoutException {
    print('操作超时');
    return null;
  }
}
```

## 🎯 性能优化

### 1. 使用连接池
```dart
class SMBConnectionPool {
  final Map<String, SMBExample> _connections = {};
  
  SMBExample getConnection(String key) {
    return _connections.putIfAbsent(key, () => SMBExample());
  }
  
  void releaseConnection(String key) {
    _connections[key]?.disconnect();
    _connections.remove(key);
  }
}
```

### 2. 缓存文件列表
```dart
class SMBCache {
  final Map<String, List<Map<String, dynamic>>> _cache = {};
  final Duration _ttl = Duration(minutes: 5);
  
  List<Map<String, dynamic>>? get(String path) {
    return _cache[path];
  }
  
  void set(String path, List<Map<String, dynamic>> files) {
    _cache[path] = files;
    Future.delayed(_ttl, () => _cache.remove(path));
  }
}
```

### 3. 分块读取大文件
```dart
Future<void> readLargeFile(String path) async {
  const chunkSize = 1024 * 1024; // 1MB
  int offset = 0;
  
  while (true) {
    final chunk = await _smb.readFile(
      path,
      start: offset,
      end: offset + chunkSize - 1,
    );
    
    if (chunk == null || chunk['data'].isEmpty) break;
    
    // 处理数据块
    processChunk(chunk['data']);
    
    offset += chunkSize;
  }
}
```
