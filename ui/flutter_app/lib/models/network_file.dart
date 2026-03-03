/// 网络文件/目录
class NetworkFile {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? modified;
  final String? mimeType;

  NetworkFile({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.modified,
    this.mimeType,
  });

  bool get isVideo {
    if (mimeType != null) {
      return mimeType!.startsWith('video/');
    }
    final ext = name.toLowerCase().split('.').last;
    return ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'm4v', 'ts', 'm2ts'].contains(ext);
  }

  bool get isAudio {
    if (mimeType != null) {
      return mimeType!.startsWith('audio/');
    }
    final ext = name.toLowerCase().split('.').last;
    return ['mp3', 'flac', 'wav', 'aac', 'm4a', 'ogg', 'wma'].contains(ext);
  }

  bool get isSubtitle {
    final ext = name.toLowerCase().split('.').last;
    return ['srt', 'ass', 'ssa', 'sub', 'vtt'].contains(ext);
  }

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
