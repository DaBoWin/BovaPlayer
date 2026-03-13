import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'window_native_tools.dart';

const String kMainWindowChannelName = 'bovaplayer/main_window';

const WindowMethodChannel _mainWindowChannel = WindowMethodChannel(
  kMainWindowChannelName,
  mode: ChannelMode.unidirectional,
);
const MethodChannel _windowControlChannel =
    MethodChannel('bovaplayer/window_control');

Future<void> ensureMainWindowInteractive(String source) async {
  final beforeMinimized = await windowManager.isMinimized();
  final beforeVisible = await windowManager.isVisible();
  final beforeFocused = await windowManager.isFocused();
  print(
    '[MainWindowChannel] $source before: '
    'minimized=$beforeMinimized visible=$beforeVisible focused=$beforeFocused',
  );
  releaseMouseCapture();
  ensureForegroundWindowInteractive();
  await windowManager.setIgnoreMouseEvents(false);
  if (beforeMinimized) {
    await windowManager.restore();
  }
  await windowManager.show();
  await windowManager.focus();
  try {
    await _windowControlChannel.invokeMethod('reactivateFlutterView');
  } catch (error) {
    print('[MainWindowChannel] reactivateFlutterView failed: $error');
  }
  releaseMouseCapture();
  ensureForegroundWindowInteractive();
  final afterMinimized = await windowManager.isMinimized();
  final afterVisible = await windowManager.isVisible();
  final afterFocused = await windowManager.isFocused();
  print(
    '[MainWindowChannel] $source after: '
    'minimized=$afterMinimized visible=$afterVisible focused=$afterFocused',
  );
}

Future<void> registerMainWindowChannel() {
  return _mainWindowChannel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'focus':
        await ensureMainWindowInteractive('focus request received');
        return null;
      default:
        throw MissingPluginException(
          'Not implemented main window method: ${call.method}',
        );
    }
  });
}

Future<void> requestMainWindowFocus() {
  print('[MainWindowChannel] sending focus request to main window');
  return _mainWindowChannel.invokeMethod('focus');
}
