import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'player_screen_desktop.dart' as desktop;
import 'player_screen_mobile.dart' as mobile;
import 'player_screen_web_stub.dart'
    if (dart.library.html) 'player_screen_web.dart' as web;

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const web.WebPlayerScreen();
    }

    final platform = Theme.of(context).platform;
    final isMobilePlatform =
        platform == TargetPlatform.iOS || platform == TargetPlatform.android;

    return isMobilePlatform
        ? const mobile.PlayerScreen()
        : const desktop.PlayerScreen();
  }
}
