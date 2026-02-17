import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Emby 播放进度上报器
class EmbyReporter {
  String? _playSessionId;
  Timer? _reportProgressTimer;
  
  final String? itemId;
  final String? serverUrl;
  final String? accessToken;
  final String? userId;
  
  EmbyReporter({
    this.itemId,
    this.serverUrl,
    this.accessToken,
    this.userId,
  });

  /// 上报播放开始
  Future<void> reportPlaybackStart(double volume) async {
    if (itemId == null || serverUrl == null || accessToken == null) {
      return;
    }
    
    try {
      _playSessionId = 'bova_${DateTime.now().millisecondsSinceEpoch}';
      
      final url = '$serverUrl/Sessions/Playing';
      final body = {
        'ItemId': itemId,
        'PlaySessionId': _playSessionId,
        'CanSeek': true,
        'IsPaused': false,
        'IsMuted': false,
        'PositionTicks': 0,
        'VolumeLevel': (volume * 100).toInt(),
        'PlayMethod': 'DirectPlay',
      };
      
      await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Emby-Token': accessToken!,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));
      
      print('[EmbyReporter] 播放开始上报成功');
    } catch (e) {
      print('[EmbyReporter] 播放开始上报异常: $e');
    }
  }

  /// 开始定时上报播放进度
  void startReportProgressTimer(Function() getProgressData) {
    _reportProgressTimer?.cancel();
    _reportProgressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      getProgressData();
    });
  }

  /// 上报播放进度
  Future<void> reportPlaybackProgress(Duration position, bool isPaused, double volume) async {
    if (itemId == null || serverUrl == null || accessToken == null || _playSessionId == null) {
      return;
    }
    
    try {
      final positionTicks = position.inMicroseconds * 10;
      
      final url = '$serverUrl/Sessions/Playing/Progress';
      final body = {
        'ItemId': itemId,
        'PlaySessionId': _playSessionId,
        'CanSeek': true,
        'IsPaused': isPaused,
        'IsMuted': false,
        'PositionTicks': positionTicks,
        'VolumeLevel': (volume * 100).toInt(),
        'PlayMethod': 'DirectPlay',
      };
      
      await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Emby-Token': accessToken!,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      print('[EmbyReporter] 播放进度上报异常: $e');
    }
  }

  /// 上报播放停止
  Future<void> reportPlaybackStopped(Duration position) async {
    if (itemId == null || serverUrl == null || accessToken == null || _playSessionId == null) {
      return;
    }
    
    try {
      final positionTicks = position.inMicroseconds * 10;
      
      final url = '$serverUrl/Sessions/Playing/Stopped';
      final body = {
        'ItemId': itemId,
        'PlaySessionId': _playSessionId,
        'PositionTicks': positionTicks,
      };
      
      await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Emby-Token': accessToken!,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));
      
      print('[EmbyReporter] 播放停止上报成功');
    } catch (e) {
      print('[EmbyReporter] 播放停止上报异常: $e');
    }
  }

  /// 清理资源
  void dispose() {
    _reportProgressTimer?.cancel();
  }
}
