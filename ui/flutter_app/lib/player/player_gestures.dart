import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 播放器手势控制 Mixin
mixin PlayerGesturesMixin<T extends StatefulWidget> on State<T> {
  // 手势控制状态
  double _brightness = 0.5;
  double _volume = 0.5;
  bool _showBrightnessIndicator = false;
  bool _showVolumeIndicator = false;
  bool _showSeekIndicator = false;
  String _seekIndicatorText = '';
  Timer? _indicatorTimer;
  Duration? _seekTargetPosition;
  
  // 子类需要实现的方法
  bool get isLocked;
  void setVolume(double volume);
  Duration? getCurrentDuration();
  Duration? getCurrentPosition(); // 获取当前播放位置
  void seekTo(Duration position);

  /// 处理垂直拖拽（亮度/音量）
  void handleVerticalDragUpdate(DragUpdateDetails details, bool isLeft) {
    if (isLocked) return;
    
    final delta = details.delta.dy;
    
    if (isLeft) {
      // 左侧控制亮度
      setState(() {
        _brightness = (_brightness - delta / 500).clamp(0.0, 1.0);
        _showBrightnessIndicator = true;
        _showVolumeIndicator = false;
        _showSeekIndicator = false;
      });
      
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarBrightness: _brightness > 0.5 ? Brightness.light : Brightness.dark,
      ));
      
      startIndicatorTimer();
    } else {
      // 右侧控制音量
      setState(() {
        _volume = (_volume - delta / 500).clamp(0.0, 1.0);
        _showVolumeIndicator = true;
        _showBrightnessIndicator = false;
        _showSeekIndicator = false;
      });
      
      setVolume(_volume);
      startIndicatorTimer();
    }
  }

  /// 处理水平拖拽开始（记录当前播放位置）
  void handleHorizontalDragStart(DragStartDetails details) {
    if (isLocked) return;
    _seekTargetPosition = getCurrentPosition();
  }

  /// 处理水平拖拽（从当前位置进行增量偏移）
  void handleHorizontalDragUpdate(DragUpdateDetails details, BuildContext context) {
    if (isLocked) return;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final duration = getCurrentDuration();
    
    if (duration != null && duration.inSeconds > 0) {
      // 第一次拖拽时，以当前播放位置为起点
      _seekTargetPosition ??= getCurrentPosition() ?? Duration.zero;
      
      // 根据手指滑动距离计算时间偏移（全屏宽度 = 180秒）
      final deltaSec = (details.delta.dx / screenWidth) * 180;
      final newSeconds = (_seekTargetPosition!.inSeconds + deltaSec).round().clamp(0, duration.inSeconds);
      _seekTargetPosition = Duration(seconds: newSeconds);
      
      final minutes = newSeconds ~/ 60;
      final seconds = newSeconds % 60;
      final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      
      setState(() {
        _showSeekIndicator = true;
        _showBrightnessIndicator = false;
        _showVolumeIndicator = false;
        _seekIndicatorText = timeStr;
      });
      
      startIndicatorTimer();
    }
  }

  /// 处理水平拖拽结束
  void handleHorizontalDragEnd(DragEndDetails details) {
    if (isLocked || _seekTargetPosition == null) return;
    
    seekTo(_seekTargetPosition!);
    _seekTargetPosition = null;
  }

  /// 启动指示器定时器
  void startIndicatorTimer() {
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showBrightnessIndicator = false;
          _showVolumeIndicator = false;
          _showSeekIndicator = false;
        });
      }
    });
  }

  /// 清理手势资源
  void disposeGestures() {
    _indicatorTimer?.cancel();
  }

  // ============== UI 构建方法 ==============

  Widget buildBrightnessIndicator() {
    if (!_showBrightnessIndicator) return const SizedBox.shrink();
    
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.brightness_6, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              '${(_brightness * 100).toInt()}%',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                value: _brightness,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildVolumeIndicator() {
    if (!_showVolumeIndicator) return const SizedBox.shrink();
    
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _volume > 0.5 ? Icons.volume_up : (_volume > 0 ? Icons.volume_down : Icons.volume_off),
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              '${(_volume * 100).toInt()}%',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                value: _volume,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSeekIndicator() {
    if (!_showSeekIndicator) return const SizedBox.shrink();
    
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fast_forward, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              _seekIndicatorText,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
