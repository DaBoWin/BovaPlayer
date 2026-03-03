import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/danmaku.dart';

/// 弹幕 API 服务
class DanmakuApiService {
  static const String baseUrl = 'https://danmuapi-sandy-six.vercel.app/bova';
  
  // API 认证信息（如果需要）
  final String? apiKey;
  final String? appId;
  
  DanmakuApiService({
    this.apiKey,
    this.appId,
  });
  
  /// 获取请求头
  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': 'BovaPlayer/1.0',
    };
    
    // 如果有 API Key，添加到请求头
    final key = apiKey;
    if (key != null) {
      headers['Authorization'] = 'Bearer $key';
    }
    final id = appId;
    if (id != null) {
      headers['X-App-Id'] = id;
    }
    
    return headers;
  }
  
  /// 搜索匹配视频
  /// 
  /// [fileName] 文件名
  /// [fileHash] 文件哈希（可选）
  /// [fileSize] 文件大小（可选）
  /// [videoDuration] 视频时长（可选）
  Future<List<Map<String, dynamic>>> searchMatch({
    required String fileName,
    String? fileHash,
    int? fileSize,
    int? videoDuration,
  }) async {
    try {
      final body = <String, dynamic>{
        'fileName': fileName,
      };
      
      if (fileHash != null) body['fileHash'] = fileHash;
      if (fileSize != null) body['fileSize'] = fileSize;
      if (videoDuration != null) body['videoDuration'] = videoDuration;
      
      final uri = Uri.parse('$baseUrl/api/v2/match');
      
      print('[弹幕API] 🔍 请求 URL: $uri');
      print('[弹幕API] 📦 请求体: ${jsonEncode(body)}');
      
      final response = await http.post(
        uri,
        headers: _getHeaders(),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      
      print('[弹幕API] 📡 响应状态: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        
        print('[弹幕API] 📦 响应数据: ${jsonEncode(data)}');
        
        if (data['success'] == true) {
          final matches = data['matches'] as List?;
          if (matches != null && matches.isNotEmpty) {
            print('[弹幕API] ✅ 找到 ${matches.length} 个匹配');
            return List<Map<String, dynamic>>.from(matches);
          } else {
            print('[弹幕API] ⚠️  success=true 但 matches 为空');
          }
        } else {
          print('[弹幕API] ❌ success=false, errorMessage: ${data['errorMessage']}');
        }
      } else {
        print('[弹幕API] ❌ HTTP 错误: ${response.statusCode}');
        print('[弹幕API] 响应内容: ${response.body}');
      }
    } catch (e) {
      print('[弹幕API] ❌ 异常: $e');
    }
    
    return [];
  }
  
  /// 获取弹幕列表
  /// 
  /// [episodeId] 剧集 ID
  /// [withRelated] 是否包含相关弹幕
  Future<List<Danmaku>> getDanmaku(int episodeId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v2/comment/$episodeId?format=json');
      
      print('[弹幕API] 🔍 获取弹幕: $uri');
      
      final response = await http.get(uri, headers: _getHeaders()).timeout(
        const Duration(seconds: 15),
      );
      
      print('[弹幕API] 📡 响应状态: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        
        print('[弹幕API] 📦 响应数据: ${jsonEncode(data)}');
        
        final comments = data['comments'] as List?;
        if (comments != null && comments.isNotEmpty) {
          print('[弹幕API] ✅ 解析 ${comments.length} 条弹幕');
          print('[弹幕API] 📝 第一条弹幕示例: ${jsonEncode(comments.first)}');
          
          return comments
              .map((c) => Danmaku.fromDandanplay(c))
              .toList();
        } else {
          print('[弹幕API] ⚠️  comments 为空');
        }
      } else {
        print('[弹幕API] ❌ HTTP 错误: ${response.statusCode}');
      }
    } catch (e) {
      print('[弹幕API] ❌ 异常: $e');
    }
    
    return [];
  }
  
  /// 发送弹幕
  /// 
  /// [episodeId] 剧集 ID
  /// [time] 时间（秒）
  /// [content] 内容
  /// [type] 类型
  /// [color] 颜色
  Future<bool> sendDanmaku({
    required int episodeId,
    required double time,
    required String content,
    DanmakuType type = DanmakuType.scroll,
    int color = 0xFFFFFF,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v2/comment/$episodeId');
      
      final body = jsonEncode({
        'time': time,
        'mode': type.code,
        'color': color,
        'comment': content,
      });
      
      print('[DanmakuAPI] 发送弹幕: $uri');
      
      final response = await http.post(
        uri,
        headers: _getHeaders(),
        body: body,
      ).timeout(const Duration(seconds: 10));
      
      print('[DanmakuAPI] 响应状态: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          print('[DanmakuAPI] 弹幕发送成功');
          return true;
        } else {
          print('[DanmakuAPI] 发送失败: ${data['errorMessage']}');
        }
      }
    } catch (e) {
      print('[DanmakuAPI] 发送弹幕失败: $e');
    }
    
    return false;
  }
  
  /// 搜索番剧/影视
  /// 
  /// [keyword] 关键词
  Future<List<Map<String, dynamic>>> searchAnime(String keyword) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v2/search/anime').replace(
        queryParameters: {'keyword': keyword},
      );
      
      print('[DanmakuAPI] 搜索影视: $uri');
      
      final response = await http.get(uri, headers: _getHeaders()).timeout(
        const Duration(seconds: 10),
      );
      
      print('[DanmakuAPI] 响应状态: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (data['success'] == true) {
          final animes = data['animes'] as List?;
          if (animes != null && animes.isNotEmpty) {
            print('[DanmakuAPI] 找到 ${animes.length} 个结果');
            return List<Map<String, dynamic>>.from(animes);
          }
        }
      }
    } catch (e) {
      print('[DanmakuAPI] 搜索影视失败: $e');
    }
    
    return [];
  }
}
