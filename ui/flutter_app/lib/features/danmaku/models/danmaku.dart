/// 弹幕数据模型
class Danmaku {
  final String content;      // 弹幕内容
  final double time;         // 出现时间（秒）
  final DanmakuType type;    // 弹幕类型
  final int color;           // 颜色（RGB）
  final int fontSize;        // 字体大小
  final String? userId;      // 用户ID（可选）
  
  Danmaku({
    required this.content,
    required this.time,
    required this.type,
    required this.color,
    this.fontSize = 25,
    this.userId,
  });
  
  /// 从弹弹 play API 格式解析
  factory Danmaku.fromDandanplay(Map<String, dynamic> json) {
    try {
      final p = json['p'].toString().split(',');
      final typeCode = int.parse(p[1]);
      final colorStr = p[2];
      
      // 移除方括号和其他非数字字符
      final colorValue = int.tryParse(colorStr.replaceAll(RegExp(r'[^\d]'), '')) ?? 16777215;
      
      return Danmaku(
        time: double.parse(p[0]),
        type: DanmakuType.fromCode(typeCode),
        color: colorValue,
        fontSize: p.length > 3 ? (int.tryParse(p[3]) ?? 25) : 25,
        content: json['m'] ?? '',
        userId: null,
      );
    } catch (e) {
      print('[弹幕解析] ❌ 解析失败: $e, 数据: $json');
      // 返回一个默认弹幕，避免整个列表解析失败
      return Danmaku(
        time: 0,
        type: DanmakuType.scroll,
        color: 0xFFFFFF,
        fontSize: 25,
        content: json['m'] ?? '解析失败',
      );
    }
  }
  
  /// 从 B 站 XML 格式解析
  factory Danmaku.fromBilibiliXml(Map<String, dynamic> json) {
    final p = json['@p'].toString().split(',');
    final typeCode = int.parse(p[1]);
    
    return Danmaku(
      time: double.parse(p[0]),
      type: DanmakuType.fromCode(typeCode),
      color: int.parse(p[2]),
      fontSize: int.parse(p[3]),
      content: json['#text'] ?? '',
      userId: p.length > 6 ? p[6] : null,
    );
  }
  
  /// 转换为 JSON
  Map<String, dynamic> toJson() => {
    'content': content,
    'time': time,
    'type': type.code,
    'color': color,
    'fontSize': fontSize,
    'userId': userId,
  };
  
  /// 从 JSON 解析
  factory Danmaku.fromJson(Map<String, dynamic> json) {
    return Danmaku(
      content: json['content'] ?? '',
      time: (json['time'] ?? 0).toDouble(),
      type: DanmakuType.fromCode(json['type'] ?? 1),
      color: json['color'] ?? 0xFFFFFF,
      fontSize: json['fontSize'] ?? 25,
      userId: json['userId'],
    );
  }
}

/// 弹幕类型
enum DanmakuType {
  scroll,    // 滚动弹幕（从右到左）
  top,       // 顶部固定
  bottom,    // 底部固定
  
  // 高级类型（暂不支持）
  // reverse,   // 逆向滚动
  // position,  // 定位弹幕
  // advanced,  // 高级弹幕
  ;
  
  int get code {
    switch (this) {
      case DanmakuType.scroll:
        return 1;
      case DanmakuType.top:
        return 5;
      case DanmakuType.bottom:
        return 4;
    }
  }
  
  static DanmakuType fromCode(int code) {
    switch (code) {
      case 1:
      case 2:
      case 3:
        return DanmakuType.scroll;
      case 5:
        return DanmakuType.top;
      case 4:
        return DanmakuType.bottom;
      default:
        return DanmakuType.scroll;
    }
  }
}
