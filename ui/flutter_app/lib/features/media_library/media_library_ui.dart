import 'package:flutter/material.dart';

import '../../core/theme/design_system.dart';
import '../../core/theme/bova_icons.dart';
import '../../models/network_file.dart';
import 'models/media_source.dart';

class MediaSourceVisual {
  final IconData icon;
  final Color primary;
  final Color secondary;
  final String label;
  final String description;

  const MediaSourceVisual({
    required this.icon,
    required this.primary,
    required this.secondary,
    required this.label,
    required this.description,
  });
}

class MediaFileVisual {
  final IconData icon;
  final Color color;
  final String label;

  const MediaFileVisual({
    required this.icon,
    required this.color,
    required this.label,
  });
}

MediaSourceVisual mediaSourceVisual(SourceType type) {
  switch (type) {
    case SourceType.emby:
      return const MediaSourceVisual(
        icon: BovaIcons.cloudOutline,
        primary: DesignSystem.accent600,
        secondary: DesignSystem.accent400,
        label: 'Emby',
        description: '媒体服务与元数据管理',
      );
    case SourceType.smb:
      return const MediaSourceVisual(
        icon: BovaIcons.folderOutline,
        primary: Color(0xFFB45309),
        secondary: Color(0xFFF59E0B),
        label: 'SMB',
        description: '局域网共享目录浏览',
      );
    case SourceType.ftp:
      return const MediaSourceVisual(
        icon: BovaIcons.uploadOutline,
        primary: Color(0xFF047857),
        secondary: Color(0xFF34D399),
        label: 'FTP',
        description: '远程文件服务器访问',
      );
  }
}

MediaFileVisual mediaFileVisual(NetworkFile item) {
  if (item.isDirectory) {
    return const MediaFileVisual(
      icon: BovaIcons.folderOutline,
      color: Color(0xFFD97706),
      label: '文件夹',
    );
  }
  if (item.isVideo) {
    return const MediaFileVisual(
      icon: BovaIcons.playerOutline,
      color: DesignSystem.accent600,
      label: '视频',
    );
  }
  if (item.isAudio) {
    return const MediaFileVisual(
      icon: Icons.music_note_outlined,
      color: DesignSystem.success,
      label: '音频',
    );
  }
  if (item.isSubtitle) {
    return const MediaFileVisual(
      icon: Icons.subtitles_outlined,
      color: Color(0xFF7C3AED),
      label: '字幕',
    );
  }
  return const MediaFileVisual(
    icon: Icons.insert_drive_file_outlined,
    color: DesignSystem.neutral500,
    label: '文件',
  );
}

String formatMediaLibraryTime(DateTime dateTime) {
  final year = dateTime.year.toString().padLeft(4, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}

String sourceEndpointLabel(MediaSource source) {
  if (source.type == SourceType.emby) {
    return source.url;
  }
  final uri = Uri.tryParse(source.url);
  if (uri == null) {
    return source.url;
  }
  return '${uri.host}:${uri.hasPort ? uri.port : ''}'
      .replaceAll(RegExp(r':$'), '');
}

String sourceDetailLabel(MediaSource source) {
  switch (source.type) {
    case SourceType.emby:
      return source.username.isEmpty ? '未填写用户名' : '用户 ${source.username}';
    case SourceType.smb:
      final shareName = source.shareName?.trim();
      return shareName == null || shareName.isEmpty
          ? '未指定共享名'
          : '共享 $shareName';
    case SourceType.ftp:
      return source.username.isEmpty ? '匿名访问' : '用户 ${source.username}';
  }
}
