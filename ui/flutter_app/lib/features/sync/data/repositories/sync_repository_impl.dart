import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../../domain/repositories/sync_repository.dart';
import '../../../../core/security/encryption_service.dart';

/// 同步仓库实现
/// 
/// 实现本地数据与云端的双向同步
/// 使用用户密码加密敏感信息（access_token）
class SyncRepositoryImpl implements SyncRepository {
  final SupabaseClient _supabase;
  final SharedPreferences _prefs;
  
  // 用户密码缓存（仅在内存中，用于加密/解密）
  String? _userPassword;

  SyncRepositoryImpl({
    SupabaseClient? supabase,
    required SharedPreferences prefs,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _prefs = prefs;

  String? get _userId => _supabase.auth.currentUser?.id;
  
  /// 检查是否已设置用户密码
  bool get hasUserPassword => _userPassword != null;
  
  /// 设置用户密码（登录时调用）
  void setUserPassword(String password) {
    _userPassword = password;
    print('[Sync] 用户密码已设置，可用于加密/解密');
  }
  
  /// 清除用户密码（登出时调用）
  void clearUserPassword() {
    _userPassword = null;
    print('[Sync] 用户密码已清除');
  }

  @override
  Future<void> syncMediaServers() async {
    if (_userId == null) throw Exception('未登录');
    if (_userPassword == null) throw Exception('未设置用户密码，无法加密数据');

    print('[Sync] 🔄 开始同步媒体服务器...');
    print('[Sync] 用户ID: $_userId');
    print('[Sync] 密码已设置: ${_userPassword != null}');

    // 1. 获取本地 Emby 服务器列表
    final localEmbyJson = _prefs.getString('emby_servers');
    print('[Sync] 本地 Emby JSON: ${localEmbyJson?.substring(0, localEmbyJson.length > 100 ? 100 : localEmbyJson.length)}...');
    final List<Map<String, dynamic>> localServers = [];

    if (localEmbyJson != null) {
      final List<dynamic> embyList = jsonDecode(localEmbyJson);
      for (var item in embyList) {
        final username = item['username'] as String? ?? '';
        final password = item['password'] as String? ?? '';
        
        if (username.isEmpty) {
          print('[Sync] ⚠️  服务器 ${item['name']} 的用户名为空，跳过');
          continue;
        }
        
        // 加密密码
        final encryptedPassword = password.isNotEmpty
            ? EncryptionService.encryptWithMasterPassword(
                password,
                _userPassword!,
                _userId!,
              )
            : '';
        
        localServers.add({
          'server_type': 'emby',
          'name': item['name'],
          'url': item['url'],
          'username': username,
          'password_encrypted': encryptedPassword,
          'user_id_server': item['userId'] ?? '',
        });
        
        print('[Sync] 已加密服务器: ${item['name']}');
      }
    }

    print('[Sync] 本地服务器数量: ${localServers.length}');

    // 2. 获取云端服务器列表
    final cloudServers = await _supabase
        .from('media_servers')
        .select()
        .eq('user_id', _userId!)
        .eq('is_active', true);

    print('[Sync] 云端服务器数量: ${(cloudServers as List).length}');

    // 3. 智能合并策略
    if (cloudServers.isEmpty && localServers.isNotEmpty) {
      // 场景 1：首次同步，上传本地到云端
      print('[Sync] 首次同步：上传本地服务器到云端');
      for (var server in localServers) {
        await _supabase.from('media_servers').insert({
          'user_id': _userId,
          ...server,
        });
      }
      print('[Sync] ✅ 上传完成');
      
    } else if (cloudServers.isNotEmpty && localServers.isEmpty) {
      // 场景 2：新设备登录，下载云端到本地
      print('[Sync] 新设备登录：下载云端服务器到本地');
      final embyServers = <Map<String, dynamic>>[];
      
      for (var s in cloudServers) {
        if (s['server_type'] == 'emby') {
          try {
            final encryptedPassword = s['password_encrypted'] as String?;
            final username = s['username'] as String? ?? '';
            
            if (username.isEmpty) {
              print('[Sync] ⚠️  服务器 ${s['name']} 的用户名为空，跳过');
              continue;
            }
            
            String decryptedPassword = '';
            
            // 尝试解密密码
            if (encryptedPassword != null && encryptedPassword.isNotEmpty) {
              try {
                decryptedPassword = EncryptionService.decryptWithMasterPassword(
                  encryptedPassword,
                  _userPassword!,
                  _userId!,
                );
                print('[Sync] ✅ 成功解密服务器: ${s['name']}');
              } catch (e) {
                print('[Sync] ⚠️  解密失败: ${s['name']}, 错误: $e');
                print('[Sync] 提示：该服务器可能使用旧的加密方式或数据损坏，跳过');
                continue; // 跳过无法解密的服务器
              }
            } else {
              print('[Sync] ⚠️  服务器 ${s['name']} 没有加密密码');
            }
            
            embyServers.add({
              'name': s['name'],
              'url': s['url'],
              'username': username,
              'password': decryptedPassword,
              'accessToken': null,
              'userId': s['user_id_server'] ?? '',
            });
            
            print('[Sync] ✅ 已解密服务器: ${s['name']}');
          } catch (e) {
            print('[Sync] ❌ 处理服务器失败: ${s['name']}, 错误: $e');
          }
        }
      }

      if (embyServers.isNotEmpty) {
        await _prefs.setString('emby_servers', jsonEncode(embyServers));
        print('[Sync] ✅ 下载完成，已保存 ${embyServers.length} 个服务器');
      }
      
    } else if (cloudServers.isNotEmpty && localServers.isNotEmpty) {
      // 场景 3：双向同步，合并本地和云端
      print('[Sync] 双向同步：合并本地和云端数据');
      
      // 创建云端服务器的 URL 映射（URL 作为唯一标识）
      final cloudServerMap = <String, Map<String, dynamic>>{};
      for (var s in cloudServers) {
        cloudServerMap[s['url']] = s;
      }
      
      // 创建本地服务器的 URL 映射
      final localServerMap = <String, Map<String, dynamic>>{};
      for (var local in localServers) {
        localServerMap[local['url']] = local;
      }
      
      // 1. 处理本地服务器：上传新的，更新现有的
      for (var local in localServers) {
        final url = local['url'];
        
        if (!cloudServerMap.containsKey(url)) {
          // 本地独有，上传到云端
          print('[Sync] ⬆️  上传新服务器: ${local['name']}');
          await _supabase.from('media_servers').insert({
            'user_id': _userId,
            ...local,
          });
        } else {
          // 云端也有，更新云端记录（本地优先）
          final cloudServer = cloudServerMap[url]!;
          print('[Sync] 🔄 更新云端服务器: ${local['name']}');
          await _supabase
              .from('media_servers')
              .update({
                'name': local['name'],
                'username': local['username'],
                'password_encrypted': local['password_encrypted'],
                'user_id_server': local['user_id_server'],
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', cloudServer['id']);
        }
      }
      
      // 2. 处理云端独有的服务器：下载到本地
      // 先获取当前本地的所有服务器
      final currentLocalJson = _prefs.getString('emby_servers');
      final embyServers = currentLocalJson != null 
          ? List<Map<String, dynamic>>.from(jsonDecode(currentLocalJson))
          : <Map<String, dynamic>>[];
      
      // 创建本地服务器的 URL 集合（用于快速查找）
      final localUrls = embyServers.map((s) => s['url'] as String).toSet();
      
      for (var cloud in cloudServers) {
        final url = cloud['url'];
        
        // 只下载本地没有的服务器
        if (!localUrls.contains(url) && cloud['server_type'] == 'emby') {
          try {
            final encryptedPassword = cloud['password_encrypted'] as String?;
            final username = cloud['username'] as String? ?? '';
            
            if (username.isEmpty) {
              print('[Sync] ⚠️  云端服务器 ${cloud['name']} 的用户名为空，跳过');
              continue;
            }
            
            String decryptedPassword = '';
            
            // 尝试解密密码
            if (encryptedPassword != null && encryptedPassword.isNotEmpty) {
              try {
                decryptedPassword = EncryptionService.decryptWithMasterPassword(
                  encryptedPassword,
                  _userPassword!,
                  _userId!,
                );
                print('[Sync] ✅ 成功解密服务器: ${cloud['name']}');
              } catch (e) {
                print('[Sync] ⚠️  解密失败: ${cloud['name']}, 错误: $e');
                print('[Sync] 提示：该服务器可能使用旧的加密方式或数据损坏，跳过');
                continue; // 跳过无法解密的服务器
              }
            } else {
              print('[Sync] ⚠️  云端服务器 ${cloud['name']} 没有加密密码');
            }
            
            embyServers.add({
              'name': cloud['name'],
              'url': url,
              'username': username,
              'password': decryptedPassword,
              'accessToken': null,
              'userId': cloud['user_id_server'] ?? '',
            });
            
            print('[Sync] ⬇️  下载云端独有服务器: ${cloud['name']}');
          } catch (e) {
            print('[Sync] ❌ 处理服务器失败: ${cloud['name']}, 错误: $e');
          }
        }
      }
      
      await _prefs.setString('emby_servers', jsonEncode(embyServers));
      print('[Sync] ✅ 双向合并完成，本地共有 ${embyServers.length} 个服务器');
    }

    await _updateLastSyncTime();
    print('[Sync] 媒体服务器同步完成');
  }

  @override
  Future<void> syncNetworkConnections() async {
    if (_userId == null) throw Exception('未登录');

    print('[Sync] 开始同步网络连接...');

    // 1. 获取本地网络连接（从 connection_manager）
    // 注意：密码不同步到云端，仅同步元数据
    final localConnectionsJson = _prefs.getString('network_connections');
    final List<Map<String, dynamic>> localConnections = [];

    if (localConnectionsJson != null) {
      final List<dynamic> connList = jsonDecode(localConnectionsJson);
      for (var conn in connList) {
        localConnections.add({
          'protocol': conn['protocol'],
          'name': conn['name'],
          'host': conn['host'],
          'port': conn['port'],
          'username': conn['username'],
          'share_name': conn['shareName'],
          'workgroup': conn['workgroup'],
          // 注意：不包含 password
        });
      }
    }

    print('[Sync] 本地连接数量: ${localConnections.length}');

    // 2. 获取云端连接列表
    final cloudConnections = await _supabase
        .from('network_connections')
        .select()
        .eq('user_id', _userId!)
        .eq('is_active', true);

    print('[Sync] 云端连接数量: ${(cloudConnections as List).length}');

    // 3. 首次同步：上传本地连接到云端
    if (cloudConnections.isEmpty && localConnections.isNotEmpty) {
      print('[Sync] 首次同步：上传本地连接到云端');
      for (var conn in localConnections) {
        await _supabase.from('network_connections').insert({
          'user_id': _userId,
          ...conn,
        });
      }
      print('[Sync] 上传完成');
    }

    await _updateLastSyncTime();
    print('[Sync] 网络连接同步完成');
  }

  @override
  Future<void> syncPlayHistory() async {
    if (_userId == null) throw Exception('未登录');
    print('[Sync] 播放历史同步功能待实现');
    // TODO: 实现播放历史同步
  }

  @override
  Future<void> syncFavorites() async {
    if (_userId == null) throw Exception('未登录');
    print('[Sync] 收藏列表同步功能待实现');
    // TODO: 实现收藏列表同步
  }

  @override
  Future<void> syncUserSettings() async {
    if (_userId == null) throw Exception('未登录');
    print('[Sync] 用户设置同步功能待实现');
    // TODO: 实现用户设置同步
  }

  @override
  Future<void> syncAll() async {
    print('[Sync] 开始完整同步...');
    
    try {
      await syncMediaServers();
      await syncNetworkConnections();
      // await syncPlayHistory();
      // await syncFavorites();
      // await syncUserSettings();
      
      print('[Sync] 完整同步完成');
    } catch (e) {
      print('[Sync] 同步失败: $e');
      rethrow;
    }
  }

  @override
  Future<DateTime?> getLastSyncTime() async {
    final timestamp = _prefs.getInt('last_sync_time');
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Future<void> _updateLastSyncTime() async {
    await _prefs.setInt('last_sync_time', DateTime.now().millisecondsSinceEpoch);
  }
}
