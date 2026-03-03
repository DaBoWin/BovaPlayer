import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/danmaku.dart';

/// 弹幕视图
class DanmakuView extends StatefulWidget {
  final List<Danmaku> danmakuList;
  final Duration currentPosition;
  final bool isPlaying;
  final DanmakuConfig config;
  
  const DanmakuView({
    super.key,
    required this.danmakuList,
    required this.currentPosition,
    required this.isPlaying,
    this.config = const DanmakuConfig(),
  });
  
  @override
  State<DanmakuView> createState() => _DanmakuViewState();
}

class _DanmakuViewState extends State<DanmakuView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_DanmakuItem> _activeItems = [];
  final List<_DanmakuTrack> _scrollTracks = [];
  final List<_DanmakuTrack> _topTracks = [];
  final List<_DanmakuTrack> _bottomTracks = [];
  
  int _lastProcessedIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // 60fps
    )..addListener(_onTick);
    
    print('[弹幕渲染] 🎬 初始化: 弹幕总数=${widget.danmakuList.length}, 开关=${widget.config.enabled}, 透明度=${widget.config.opacity}');
    
    if (widget.isPlaying) {
      _controller.repeat();
      print('[弹幕渲染] ▶️  开始渲染');
    }
  }
  
  @override
  void didUpdateWidget(DanmakuView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 播放状态变化
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
    
    // 位置跳转
    if ((widget.currentPosition - oldWidget.currentPosition).abs() > const Duration(seconds: 1)) {
      _reset();
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _reset() {
    _activeItems.clear();
    _scrollTracks.clear();
    _topTracks.clear();
    _bottomTracks.clear();
    _lastProcessedIndex = 0;
  }
  
  void _onTick() {
    if (!mounted) return;
    
    final currentTime = widget.currentPosition.inMilliseconds / 1000.0;
    
    // 每10秒打印一次状态
    if (currentTime.toInt() % 10 == 0 && currentTime.toInt() != _lastLogTime) {
      _lastLogTime = currentTime.toInt();
      print('[弹幕渲染] ⏱️  当前时间: ${currentTime.toStringAsFixed(1)}s, 弹幕总数: ${widget.danmakuList.length}, 已处理: $_lastProcessedIndex, 活跃: ${_activeItems.length}');
      if (widget.danmakuList.isNotEmpty) {
        print('[弹幕渲染] 📍 第一条弹幕时间: ${widget.danmakuList.first.time}s, 最后一条: ${widget.danmakuList.last.time}s');
      }
    }
    
    // 添加新弹幕
    _addNewDanmaku(currentTime);
    
    // 更新现有弹幕
    _updateDanmaku();
    
    // 移除过期弹幕
    _removeExpiredDanmaku();
    
    setState(() {});
  }
  
  int _lastLogTime = -1;
  
  void _addNewDanmaku(double currentTime) {
    // 从上次处理的位置开始查找
    for (int i = _lastProcessedIndex; i < widget.danmakuList.length; i++) {
      final danmaku = widget.danmakuList[i];
      
      // 如果弹幕时间还没到，停止查找
      if (danmaku.time > currentTime + 0.1) break;
      
      // 如果弹幕时间已过，跳过
      if (danmaku.time < currentTime - 0.5) {
        _lastProcessedIndex = i + 1;
        continue;
      }
      
      // 添加弹幕
      print('[弹幕渲染] 🎯 添加弹幕: ${danmaku.content} @ ${danmaku.time}s');
      _addDanmakuItem(danmaku);
      _lastProcessedIndex = i + 1;
    }
  }
  
  void _addDanmakuItem(Danmaku danmaku) {
    if (!widget.config.enabled) return;
    
    // 根据类型分配轨道
    _DanmakuTrack? track;
    
    switch (danmaku.type) {
      case DanmakuType.scroll:
        track = _findAvailableScrollTrack();
        break;
      case DanmakuType.top:
        track = _findAvailableTopTrack();
        break;
      case DanmakuType.bottom:
        track = _findAvailableBottomTrack();
        break;
    }
    
    if (track != null) {
      final item = _DanmakuItem(
        danmaku: danmaku,
        track: track,
        startTime: DateTime.now(),
      );
      _activeItems.add(item);
      track.lastItem = item;
    } else {
      // 轨道已满，丢弃这条弹幕
      // print('[弹幕渲染] ⚠️  轨道已满，丢弃弹幕: ${danmaku.content}');
    }
  }
  
  _DanmakuTrack? _findAvailableScrollTrack() {
    final screenHeight = context.size!.height;
    final displayHeight = screenHeight * widget.config.displayArea;
    final trackHeight = widget.config.fontSize + 2;
    int maxTracks = (displayHeight / trackHeight).floor();
    
    if (maxTracks <= 0) return null;
    if (maxTracks > 50) maxTracks = 50; // 防御性限制最高满屏数量
    
    // 收集所有可用轨道的 index
    List<int> availableIndices = List.generate(maxTracks, (i) => i);
    
    for (var track in _scrollTracks) {
      if (track.index < maxTracks) {
        if (!track.isAvailable(context.size!.width)) {
          availableIndices.remove(track.index);
        } else {
          // 如果轨道可用，更新它的 y 坐标以防 fontSize 变化
          track.y = track.index * trackHeight;
        }
      }
    }
    
    if (availableIndices.isEmpty) {
      return null;
    }
    
    // 随机选择一个可用轨道，让弹幕均匀分布在设置的显示区域，而不是全部挤在最上方
    final targetIndex = availableIndices[math.Random().nextInt(availableIndices.length)];
    
    // 查找是否已经有该轨道的实例
    _DanmakuTrack? targetTrack;
    for (var track in _scrollTracks) {
      if (track.index == targetIndex) {
        targetTrack = track;
        break;
      }
    }
    
    if (targetTrack == null) {
      targetTrack = _DanmakuTrack(
        index: targetIndex,
        y: targetIndex * trackHeight,
      );
      _scrollTracks.add(targetTrack);
    }
    
    return targetTrack;
  }
  
  _DanmakuTrack? _findAvailableTopTrack() {
    final trackHeight = widget.config.fontSize + 10;
    final maxTracks = 3; // 最多3行顶部弹幕
    
    List<_DanmakuTrack> validAndFree = [];
    int maxExistingIndex = -1;
    
    for (var track in _topTracks) {
      if (track.index < maxTracks) {
        if (track.index > maxExistingIndex) maxExistingIndex = track.index;
        if (track.isAvailableFixed()) {
          track.y = track.index * trackHeight;
          validAndFree.add(track);
        }
      }
    }
    
    if (validAndFree.isNotEmpty) {
      validAndFree.sort((a, b) => a.index.compareTo(b.index));
      return validAndFree.first;
    }
    
    if (maxExistingIndex + 1 < maxTracks) {
      int nextIndex = maxExistingIndex + 1;
      final track = _DanmakuTrack(
        index: nextIndex,
        y: nextIndex * trackHeight,
      );
      _topTracks.add(track);
      return track;
    }
    
    return null;
  }
  
  _DanmakuTrack? _findAvailableBottomTrack() {
    final trackHeight = widget.config.fontSize + 10;
    final maxTracks = 3; // 最多3行底部弹幕
    
    List<_DanmakuTrack> validAndFree = [];
    int maxExistingIndex = -1;
    
    for (var track in _bottomTracks) {
      if (track.index < maxTracks) {
        if (track.index > maxExistingIndex) maxExistingIndex = track.index;
        if (track.isAvailableFixed()) {
          track.y = context.size!.height - ((track.index + 1) * trackHeight);
          validAndFree.add(track);
        }
      }
    }
    
    if (validAndFree.isNotEmpty) {
      validAndFree.sort((a, b) => a.index.compareTo(b.index));
      return validAndFree.first;
    }
    
    if (maxExistingIndex + 1 < maxTracks) {
      int nextIndex = maxExistingIndex + 1;
      final track = _DanmakuTrack(
        index: nextIndex,
        y: context.size!.height - ((nextIndex + 1) * trackHeight),
      );
      _bottomTracks.add(track);
      return track;
    }
    
    return null;
  }
  
  void _updateDanmaku() {
    for (var item in _activeItems) {
      item.update(context.size!.width, widget.config.speed);
    }
  }
  
  void _removeExpiredDanmaku() {
    _activeItems.removeWhere((item) => item.isExpired(context.size!.width));
  }
  
  @override
  Widget build(BuildContext context) {
    if (!widget.config.enabled) {
      print('[弹幕渲染] ⚠️  弹幕开关已关闭');
      return const SizedBox.shrink();
    }
    
    if (_activeItems.isEmpty && widget.danmakuList.isNotEmpty) {
      // 有弹幕数据但没有活跃项，可能是时间还没到
      // 不打印日志，避免刷屏
    }
    
    return IgnorePointer(
      child: Stack(
        children: _activeItems.map((item) {
          return Positioned(
            left: item.x,
            top: item.track.y,
            child: Opacity(
              opacity: widget.config.opacity,
              child: Text(
                item.danmaku.content,
                style: TextStyle(
                  color: Color(item.danmaku.color).withOpacity(1.0),
                  fontSize: widget.config.fontSize,
                  fontWeight: FontWeight.bold,
                  shadows: const [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 2,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 弹幕配置
class DanmakuConfig {
  final bool enabled;
  final double opacity;
  final double fontSize;
  final double speed;
  final double displayArea; // 显示区域（0.0-1.0）
  
  const DanmakuConfig({
    this.enabled = true,
    this.opacity = 0.8,
    this.fontSize = 25.0,
    this.speed = 1.0,
    this.displayArea = 1.0,
  });
  
  DanmakuConfig copyWith({
    bool? enabled,
    double? opacity,
    double? fontSize,
    double? speed,
    double? displayArea,
  }) {
    return DanmakuConfig(
      enabled: enabled ?? this.enabled,
      opacity: opacity ?? this.opacity,
      fontSize: fontSize ?? this.fontSize,
      speed: speed ?? this.speed,
      displayArea: displayArea ?? this.displayArea,
    );
  }
}

/// 弹幕项
class _DanmakuItem {
  final Danmaku danmaku;
  final _DanmakuTrack track;
  final DateTime startTime;
  
  double x = 0;
  double width = 0;
  
  _DanmakuItem({
    required this.danmaku,
    required this.track,
    required this.startTime,
  });
  
  void update(double screenWidth, double speed) {
    if (danmaku.type == DanmakuType.scroll) {
      // 滚动弹幕
      final elapsed = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      final duration = 15.0 / speed; // 15秒滚动完成（更慢）
      final progress = elapsed / duration;
      
      // 估算文字宽度
      width = danmaku.content.length * danmaku.fontSize * 0.6;
      
      // 从右侧进入，到左侧完全消失
      x = screenWidth - (screenWidth + width) * progress;
    } else {
      // 固定弹幕（顶部/底部）
      width = danmaku.content.length * danmaku.fontSize * 0.6;
      x = (screenWidth - width) / 2; // 居中
    }
  }
  
  bool isExpired(double screenWidth) {
    if (danmaku.type == DanmakuType.scroll) {
      // 滚动弹幕：完全移出屏幕
      return x + width < 0;
    } else {
      // 固定弹幕：显示5秒
      return DateTime.now().difference(startTime).inSeconds > 5;
    }
  }
}

/// 弹幕轨道
class _DanmakuTrack {
  final int index;
  double y;
  _DanmakuItem? lastItem;
  
  _DanmakuTrack({
    required this.index,
    required this.y,
  });
  
  bool isAvailable(double screenWidth) {
    if (lastItem == null) return true;
    
    // 检查上一条弹幕是否已经完全移出起始位置
    // 确保新弹幕不会和旧弹幕重叠
    final lastX = lastItem!.x;
    final lastWidth = lastItem!.width;
    
    // 上一条弹幕必须完全移出屏幕右侧，才能添加新弹幕
    // 或者上一条弹幕已经移动了足够远的距离（留更大的安全距离）
    return lastX + lastWidth < screenWidth - 150; // 增加到150px安全距离
  }
  
  bool isAvailableFixed() {
    if (lastItem == null) return true;
    
    // 固定弹幕：上一条显示超过1秒后可以添加新的
    return DateTime.now().difference(lastItem!.startTime).inSeconds >= 1;
  }
}
