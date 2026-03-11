import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/services/auth_service.dart';
import '../features/auth/presentation/providers/auth_provider.dart'
    as auth_provider;
import '../mdk_player_page.dart';
import '../unified_player_page.dart';

const String kMainAppWindowType = 'main';
const String kPlayerAppWindowType = 'player';

bool get supportsDetachedPlayerWindow => !kIsWeb && Platform.isMacOS;

class AppWindowArguments {
  const AppWindowArguments({required this.type, this.payload});

  final String type;
  final Map<String, dynamic>? payload;

  factory AppWindowArguments.main() =>
      const AppWindowArguments(type: kMainAppWindowType);

  factory AppWindowArguments.player(DesktopPlayerPayload payload) =>
      AppWindowArguments(type: kPlayerAppWindowType, payload: payload.toJson());

  Map<String, dynamic> toJson() => {
        'type': type,
        if (payload != null) 'payload': payload,
      };

  static AppWindowArguments? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return AppWindowArguments.main();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return AppWindowArguments.main();
      final type = decoded['type'] as String? ?? kMainAppWindowType;
      final payload = decoded['payload'];
      return AppWindowArguments(
        type: type,
        payload: payload is Map<String, dynamic>
            ? payload
            : payload is Map
                ? payload.cast<String, dynamic>()
                : null,
      );
    } catch (_) {
      return AppWindowArguments.main();
    }
  }
}

class DesktopPlayerPayload {
  const DesktopPlayerPayload({
    required this.url,
    required this.title,
    this.httpHeaders,
    this.subtitles,
    this.itemId,
    this.serverUrl,
    this.accessToken,
    this.userId,
    this.startPositionMs,
    this.startTimeTicks,
  });

  final String url;
  final String title;
  final Map<String, String>? httpHeaders;
  final List<Map<String, String>>? subtitles;
  final String? itemId;
  final String? serverUrl;
  final String? accessToken;
  final String? userId;
  final int? startPositionMs;
  final int? startTimeTicks;

  Duration? get startPosition =>
      startPositionMs == null ? null : Duration(milliseconds: startPositionMs!);

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        if (httpHeaders != null) 'httpHeaders': httpHeaders,
        if (subtitles != null) 'subtitles': subtitles,
        if (itemId != null) 'itemId': itemId,
        if (serverUrl != null) 'serverUrl': serverUrl,
        if (accessToken != null) 'accessToken': accessToken,
        if (userId != null) 'userId': userId,
        if (startPositionMs != null) 'startPositionMs': startPositionMs,
        if (startTimeTicks != null) 'startTimeTicks': startTimeTicks,
      };

  factory DesktopPlayerPayload.fromJson(Map<String, dynamic> json) {
    Map<String, String>? parseStringMap(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value.map((key, value) => MapEntry(key, value.toString()));
      }
      if (value is Map) {
        return value.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      }
      return null;
    }

    List<Map<String, String>>? parseSubtitleList(dynamic value) {
      if (value is! List) return null;
      return value.map<Map<String, String>>((item) {
        if (item is Map<String, dynamic>) {
          return item.map((key, value) => MapEntry(key, value.toString()));
        }
        if (item is Map) {
          return item.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          );
        }
        return <String, String>{};
      }).toList();
    }

    return DesktopPlayerPayload(
      url: json['url'] as String? ?? '',
      title: json['title'] as String? ?? 'BovaPlayer',
      httpHeaders: parseStringMap(json['httpHeaders']),
      subtitles: parseSubtitleList(json['subtitles']),
      itemId: json['itemId'] as String?,
      serverUrl: json['serverUrl'] as String?,
      accessToken: json['accessToken'] as String?,
      userId: json['userId'] as String?,
      startPositionMs: (json['startPositionMs'] as num?)?.toInt(),
      startTimeTicks: (json['startTimeTicks'] as num?)?.toInt(),
    );
  }
}

enum PlayerLaunchMode {
  inline,
  detachedWindow,
}

class DesktopPlayerLauncher {
  const DesktopPlayerLauncher._();

  static Future<PlayerLaunchMode> openPlayer({
    required BuildContext context,
    required String url,
    required String title,
    Map<String, String>? httpHeaders,
    List<Map<String, String>>? subtitles,
    String? itemId,
    String? serverUrl,
    String? accessToken,
    String? userId,
    Duration? startPosition,
    int? startTimeTicks,
  }) async {
    if (supportsDetachedPlayerWindow) {
      final payload = DesktopPlayerPayload(
        url: url,
        title: title,
        httpHeaders: httpHeaders,
        subtitles: subtitles,
        itemId: itemId,
        serverUrl: serverUrl,
        accessToken: accessToken,
        userId: userId,
        startPositionMs: startPosition?.inMilliseconds,
        startTimeTicks: startTimeTicks,
      );
      final controller = await WindowController.create(
        WindowConfiguration(
          hiddenAtLaunch: true,
          arguments: jsonEncode(AppWindowArguments.player(payload).toJson()),
        ),
      );
      await controller.show();
      return PlayerLaunchMode.detachedWindow;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UnifiedPlayerPage(
          url: url,
          title: title,
          httpHeaders: httpHeaders,
          subtitles: subtitles,
          itemId: itemId,
          serverUrl: serverUrl,
          accessToken: accessToken,
          userId: userId,
          startPosition: startPosition,
          startTimeTicks: startTimeTicks,
        ),
      ),
    );
    return PlayerLaunchMode.inline;
  }
}

WindowOptions mainWindowOptions() => const WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'BovaPlayer',
    );

WindowOptions playerWindowOptions(DesktopPlayerPayload payload) =>
    WindowOptions(
      size: const Size(1440, 900),
      minimumSize: const Size(960, 540),
      center: true,
      backgroundColor: Colors.black,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: true,
      title: payload.title.isEmpty ? 'BovaPlayer' : payload.title,
    );

class DesktopPlayerWindowApp extends StatelessWidget {
  const DesktopPlayerWindowApp({super.key, required this.payload});

  final DesktopPlayerPayload payload;

  @override
  Widget build(BuildContext context) {
    final authRepository = AuthRepositoryImpl();
    final authService = AuthService(authRepository);

    return ChangeNotifierProvider(
      create: (_) => auth_provider.AuthProvider(authService),
      child: MaterialApp(
        title: payload.title,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: MdkPlayerPage(
          url: payload.url,
          title: payload.title,
          httpHeaders: payload.httpHeaders,
          subtitles: payload.subtitles,
          itemId: payload.itemId,
          serverUrl: payload.serverUrl,
          accessToken: payload.accessToken,
          userId: payload.userId,
          isSubWindow: true,
          startPosition: payload.startPosition,
          startTimeTicks: payload.startTimeTicks,
        ),
      ),
    );
  }
}
