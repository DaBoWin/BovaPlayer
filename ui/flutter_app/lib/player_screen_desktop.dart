import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'native_bridge.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _isPlaying = false;
  bool _hwAccelEnabled = true;
  String _currentFile = '';
  double _currentPosition = 0;
  double _totalDuration = 0;
  VideoPlayerController? _videoController;
  bool _isLoading = false;
  String? _loadingError;
  String? _errorMessage;
  bool _hasVideo = false;
  String _loadingMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeNativeBridge();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeNativeBridge() async {
    try {
      final result = await NativeBridge.initialize();
      print('Native bridge初始化结果: $result');
    } catch (e) {
      print('Native bridge初始化失败: $e');
    }
  }

  void _videoPlayerListener() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      setState(() {
        _currentPosition = _videoController!.value.position.inSeconds.toDouble();
        _isPlaying = _videoController!.value.isPlaying;
      });
    }
  }

  Future<void> _openFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final filePath = file.path!;
        final fileSizeInMB = (file.size / (1024 * 1024));
        
        print('选择的文件: ${file.name}, 路径: $filePath, 大小: ${file.size}字节');
        
        setState(() {
          _isLoading = true;
          _hasVideo = false;
          _errorMessage = null;
          _loadingMessage = fileSizeInMB > 1000 
            ? '正在加载 ${(fileSizeInMB/1024).toStringAsFixed(1)} GB 视频文件...'
            : '正在加载 ${fileSizeInMB.toStringAsFixed(1)} MB 视频文件...';
        });
        
        try {
          // 释放之前的视频控制器
          _videoController?.dispose();
          
          // 创建视频播放器控制器，直接使用文件路径
          _videoController = VideoPlayerController.file(
            File(filePath),
            videoPlayerOptions: VideoPlayerOptions(
              mixWithOthers: true,
              allowBackgroundPlayback: false,
            ),
          );
          
          // 初始化视频播放器
          await _videoController!.initialize();
          _videoController!.addListener(_videoPlayerListener);
          
          setState(() {
            _isLoading = false;
            _hasVideo = true;
            _currentFile = file.name;
            _totalDuration = _videoController!.value.duration.inSeconds.toDouble();
          });
          
          // 显示成功消息
          if (mounted) {
            final sizeText = fileSizeInMB > 1024 
                ? '${(fileSizeInMB / 1024).toStringAsFixed(1)} GB'
                : '${fileSizeInMB.toStringAsFixed(1)} MB';
                
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('视频加载成功: ${file.name} ($sizeText)'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          
          // 同时调用Native Bridge（用于日志记录）
          final config = '{"hardware_accel": $_hwAccelEnabled}';
          final openResult = await NativeBridge.openMedia(filePath, config);
          print('Native Bridge打开文件结果: $openResult');
          
        } catch (e) {
          print('视频初始化失败: $e');
          setState(() {
            _isLoading = false;
            _errorMessage = '视频初始化失败: $e';
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('视频加载失败: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      } else {
        print('用户取消了文件选择');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未选择文件')),
          );
        }
      }
    } catch (e) {
      print('文件选择错误: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '文件选择失败: $e';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('文件选择失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePlay() async {
    if (_videoController != null && _videoController!.value.isInitialized) {
      if (_videoController!.value.isPlaying) {
        await _videoController!.pause();
        print('视频暂停');
      } else {
        await _videoController!.play();
        print('视频播放');
      }
    }
  }

  Future<void> _stop() async {
    if (_videoController != null && _videoController!.value.isInitialized) {
      await _videoController!.pause();
      await _videoController!.seekTo(Duration.zero);
      print('视频停止');
    }
  }

  Future<void> _seekToPosition(double position) async {
    if (_videoController != null && _videoController!.value.isInitialized) {
      await _videoController!.seekTo(Duration(seconds: position.toInt()));
      print('视频跳转到: ${position}s');
    }
  }

  Widget _buildVideoRenderer() {
    if (_currentFile.isEmpty && !_isLoading) {
      return Container(
        width: double.infinity,
        height: 400,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_library, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('请选择视频文件', style: TextStyle(fontSize: 18, color: Colors.grey)),
              SizedBox(height: 8),
              Text('支持 MP4, AVI, MOV 等格式', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('支持大文件播放', style: TextStyle(fontSize: 12, color: Colors.green)),
            ],
          ),
        ),
      );
    }

    // 如果有视频控制器且已初始化，显示真正的视频
    if (_videoController != null && _videoController!.value.isInitialized && _hasVideo) {
      return Container(
        width: double.infinity,
        height: 400,
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),
        ),
      );
    }

    // 如果有错误消息，显示错误状态
    if (_errorMessage != null) {
      return Container(
        width: double.infinity,
        height: 400,
        decoration: BoxDecoration(
          color: Colors.red[50],
          border: Border.all(color: Colors.red[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            const Text(
              '视频加载失败',
              style: TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _currentFile,
              style: TextStyle(color: Colors.red[700], fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _currentFile = '';
                  _errorMessage = null;
                  _isLoading = false;
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重新选择文件'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // 显示加载中状态
    if (_isLoading) {
      return Container(
        width: double.infinity,
        height: 400,
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    color: Colors.blue,
                    strokeWidth: 4,
                  ),
                ),
                Icon(
                  Icons.video_file,
                  size: 40,
                  color: Colors.white70,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _loadingMessage,
              style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _currentFile,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    // 默认状态
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text('未知状态', style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  Widget _buildProgressBar() {
    double maxDuration = _totalDuration;
    double currentPos = _currentPosition;
    
    // 如果有视频控制器，使用其数据
    if (_videoController != null && _videoController!.value.isInitialized) {
      maxDuration = _videoController!.value.duration.inSeconds.toDouble();
      currentPos = _videoController!.value.position.inSeconds.toDouble();
    }
    
    return Column(
      children: [
        Slider(
          value: currentPos.clamp(0.0, maxDuration),
          min: 0,
          max: maxDuration > 0 ? maxDuration : 1,
          onChanged: _seekToPosition,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(currentPos ~/ 60).toString().padLeft(2, '0')}:${(currentPos % 60).toInt().toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                '${(maxDuration ~/ 60).toString().padLeft(2, '0')}:${(maxDuration % 60).toInt().toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BovaPlayer - 桌面版'),
        actions: [
          Switch(
            value: _hwAccelEnabled,
            onChanged: (value) async {
              setState(() {
                _hwAccelEnabled = value;
              });
              final result = await NativeBridge.setHardwareAccel(value);
              print('硬件加速设置结果: $result');
            },
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Text('硬件加速'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _buildVideoRenderer(),
            ),
          ),
          _buildProgressBar(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _openFile,
                  child: const Text('打开文件'),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: _togglePlay,
                  iconSize: 36,
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: _stop,
                  iconSize: 36,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}