import 'dart:async';
import 'dart:ffi';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'bova_native.dart';

class BovaNativePlugin {
  static const MethodChannel _channel = MethodChannel('bova_native');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  /// 初始化原生库
  static Future<void> initialize() async {
    try {
      // 测试库是否可加载
      final version = BovaNative.getVersion();
      debugPrint('BovaNative initialized: $version');
    } catch (e) {
      debugPrint('Failed to initialize BovaNative: $e');
      rethrow;
    }
  }
}