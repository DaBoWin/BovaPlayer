import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/danmaku.dart';
import '../services/danmaku_api_service.dart';
import '../widgets/danmaku_view.dart';

/// 弹幕控制器
class DanmakuController extends ChangeNotifier {
  final DanmakuApiService _apiService;
  
  List<Danmaku> _danmakuList = [];
  DanmakuConfig _config = const DanmakuConfig();
  bool _isLoading = false;
  String? _errorMessage;
  
  // 当前匹配的视频信息
  int? _currentEpisodeId;
  String? _currentVideoTitle;
  
  DanmakuController({
    String? apiKey,
    String? appId,
  }) : _apiService = DanmakuApiService(apiKey: apiKey, appId: appId) {
    _loadConfig();
  }
  
  List<Danmaku> get danmakuList => _danmakuList;
  DanmakuConfig get config => _config;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int? get currentEpisodeId => _currentEpisodeId;
  String? get currentVideoTitle => _currentVideoTitle;
  bool get hasDanmaku => _danmakuList.isNotEmpty;
  
  /// 加载配置
  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('danmaku_enabled') ?? true;
      final opacity = prefs.getDouble('danmaku_opacity') ?? 0.8;
      final fontSize = prefs.getDouble('danmaku_fontSize') ?? 25.0;
      final speed = prefs.getDouble('danmaku_speed') ?? 1.0;
      final displayArea = prefs.getDouble('danmaku_displayArea') ?? 1.0;
      
      _config = DanmakuConfig(
        enabled: enabled,
        opacity: opacity,
        fontSize: fontSize,
        speed: speed,
        displayArea: displayArea,
      );
      
      notifyListeners();
    } catch (e) {
      print('[DanmakuController] 加载配置失败: $e');
    }
  }
  
  /// 保存配置
  Future<void> _saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('danmaku_enabled', _config.enabled);
      await prefs.setDouble('danmaku_opacity', _config.opacity);
      await prefs.setDouble('danmaku_fontSize', _config.fontSize);
      await prefs.setDouble('danmaku_speed', _config.speed);
      await prefs.setDouble('danmaku_displayArea', _config.displayArea);
    } catch (e) {
      print('[DanmakuController] 保存配置失败: $e');
    }
  }
  
  /// 更新配置
  void updateConfig(DanmakuConfig newConfig) {
    _config = newConfig;
    _saveConfig();
    notifyListeners();
  }
  
  /// 切换弹幕开关
  void toggleEnabled() {
    _config = _config.copyWith(enabled: !_config.enabled);
    _saveConfig();
    notifyListeners();
  }
  
  /// 设置透明度
  void setOpacity(double opacity) {
    _config = _config.copyWith(opacity: opacity.clamp(0.0, 1.0));
    _saveConfig();
    notifyListeners();
  }
  
  /// 设置字体大小
  void setFontSize(double fontSize) {
    _config = _config.copyWith(fontSize: fontSize.clamp(12.0, 48.0));
    _saveConfig();
    notifyListeners();
  }
  
  /// 设置速度
  void setSpeed(double speed) {
    _config = _config.copyWith(speed: speed.clamp(0.5, 2.0));
    _saveConfig();
    notifyListeners();
  }
  
  /// 设置显示区域
  void setDisplayArea(double area) {
    _config = _config.copyWith(displayArea: area.clamp(0.25, 1.0));
    _saveConfig();
    notifyListeners();
  }
  
  /// 加载弹幕（通过文件名匹配）
  Future<bool> loadDanmakuByFileName(String fileName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      print('');
      print('========================================');
      print('[弹幕] 原始标题: $fileName');
      
      // 检查标题是否已经包含季集信息（S01E01）
      final hasSeasonEpisode = RegExp(r'S\d+E\d+', caseSensitive: false).hasMatch(fileName);
      
      String searchQuery;
      if (hasSeasonEpisode) {
        // 标题已包含季集信息（来自 Emby 的中文标题 + S01E01）
        // 只需要清理技术信息
        searchQuery = _cleanFileNameSimple(fileName);
        print('[弹幕] 使用 Emby 标题（已含季集）: $searchQuery');
      } else {
        // 标题不包含季集信息，使用完整清理逻辑
        searchQuery = _cleanFileName(fileName);
        print('[弹幕] 清理后标题: $searchQuery');
      }
      
      print('========================================');
      
      // 1. 搜索匹配
      print('[弹幕] 🔍 开始调用 API...');
      final matches = await _apiService.searchMatch(fileName: searchQuery);
      print('[弹幕] 📡 API 返回 ${matches.length} 个结果');
      
      if (matches.isEmpty) {
        _errorMessage = '未找到匹配的弹幕';
        print('[弹幕] ❌ 未找到匹配');
        print('========================================');
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // 2. 使用第一个匹配结果
      final match = matches.first;
      final episodeId = match['episodeId'] as int;
      final title = match['animeTitle'] ?? match['episodeTitle'] ?? '未知';
      
      print('[弹幕] ✅ 匹配成功: $title');
      print('[弹幕] 剧集ID: $episodeId');
      
      // 3. 获取弹幕
      final danmakuList = await _apiService.getDanmaku(episodeId);
      
      if (danmakuList.isEmpty) {
        _errorMessage = '该视频暂无弹幕';
        print('[弹幕] ⚠️  暂无弹幕');
        print('========================================');
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // 4. 按时间排序
      danmakuList.sort((a, b) => a.time.compareTo(b.time));
      
      _danmakuList = danmakuList;
      _currentEpisodeId = episodeId;
      _currentVideoTitle = title;
      _errorMessage = null;
      
      print('[弹幕] ✅ 加载成功: ${danmakuList.length} 条弹幕');
      print('[弹幕] 弹幕开关: ${_config.enabled ? "开启" : "关闭"}');
      print('========================================');
      print('');
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '加载弹幕失败: $e';
      print('[弹幕] ❌ 加载失败: $e');
      print('========================================');
      print('');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// 简单清理（用于已包含季集信息的 Emby 标题）
  /// 只移除技术信息，保留剧名和季集
  String _cleanFileNameSimple(String fileName) {
    String cleaned = fileName;
    
    // 移除文件扩展名
    cleaned = cleaned.replaceAll(RegExp(r'\.(mp4|mkv|avi|mov|flv|wmv|webm)$', caseSensitive: false), '');
    
    // 不再移除年份，以提高电影匹配的准确性（例如："金刚 2005"）
    // cleaned = cleaned.replaceAll(RegExp(r'\(?\d{4}\)?'), '');
    
    // 移除分辨率、编码、音频、HDR、来源等技术信息
    cleaned = cleaned.replaceAll(RegExp(r'\b(4K|2160p|1080p|720p|480p|360p)\b', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b(HEVC|H\.?264|H\.?265|x264|x265|AVC|VP9|AV1)\b', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b(AAC|AC3|DTS|TrueHD|FLAC|Atmos|DDP|DD\+?|5\.1|7\.1)\b', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b(HDR|HDR10|HDR10\+|Dolby Vision|DV|SDR)\b', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b(WEB-?DL|WEBRip|BluRay|BDRip|DVDRip|HDTV|WEB)\b', caseSensitive: false), '');
    
    // 移除制作组信息
    cleaned = cleaned.replaceAll(RegExp(r'\[.*?\]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\(.*?(字幕组|Sub|Rip|组|简|繁|中字|内封|外挂).*?\)', caseSensitive: false), '');
    
    // 标准化季集格式
    cleaned = cleaned.replaceAllMapped(RegExp(r's(\d+)e(\d+)', caseSensitive: false), (match) {
      final season = match.group(1)!.padLeft(2, '0');
      final episode = match.group(2)!.padLeft(2, '0');
      return 'S${season}E$episode';
    });
    
    // 清理分隔符
    cleaned = cleaned.replaceAll(RegExp(r'[_\.\-]+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    
    return cleaned.trim();
  }
  
  /// 清理文件名，提高匹配成功率
  /// 策略：
  /// 1. 优先提取中文名称
  /// 2. 保留季集信息（S01E01）
  /// 3. 移除技术信息（分辨率、编码等）
  String _cleanFileName(String fileName) {
    String cleaned = fileName;
    
    // 移除常见的视频文件扩展名
    cleaned = cleaned.replaceAll(RegExp(r'\.(mp4|mkv|avi|mov|flv|wmv|webm)$', caseSensitive: false), '');
    
    // 提取季集信息（S01E01）
    String? seasonEpisode;
    final seasonEpisodeMatch = RegExp(r's(\d+)e(\d+)', caseSensitive: false).firstMatch(cleaned);
    if (seasonEpisodeMatch != null) {
      final season = seasonEpisodeMatch.group(1)!.padLeft(2, '0');
      final episode = seasonEpisodeMatch.group(2)!.padLeft(2, '0');
      seasonEpisode = 'S${season}E$episode';
    }
    
    // 移除制作组信息（通常在方括号中）
    cleaned = cleaned.replaceAll(RegExp(r'\[.*?\]'), '');
    
    // 移除圆括号中的技术信息
    cleaned = cleaned.replaceAll(RegExp(r'\(.*?(字幕组|Sub|Rip|组|简|繁|中字|内封|外挂).*?\)', caseSensitive: false), '');
    
    // 将括号包裹的单独年份释放出来（如 "(2005)" 变成 " 2005 "），其余的保留
    cleaned = cleaned.replaceAllMapped(RegExp(r'\((\d{4})\)'), (match) => ' ${match.group(1)} ');
    
    // 移除分辨率信息
    cleaned = cleaned.replaceAll(RegExp(r'\b(4K|2160p|1080p|720p|480p|360p)\b', caseSensitive: false), '');
    
    // 移除编码信息
    cleaned = cleaned.replaceAll(RegExp(r'\b(HEVC|H\.?264|H\.?265|x264|x265|AVC|VP9|AV1)\b', caseSensitive: false), '');
    
    // 移除音频信息
    cleaned = cleaned.replaceAll(RegExp(r'\b(AAC|AC3|DTS|TrueHD|FLAC|Atmos|DDP|DD\+?|5\.1|7\.1)\b', caseSensitive: false), '');
    
    // 移除 HDR 信息
    cleaned = cleaned.replaceAll(RegExp(r'\b(HDR|HDR10|HDR10\+|Dolby Vision|DV|SDR)\b', caseSensitive: false), '');
    
    // 移除来源信息
    cleaned = cleaned.replaceAll(RegExp(r'\b(WEB-?DL|WEBRip|BluRay|BDRip|DVDRip|HDTV|WEB)\b', caseSensitive: false), '');
    
    // 移除季集信息（稍后会重新添加）
    cleaned = cleaned.replaceAll(RegExp(r's\d+e\d+', caseSensitive: false), '');
    
    // 将点号、下划线、连字符替换为空格
    cleaned = cleaned.replaceAll(RegExp(r'[_\.\-]+'), ' ');
    
    // 移除多余的空格
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.trim();
    
    // 优先提取中文名称
    String finalName = '';
    
    // 检查是否包含中文
    final chineseMatch = RegExp(r'[\u4e00-\u9fa5]+(?:[\u4e00-\u9fa5\s]*[\u4e00-\u9fa5]+)*').firstMatch(cleaned);
    
    if (chineseMatch != null) {
      // 有中文，优先使用中文名称
      finalName = chineseMatch.group(0)!.trim();
    } else {
      // 没有中文，使用清理后的完整名称
      // 但要移除可能的多余英文单词（如 The、A、An 等）
      finalName = cleaned;
    }
    
    // 添加季集信息
    if (seasonEpisode != null) {
      finalName = '$finalName $seasonEpisode';
    } else {
      // 若没有季集信息，尝试提取可能的年份并追加到后面（如果是电影）
      // 这里的逻辑是如果原始文件名含有年份，并且 finalName 里尚未包含，则补上
      final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(cleaned);
      if (yearMatch != null && !finalName.contains(yearMatch.group(0)!)) {
        finalName = '$finalName ${yearMatch.group(0)}';
      }
    }
    
    return finalName.trim();
  }
  
  /// 加载弹幕（通过剧集ID）
  Future<bool> loadDanmakuByEpisodeId(int episodeId, {String? title}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      print('[DanmakuController] 加载弹幕: ID=$episodeId');
      
      final danmakuList = await _apiService.getDanmaku(episodeId);
      
      if (danmakuList.isEmpty) {
        _errorMessage = '该视频暂无弹幕';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      danmakuList.sort((a, b) => a.time.compareTo(b.time));
      
      _danmakuList = danmakuList;
      _currentEpisodeId = episodeId;
      _currentVideoTitle = title;
      _errorMessage = null;
      
      print('[DanmakuController] 加载成功: ${danmakuList.length} 条弹幕');
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '加载弹幕失败: $e';
      print('[DanmakuController] 加载失败: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// 清空弹幕
  void clear() {
    _danmakuList = [];
    _currentEpisodeId = null;
    _currentVideoTitle = null;
    _errorMessage = null;
    notifyListeners();
  }
  
  /// 发送弹幕
  Future<bool> sendDanmaku({
    required double time,
    required String content,
    DanmakuType type = DanmakuType.scroll,
    int color = 0xFFFFFF,
  }) async {
    if (_currentEpisodeId == null) {
      _errorMessage = '未加载视频弹幕';
      notifyListeners();
      return false;
    }
    
    try {
      final success = await _apiService.sendDanmaku(
        episodeId: _currentEpisodeId!,
        time: time,
        content: content,
        type: type,
        color: color,
      );
      
      if (success) {
        // 添加到本地列表
        final newDanmaku = Danmaku(
          content: content,
          time: time,
          type: type,
          color: color,
        );
        
        _danmakuList.add(newDanmaku);
        _danmakuList.sort((a, b) => a.time.compareTo(b.time));
        
        notifyListeners();
      }
      
      return success;
    } catch (e) {
      _errorMessage = '发送弹幕失败: $e';
      notifyListeners();
      return false;
    }
  }
}
