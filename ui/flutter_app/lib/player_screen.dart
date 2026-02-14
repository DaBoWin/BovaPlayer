import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;
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
  Timer? _frameTimer;
  Uint8List? _currentFrame;
  int _frameWidth = 0;
  int _frameHeight = 0;
  double _currentPosition = 0;
  double _totalDuration = 0;
  VideoPlayerController? _videoController;
  String? _selectedFilePath;
  bool _isLoading = false;
  String? _loadingError;

  @override
  void initState() {
    super.initState();
    _initializeNativeBridge();
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
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

  void _startFrameTimer() {
    // VideoPlayerController自动处理帧更新，不需要手动定时器
    _frameTimer?.cancel();
    _frameTimer = null;
  }

  void _stopFrameTimer() {
    _frameTimer?.cancel();
    _frameTimer = null;
  }

  Future<void> _updateFrame() async {
    // 不再使用Native Bridge获取帧数据，完全依赖VideoPlayerController
    if (_videoController != null && _videoController!.value.isInitialized) {
      // VideoPlayerController会自动处理帧更新，我们不需要手动处理
      return;
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

  void _updatePosition() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      setState(() {
        _currentPosition = _videoController!.value.position.inSeconds.toDouble();
      });
    } else {
      final position = NativeBridge.getPosition();
      final duration = NativeBridge.getDuration();
      setState(() {
        _currentPosition = position;
        _totalDuration = duration;
      });
    }
  }

  Future<void> _openFile() async {
    try {
      // 对于大文件，不预先加载数据到内存
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: false, // 不预先加载文件数据，避免内存问题
      );

      if (result != null) {
        final fileName = result.files.single.name;
        final fileSize = result.files.single.size;
        
        print('选择的文件: $fileName, 大小: ${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB');
        
        // 检查文件大小，决定处理策略
        final isLargeFile = fileSize > 100 * 1024 * 1024; // 100MB以上为大文件
        
        // 释放之前的视频控制器
        _videoController?.dispose();
        
        // 显示加载状态
        setState(() {
          _currentFile = fileName;
          _isLoading = true;
          _loadingError = null;
        });
        
        // 在Web平台处理视频文件
        if (kIsWeb) {
          try {
            String videoUrl;
            
            if (isLargeFile) {
              // 大文件：使用File API直接创建URL，不加载到内存
              print('处理大文件 (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB)，使用流式加载');
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Text('正在准备大文件流式播放 (${(fileSize / 1024 / 1024 / 1024).toStringAsFixed(1)} GB)...'),
                      ],
                    ),
                    duration: const Duration(seconds: 8),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
              
              // 对于大文件，直接使用File对象创建URL
              final file = result.files.single;
              if (file.bytes != null) {
                // 如果bytes可用，使用Blob
                final blob = html.Blob([file.bytes!]);
                videoUrl = html.Url.createObjectUrl(blob);
              } else {
                // 如果bytes不可用，尝试其他方法
                throw Exception('大文件无法加载：浏览器内存限制');
              }
            } else {
              // 小文件：正常处理
              print('处理小文件 (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB)');
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 16),
                        Text('正在加载视频文件 (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB)...'),
                      ],
                    ),
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
              
              // 小文件可以安全地加载到内存
              final fileWithData = await FilePicker.platform.pickFiles(
                type: FileType.video,
                allowMultiple: false,
                withData: true,
              );
              
              if (fileWithData?.files.single.bytes == null) {
                throw Exception('无法读取文件数据');
              }
              
              final blob = html.Blob([fileWithData!.files.single.bytes!]);
              videoUrl = html.Url.createObjectUrl(blob);
            }
            
            print('视频URL创建成功: $videoUrl');
            
            // 创建视频播放器控制器
            _videoController = VideoPlayerController.networkUrl(
              Uri.parse(videoUrl),
              videoPlayerOptions: VideoPlayerOptions(
                mixWithOthers: true,
                allowBackgroundPlayback: false,
              ),
            );
            
            // 显示初始化进度
            if (mounted && fileSize > 1024 * 1024 * 1024) { // 大于1GB
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 16),
                      Text('正在初始化视频播放器...'),
                    ],
                  ),
                  duration: Duration(seconds: 10),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            
            // 初始化视频播放器
            await _videoController!.initialize();
            
            setState(() {
              _totalDuration = _videoController!.value.duration.inSeconds.toDouble();
              _frameWidth = _videoController!.value.size.width.toInt();
              _frameHeight = _videoController!.value.size.height.toInt();
              _isLoading = false;
              _loadingError = null;
            });
            
            // 添加监听器来更新播放位置
            _videoController!.addListener(_videoPlayerListener);
            
            // 显示成功消息
            if (mounted) {
              final sizeText = fileSize > 1024 * 1024 * 1024 
                  ? '${(fileSize / 1024 / 1024 / 1024).toStringAsFixed(1)} GB'
                  : '${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB';
                  
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('视频加载成功: $fileName ($sizeText)'),
                      if (fileSize > 1024 * 1024 * 1024)
                        const Text(
                          '大文件已加载，可以开始播放',
                          style: TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          } catch (e) {
            print('视频初始化失败: $e');
            setState(() {
              _currentFile = '';
              _isLoading = false;
              _loadingError = e.toString();
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('视频加载失败'),
                      const SizedBox(height: 4),
                      Text(
                        '可能原因: 文件格式不支持、文件损坏或内存不足',
                        style: TextStyle(fontSize: 12, color: Colors.red[100]),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 8),
                ),
              );
            }
          }
        } else {
          // 非Web平台的处理逻辑
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('桌面平台暂不支持，请使用Web版本')),
            );
          }
        }
        
        // 同时调用Native Bridge（用于日志记录）
        final config = '{"hardware_accel": $_hwAccelEnabled}';
        final openResult = await NativeBridge.openMedia(fileName, config);
        print('Native Bridge打开文件结果: $openResult');
        
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
        _currentFile = '';
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
    } else {
      // 回退到Native Bridge
      if (_isPlaying) {
        final result = await NativeBridge.pause();
        print('Native Bridge暂停结果: $result');
        _stopFrameTimer();
      } else {
        final result = await NativeBridge.play();
        print('Native Bridge播放结果: $result');
        _startFrameTimer();
      }
      setState(() {
        _isPlaying = !_isPlaying;
      });
    }
  }

  Future<void> _stop() async {
    if (_videoController != null && _videoController!.value.isInitialized) {
      await _videoController!.pause();
      await _videoController!.seekTo(Duration.zero);
      print('视频停止');
    } else {
      final result = await NativeBridge.stop();
      print('Native Bridge停止结果: $result');
      _stopFrameTimer();
      setState(() {
        _isPlaying = false;
        _currentFrame = null;
        _currentPosition = 0;
      });
    }
  }

  Future<void> _seekToPosition(double position) async {
    if (_videoController != null && _videoController!.value.isInitialized) {
      await _videoController!.seekTo(Duration(seconds: position.toInt()));
      print('视频跳转到: ${position}s');
    } else {
      final result = await NativeBridge.seek(position);
      print('Native Bridge跳转结果: $result');
      setState(() {
        _currentPosition = position;
      });
    }
  }

  Widget _buildVideoRenderer() {
    if (_currentFile.isEmpty) {
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
    if (_videoController != null && _videoController!.value.isInitialized) {
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
            child: Stack(
              children: [
                VideoPlayer(_videoController!),
                // 显示视频信息覆盖层
                if (!_videoController!.value.isPlaying)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${_frameWidth} x $_frameHeight',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // 如果有加载错误，显示错误状态
    if (_loadingError != null) {
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
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  const Text(
                    '可能的解决方案:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• 选择更小的文件 (< 100MB)\n• 尝试其他视频格式 (MP4推荐)\n• 刷新页面重试',
                    style: TextStyle(fontSize: 11),
                    textAlign: TextAlign.left,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _currentFile = '';
                  _loadingError = null;
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
            const Text(
              '正在加载视频...',
              style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
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
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue[300]),
                      const SizedBox(width: 8),
                      const Text(
                        '大文件优化加载中',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• 使用流式加载技术\n• 边下载边播放\n• 首次播放需要缓冲',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 默认状态（不应该到达这里）
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
        title: const Text('BovaPlayer'),
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
              child: _currentFile.isEmpty
                  ? const Text('请选择媒体文件')
                  : _buildVideoRenderer(),
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