// Web兼容的Native Bridge实现
import 'package:path_provider/path_provider.dart';

// 检测是否为Web平台的简单方法
bool get isWeb => identical(0, 0.0);

// 视频帧数据类
class VideoFrame {
  final int width;
  final int height;
  final List<int>? data;
  final int dataLen;
  final double timestamp;

  VideoFrame({
    required this.width,
    required this.height,
    this.data,
    required this.dataLen,
    required this.timestamp,
  });
}

class NativeBridge {
  static bool _initialized = false;

  static Future<String> initialize() async {
    if (_initialized) return "Already initialized";
    
    _initialized = true;
    if (isWeb) {
      return "Web platform initialized - using stub implementation";
    }
    return "Native platform initialized - FFI stub implementation";
  }

  static Future<String> openMedia(String filePath, String config) async {
    if (!_initialized) {
      await initialize();
    }

    return "Opened media file: $filePath with config: $config";
  }

  static Future<String> play() async {
    if (!_initialized) return "Not initialized";
    return "Playback started";
  }

  static Future<String> pause() async {
    if (!_initialized) return "Not initialized";
    return "Playback paused";
  }

  static Future<String> stop() async {
    if (!_initialized) return "Not initialized";
    return "Playback stopped";
  }

  static Future<String> seek(double position) async {
    if (!_initialized) return "Not initialized";
    return "Seeked to position: $position";
  }

  static Future<String> setHardwareAcceleration(bool enabled) async {
    if (!_initialized) return "Not initialized";
    return "Hardware acceleration ${enabled ? 'enabled' : 'disabled'}";
  }

  static VideoFrame? getVideoFrame() {
    if (!_initialized) return null;
    
    // 返回模拟帧数据用于测试
    return VideoFrame(
      width: 640,
      height: 480,
      data: List.filled(640 * 480 * 3, 128), // 灰色帧
      dataLen: 640 * 480 * 3,
      timestamp: DateTime.now().millisecondsSinceEpoch / 1000.0,
    );
  }

  static double getPosition() {
    if (!_initialized) return 0.0;
    // 返回模拟播放位置
    return DateTime.now().millisecondsSinceEpoch % 10000 / 1000.0;
  }

  static double getDuration() {
    if (!_initialized) return 0.0;
    // 返回模拟视频时长（10秒）
    return 10.0;
  }

  static Future<String> setHardwareAccel(bool enabled) async {
    return await setHardwareAcceleration(enabled);
  }
}