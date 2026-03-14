// ignore_for_file: depend_on_referenced_packages

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'core/theme/app_theme.dart';
import 'l10n/generated/app_localizations.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasVideo = false;
  String _currentFile = '';

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _pickAndPlayFile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        if (filePath != null) {
          await _playFile(filePath);
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[PlayerScreen] File pick error: $e');
      setState(() {
        _errorMessage = S.of(context).playerFilePickError(e.toString());
        _isLoading = false;
      });
    }
  }

  Future<void> _playFile(String filePath) async {
    try {
      debugPrint('[PlayerScreen] Playing file: $filePath');

      await _controller?.dispose();

      _controller = VideoPlayerController.file(File(filePath));

      await _controller!.initialize();
      await _controller!.play();

      setState(() {
        _hasVideo = true;
        _currentFile = filePath.split('/').last;
        _isLoading = false;
        _errorMessage = null;
      });

      debugPrint('[PlayerScreen] Playback started');
    } catch (e) {
      debugPrint('[PlayerScreen] Playback failed: $e');
      setState(() {
        _errorMessage = S.of(context).playerPlayFailed(e.toString());
        _isLoading = false;
        _hasVideo = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final scheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              S.of(context).playerLoading,
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5), fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: scheme.error, size: 64),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: scheme.error, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text(S.of(context).playerRetry),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.buttonAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: _pickAndPlayFile,
            ),
          ],
        ),
      );
    }

    if (!_hasVideo || _controller == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.14),
              ),
              child: Icon(
                Icons.video_library_outlined,
                size: 60,
                color: scheme.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              S.of(context).playerNoVideo,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              S.of(context).playerNoVideoHint,
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.38), fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: Text(S.of(context).playerSelectFile),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.buttonAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: _pickAndPlayFile,
            ),
          ],
        ),
      );
    }

    // Video player view
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: scheme.surfaceContainerHighest,
          child: Text(
            _currentFile,
            style: TextStyle(color: scheme.onSurface, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(_controller!),
                  Positioned(
                    bottom: 16,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _controller!.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            color: Colors.white,
                            size: 48,
                          ),
                          onPressed: () {
                            setState(() {
                              if (_controller!.value.isPlaying) {
                                _controller!.pause();
                              } else {
                                _controller!.play();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
