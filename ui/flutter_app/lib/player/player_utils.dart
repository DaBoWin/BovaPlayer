import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 播放器工具类
class PlayerUtils {
  /// 格式化时长
  static String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 格式化网速
  static String formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 0) return '0 B/s';
    
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    }
  }

  /// 加载保存的播放位置
  static Future<Duration?> loadSavedPosition(String? itemId) async {
    if (itemId == null) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'play_position_$itemId';
      final savedSeconds = prefs.getInt(key);
      if (savedSeconds != null && savedSeconds > 0) {
        return Duration(seconds: savedSeconds);
      }
    } catch (e) {
      print('[PlayerUtils] 加载播放位置失败: $e');
    }
    return null;
  }

  /// 保存播放位置
  static Future<void> savePlayPosition(String? itemId, Duration? position, Duration? duration) async {
    if (itemId == null || position == null || duration == null) return;
    try {
      // 如果播放超过 95%，清除保存的位置
      if (duration.inSeconds > 0 && position.inSeconds / duration.inSeconds > 0.95) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('play_position_$itemId');
        return;
      }
      
      // 只保存超过 5 秒的位置
      if (position.inSeconds > 5) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('play_position_$itemId', position.inSeconds);
      }
    } catch (e) {
      print('[PlayerUtils] 保存播放位置失败: $e');
    }
  }

  /// 显示继续播放对话框
  static Future<bool?> showResumeDialog(BuildContext context, Duration savedPosition) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('继续播放', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text(
          '上次播放到 ${formatDuration(savedPosition)}\n是否继续播放？',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('从头开始', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F2937),
              foregroundColor: Colors.white,
            ),
            child: const Text('继续播放'),
          ),
        ],
      ),
    );
  }
}
