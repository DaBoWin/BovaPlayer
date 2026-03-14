import 'package:flutter/material.dart';

import '../../core/theme/design_system.dart';
import '../../core/theme/bova_icons.dart';
import '../../l10n/generated/app_localizations.dart';
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

MediaSourceVisual mediaSourceVisual(SourceType type, {BuildContext? context}) {
  final l10n = context != null ? S.of(context) : null;
  switch (type) {
    case SourceType.emby:
      return MediaSourceVisual(
        icon: BovaIcons.cloudOutline,
        primary: DesignSystem.accent600,
        secondary: DesignSystem.accent400,
        label: 'Emby',
        description: l10n?.mediaTypeEmbyService ?? 'Media service and metadata management',
      );
    case SourceType.smb:
      return MediaSourceVisual(
        icon: BovaIcons.folderOutline,
        primary: const Color(0xFFB45309),
        secondary: const Color(0xFFF59E0B),
        label: 'SMB',
        description: l10n?.mediaTypeSmbShare ?? 'LAN shared directory browsing',
      );
    case SourceType.ftp:
      return MediaSourceVisual(
        icon: BovaIcons.uploadOutline,
        primary: const Color(0xFF047857),
        secondary: const Color(0xFF34D399),
        label: 'FTP',
        description: l10n?.mediaTypeFtpServer ?? 'Remote file server access',
      );
  }
}

MediaFileVisual mediaFileVisual(NetworkFile item, {BuildContext? context}) {
  final l10n = context != null ? S.of(context) : null;
  if (item.isDirectory) {
    return MediaFileVisual(
      icon: BovaIcons.folderOutline,
      color: const Color(0xFFD97706),
      label: l10n?.mediaTypeFolder ?? 'Folder',
    );
  }
  if (item.isVideo) {
    return MediaFileVisual(
      icon: BovaIcons.playerOutline,
      color: DesignSystem.accent600,
      label: l10n?.mediaTypeVideo ?? 'Video',
    );
  }
  if (item.isAudio) {
    return MediaFileVisual(
      icon: Icons.music_note_outlined,
      color: DesignSystem.success,
      label: l10n?.mediaTypeAudio ?? 'Audio',
    );
  }
  if (item.isSubtitle) {
    return MediaFileVisual(
      icon: Icons.subtitles_outlined,
      color: const Color(0xFF7C3AED),
      label: l10n?.mediaTypeSubtitle ?? 'Subtitle',
    );
  }
  return MediaFileVisual(
    icon: Icons.insert_drive_file_outlined,
    color: DesignSystem.neutral500,
    label: l10n?.mediaTypeFile ?? 'File',
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

String sourceDetailLabel(MediaSource source, {BuildContext? context}) {
  final l10n = context != null ? S.of(context) : null;
  switch (source.type) {
    case SourceType.emby:
      return source.username.isEmpty
          ? (l10n?.mediaTypeUsernameNotSet ?? 'Username not set')
          : (l10n?.mediaTypeUser(source.username) ?? 'User ${source.username}');
    case SourceType.smb:
      final shareName = source.shareName?.trim();
      return shareName == null || shareName.isEmpty
          ? (l10n?.mediaTypeShareNotSet ?? 'Share name not set')
          : (l10n?.mediaTypeShare(shareName) ?? 'Share $shareName');
    case SourceType.ftp:
      return source.username.isEmpty
          ? (l10n?.mediaTypeAnonymous ?? 'Anonymous access')
          : (l10n?.mediaTypeUser(source.username) ?? 'User ${source.username}');
  }
}
