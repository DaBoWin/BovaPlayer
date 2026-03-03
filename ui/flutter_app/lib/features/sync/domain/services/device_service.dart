import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// 设备服务
/// 
/// 管理设备注册和信息
class DeviceService {
  final SupabaseClient _supabase;

  DeviceService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  /// 注册当前设备
  Future<void> registerCurrentDevice() async {
    if (_userId == null) throw Exception('未登录');

    try {
      print('[Device] 开始注册设备...');

      // 获取设备信息
      final deviceInfo = await _getDeviceInfo();
      
      print('[Device] 设备信息: $deviceInfo');

      // 检查设备是否已注册
      final existing = await _supabase
          .from('devices')
          .select()
          .eq('user_id', _userId!)
          .eq('device_id', deviceInfo['device_id']!)
          .maybeSingle();

      if (existing != null) {
        // 设备已存在，更新最后活跃时间
        print('[Device] 设备已存在，更新活跃时间');
        await _supabase
            .from('devices')
            .update({'last_active_at': DateTime.now().toIso8601String()})
            .eq('id', existing['id']);
      } else {
        // 新设备，插入记录
        print('[Device] 注册新设备');
        await _supabase.from('devices').insert({
          'user_id': _userId,
          'device_name': deviceInfo['device_name']!,
          'device_type': deviceInfo['device_type']!,
          'device_id': deviceInfo['device_id']!,
        });
      }

      // 更新用户表的 device_count
      await _updateDeviceCount();

      print('[Device] 设备注册完成');
    } catch (e) {
      print('[Device] 设备注册失败: $e');
      // 不抛出异常，避免影响登录流程
    }
  }

  /// 获取设备信息
  Future<Map<String, String>> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();

    if (kIsWeb) {
      final webInfo = await deviceInfoPlugin.webBrowserInfo;
      return {
        'device_name': '${webInfo.browserName} on ${webInfo.platform}',
        'device_type': 'web',
        'device_id': 'web_${webInfo.userAgent?.hashCode ?? 0}',
      };
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      return {
        'device_name': '${androidInfo.brand} ${androidInfo.model}',
        'device_type': 'android',
        'device_id': androidInfo.id, // Android ID
      };
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;
      return {
        'device_name': '${iosInfo.name} (${iosInfo.model})',
        'device_type': 'ios',
        'device_id': iosInfo.identifierForVendor ?? 'ios_${iosInfo.name.hashCode}',
      };
    } else if (Platform.isMacOS) {
      final macInfo = await deviceInfoPlugin.macOsInfo;
      return {
        'device_name': macInfo.computerName,
        'device_type': 'macos',
        'device_id': macInfo.systemGUID ?? 'macos_${macInfo.computerName.hashCode}',
      };
    } else if (Platform.isWindows) {
      final windowsInfo = await deviceInfoPlugin.windowsInfo;
      return {
        'device_name': windowsInfo.computerName,
        'device_type': 'windows',
        'device_id': 'windows_${windowsInfo.computerName.hashCode}',
      };
    } else if (Platform.isLinux) {
      final linuxInfo = await deviceInfoPlugin.linuxInfo;
      return {
        'device_name': linuxInfo.name,
        'device_type': 'linux',
        'device_id': linuxInfo.machineId ?? 'linux_${linuxInfo.name.hashCode}',
      };
    }

    // 默认
    return {
      'device_name': 'Unknown Device',
      'device_type': 'unknown',
      'device_id': 'unknown_${DateTime.now().millisecondsSinceEpoch}',
    };
  }

  /// 更新设备数量
  Future<void> _updateDeviceCount() async {
    if (_userId == null) return;

    try {
      // 统计设备数量
      final devices = await _supabase
          .from('devices')
          .select('id')
          .eq('user_id', _userId!);

      final count = (devices as List).length;

      // 更新 users 表
      await _supabase
          .from('users')
          .update({'device_count': count})
          .eq('id', _userId!);

      print('[Device] 设备数量已更新: $count');
    } catch (e) {
      print('[Device] 更新设备数量失败: $e');
    }
  }

  /// 获取当前用户的所有设备
  Future<List<Map<String, dynamic>>> getDevices() async {
    if (_userId == null) throw Exception('未登录');

    final devices = await _supabase
        .from('devices')
        .select()
        .eq('user_id', _userId!)
        .order('last_active_at', ascending: false);

    return List<Map<String, dynamic>>.from(devices);
  }

  /// 删除设备
  Future<void> removeDevice(String deviceId) async {
    if (_userId == null) throw Exception('未登录');

    await _supabase
        .from('devices')
        .delete()
        .eq('user_id', _userId!)
        .eq('device_id', deviceId);

    await _updateDeviceCount();
  }
}
