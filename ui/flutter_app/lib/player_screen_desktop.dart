import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  Player? _player;
  VideoController? _videoController;
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasVideo = false;
  String _currentFile = '';

  @override
  void initState() {
    super.initState();
    
    // 创建播放器时配置
    _player = Player(
      configuration: const PlayerConfiguration(
        title: '本地播放器',
      ),
    );
    _videoController = VideoController(_player!);
    
    // 监听播放器状态
    _player!.stream.playing.listen((playing) {
      print('[PlayerScreen] 播放状态变化: $playing');
    });
    
    _player!.stream.buffering.listen((buffering) {
      print('[PlayerScreen] 缓冲状态: $buffering');
    });
    
    _player!.stream.error.listen((error) {
      print('[PlayerScreen] 播放器错误: $error');
      if (mounted) {
        setState(() {
          _errorMessage = '播放错误: $error';
          _isLoading = false;
        });
      }
    });
    
    _player!.stream.width.listen((width) {
      print('[PlayerScreen] 视频宽度: $width');
    });
    
    _player!.stream.height.listen((height) {
      print('[PlayerScreen] 视频高度: $height');
    });
    
    _player!.stream.duration.listen((duration) {
      print('[PlayerScreen] 视频时长: $duration');
    });
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _pickAndPlayFile() async {
    try {
      print('[PlayerScreen] 开始选择文件...');
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any, // 改为 any 以便测试
        allowMultiple: false,
        dialogTitle: '选择视频文件',
      );
      
      print('[PlayerScreen] 文件选择结果: ${result != null ? "有结果" : "无结果"}');
      
      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final filePath = file.path!;
        
        print('[PlayerScreen] 选择的文件: $filePath');
        print('[PlayerScreen] 文件名: ${file.name}');
        print('[PlayerScreen] 文件大小: ${file.size} bytes');

        setState(() {
          _isLoading = true;
          _hasVideo = false;
          _errorMessage = null;
        });

        try {
          print('[PlayerScreen] 打开媒体文件...');
          await _player!.open(Media(filePath));
          
          print('[PlayerScreen] 开始播放...');
          await _player!.play();

          print('[PlayerScreen] 播放成功！');
          setState(() {
            _isLoading = false;
            _hasVideo = true;
            _currentFile = file.name;
          });
        } catch (e, stackTrace) {
          print('[PlayerScreen] 视频加载失败: $e');
          print('[PlayerScreen] 堆栈: $stackTrace');
          
          setState(() {
            _isLoading = false;
            _errorMessage = '视频加载失败: $e';
          });
        }
      } else {
        print('[PlayerScreen] 用户取消选择或没有选择文件');
      }
    } catch (e, stackTrace) {
      print('[PlayerScreen] 文件选择异常: $e');
      print('[PlayerScreen] 堆栈: $stackTrace');
      
      setState(() {
        _isLoading = false;
        _errorMessage = '文件选择失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('本地播放'),
        backgroundColor: const Color(0xFF16213E),
        actions: [
          if (_hasVideo)
            IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: _pickAndPlayFile,
              tooltip: '选择其他文件',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.deepPurple),
            SizedBox(height: 16),
            Text(
              '正在加载视频...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickAndPlayFile,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (!_hasVideo) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 120,
              color: Colors.deepPurple.shade200,
            ),
            const SizedBox(height: 24),
            const Text(
              '选择视频文件开始播放',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickAndPlayFile,
              icon: const Icon(Icons.folder_open, size: 24),
              label: const Text(
                '选择文件',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 显示视频播放器
    return Column(
      children: [
        // 文件信息栏
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF16213E),
          child: Row(
            children: [
              const Icon(Icons.play_circle_outline, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentFile,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // 视频播放器
        Expanded(
          child: Container(
            color: Colors.black,
            child: _videoController != null
                ? AspectRatio(
                    aspectRatio: 16 / 9, // 默认宽高比
                    child: Video(
                      controller: _videoController!,
                      controls: MaterialDesktopVideoControls,
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
          ),
        ),
      ],
    );
  }
}
