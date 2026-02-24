import 'package:shared_preferences/shared_preferences.dart';

/// 播放器配置管理
class PlayerConfig {
  static const String _keyHardwareDecode = 'hardware_decode';
  static const String _keyLoudnessNorm = 'loudness_norm';
  static const String _keyEqEnabled = 'eq_enabled';
  static const String _keyEqPreset = 'eq_preset';
  static const String _keyAudioChannels = 'audio_channels';
  
  // 硬件解码
  bool hardwareDecodeEnabled = true;
  
  // 音频增强
  bool loudnessNormEnabled = false;
  bool eqEnabled = false;
  String eqPreset = 'flat';
  List<double> eqBands = List.filled(10, 0.0); // 10段均衡器
  String audioChannels = 'auto'; // auto, stereo, 5.1, 7.1
  
  PlayerConfig._();
  
  static final PlayerConfig _instance = PlayerConfig._();
  factory PlayerConfig() => _instance;
  
  /// 加载配置
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    hardwareDecodeEnabled = prefs.getBool(_keyHardwareDecode) ?? true;
    loudnessNormEnabled = prefs.getBool(_keyLoudnessNorm) ?? false;
    eqEnabled = prefs.getBool(_keyEqEnabled) ?? false;
    eqPreset = prefs.getString(_keyEqPreset) ?? 'flat';
    audioChannels = prefs.getString(_keyAudioChannels) ?? 'auto';
    
    // 加载 EQ 频段
    for (int i = 0; i < 10; i++) {
      eqBands[i] = prefs.getDouble('eq_band_$i') ?? 0.0;
    }
  }
  
  /// 保存配置
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHardwareDecode, hardwareDecodeEnabled);
    await prefs.setBool(_keyLoudnessNorm, loudnessNormEnabled);
    await prefs.setBool(_keyEqEnabled, eqEnabled);
    await prefs.setString(_keyEqPreset, eqPreset);
    await prefs.setString(_keyAudioChannels, audioChannels);
    
    // 保存 EQ 频段
    for (int i = 0; i < 10; i++) {
      await prefs.setDouble('eq_band_$i', eqBands[i]);
    }
  }
  
  /// 设置硬件解码
  Future<void> setHardwareDecode(bool enabled) async {
    hardwareDecodeEnabled = enabled;
    await save();
  }
  
  /// 设置响度归一化
  Future<void> setLoudnessNorm(bool enabled) async {
    loudnessNormEnabled = enabled;
    await save();
  }
  
  /// 设置均衡器
  Future<void> setEq(bool enabled, {String? preset, List<double>? bands}) async {
    eqEnabled = enabled;
    if (preset != null) eqPreset = preset;
    if (bands != null && bands.length == 10) {
      eqBands = List.from(bands);
    }
    await save();
  }
  
  /// 设置声道配置
  Future<void> setAudioChannels(String channels) async {
    audioChannels = channels;
    await save();
  }
  
  /// 获取 libmpv 配置参数
  Map<String, String> getMpvOptions() {
    final options = <String, String>{};
    
    // 硬件解码配置
    if (hardwareDecodeEnabled) {
      options['hwdec'] = 'auto-safe'; // 自动选择安全的硬件解码器
      options['hwdec-codecs'] = 'all'; // 所有编码格式尝试硬解
    } else {
      options['hwdec'] = 'no';
    }
    
    // 音频解码器配置 - 添加 TrueHD 支持
    options['ad'] = 'lavc:libavcodec'; // 使用 libavcodec 音频解码器
    options['audio-spdif'] = 'ac3,eac3,dts,dts-hd,truehd'; // 支持的音频格式
    
    // 音频输出配置
    options['ao'] = 'coreaudio'; // macOS 使用 CoreAudio
    options['audio-channels'] = 'auto-safe'; // 自动检测声道
    
    // 音频滤镜链
    final audioFilters = <String>[];
    
    // 响度归一化
    if (loudnessNormEnabled) {
      audioFilters.add('loudnorm=I=-16:TP=-1.5:LRA=11');
    }
    
    // 均衡器
    if (eqEnabled) {
      if (eqPreset != 'custom') {
        audioFilters.add(_getEqPresetFilter(eqPreset));
      } else {
        audioFilters.add(_getCustomEqFilter());
      }
    }
    
    // 声道映射
    if (audioChannels != 'auto') {
      audioFilters.add(_getChannelFilter(audioChannels));
    }
    
    if (audioFilters.isNotEmpty) {
      options['af'] = audioFilters.join(',');
    }
    
    // 其他优化配置
    options['vo'] = 'gpu'; // GPU 渲染
    options['gpu-api'] = 'auto'; // 自动选择 GPU API
    options['video-sync'] = 'display-resample'; // 视频同步优化
    options['interpolation'] = 'yes'; // 帧插值
    options['tscale'] = 'oversample'; // 时间缩放算法
    
    // 解码器回退策略
    options['vd-lavc-software-fallback'] = 'yes'; // 硬解失败时回退到软解
    options['ad-lavc-downmix'] = 'yes'; // 自动降混音
    options['audio-normalize-downmix'] = 'yes'; // 降混音时归一化
    
    return options;
  }
  
  /// 获取 EQ 预设滤镜
  String _getEqPresetFilter(String preset) {
    switch (preset) {
      case 'rock':
        return 'equalizer=f=60:width_type=o:width=2:g=8,'
               'equalizer=f=170:width_type=o:width=2:g=4,'
               'equalizer=f=310:width_type=o:width=2:g=-4,'
               'equalizer=f=600:width_type=o:width=2:g=-6,'
               'equalizer=f=1000:width_type=o:width=2:g=-4,'
               'equalizer=f=3000:width_type=o:width=2:g=4,'
               'equalizer=f=6000:width_type=o:width=2:g=6,'
               'equalizer=f=12000:width_type=o:width=2:g=8,'
               'equalizer=f=14000:width_type=o:width=2:g=8,'
               'equalizer=f=16000:width_type=o:width=2:g=8';
      case 'pop':
        return 'equalizer=f=60:width_type=o:width=2:g=-2,'
               'equalizer=f=170:width_type=o:width=2:g=4,'
               'equalizer=f=310:width_type=o:width=2:g=6,'
               'equalizer=f=600:width_type=o:width=2:g=6,'
               'equalizer=f=1000:width_type=o:width=2:g=4,'
               'equalizer=f=3000:width_type=o:width=2:g=-2,'
               'equalizer=f=6000:width_type=o:width=2:g=-2,'
               'equalizer=f=12000:width_type=o:width=2:g=-2,'
               'equalizer=f=14000:width_type=o:width=2:g=-2,'
               'equalizer=f=16000:width_type=o:width=2:g=-2';
      case 'jazz':
        return 'equalizer=f=60:width_type=o:width=2:g=4,'
               'equalizer=f=170:width_type=o:width=2:g=3,'
               'equalizer=f=310:width_type=o:width=2:g=2,'
               'equalizer=f=600:width_type=o:width=2:g=2,'
               'equalizer=f=1000:width_type=o:width=2:g=-2,'
               'equalizer=f=3000:width_type=o:width=2:g=-2,'
               'equalizer=f=6000:width_type=o:width=2:g=0,'
               'equalizer=f=12000:width_type=o:width=2:g=2,'
               'equalizer=f=14000:width_type=o:width=2:g=3,'
               'equalizer=f=16000:width_type=o:width=2:g=4';
      case 'classical':
        return 'equalizer=f=60:width_type=o:width=2:g=4,'
               'equalizer=f=170:width_type=o:width=2:g=3,'
               'equalizer=f=310:width_type=o:width=2:g=2,'
               'equalizer=f=600:width_type=o:width=2:g=0,'
               'equalizer=f=1000:width_type=o:width=2:g=0,'
               'equalizer=f=3000:width_type=o:width=2:g=0,'
               'equalizer=f=6000:width_type=o:width=2:g=2,'
               'equalizer=f=12000:width_type=o:width=2:g=3,'
               'equalizer=f=14000:width_type=o:width=2:g=4,'
               'equalizer=f=16000:width_type=o:width=2:g=4';
      case 'bass':
        return 'equalizer=f=60:width_type=o:width=2:g=8,'
               'equalizer=f=170:width_type=o:width=2:g=6,'
               'equalizer=f=310:width_type=o:width=2:g=4,'
               'equalizer=f=600:width_type=o:width=2:g=2,'
               'equalizer=f=1000:width_type=o:width=2:g=0,'
               'equalizer=f=3000:width_type=o:width=2:g=0,'
               'equalizer=f=6000:width_type=o:width=2:g=0,'
               'equalizer=f=12000:width_type=o:width=2:g=0,'
               'equalizer=f=14000:width_type=o:width=2:g=0,'
               'equalizer=f=16000:width_type=o:width=2:g=0';
      case 'treble':
        return 'equalizer=f=60:width_type=o:width=2:g=0,'
               'equalizer=f=170:width_type=o:width=2:g=0,'
               'equalizer=f=310:width_type=o:width=2:g=0,'
               'equalizer=f=600:width_type=o:width=2:g=0,'
               'equalizer=f=1000:width_type=o:width=2:g=0,'
               'equalizer=f=3000:width_type=o:width=2:g=2,'
               'equalizer=f=6000:width_type=o:width=2:g=4,'
               'equalizer=f=12000:width_type=o:width=2:g=6,'
               'equalizer=f=14000:width_type=o:width=2:g=8,'
               'equalizer=f=16000:width_type=o:width=2:g=8';
      default: // flat
        return '';
    }
  }
  
  /// 获取自定义 EQ 滤镜
  String _getCustomEqFilter() {
    final frequencies = [60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000];
    final filters = <String>[];
    
    for (int i = 0; i < 10; i++) {
      if (eqBands[i] != 0.0) {
        filters.add('equalizer=f=${frequencies[i]}:width_type=o:width=2:g=${eqBands[i]}');
      }
    }
    
    return filters.join(',');
  }
  
  /// 获取声道滤镜
  String _getChannelFilter(String channels) {
    switch (channels) {
      case 'stereo':
        return 'pan=stereo|c0=c0|c1=c1';
      case '5.1':
        return 'pan=5.1|c0=c0|c1=c1|c2=c2|c3=c3|c4=c4|c5=c5';
      case '7.1':
        return 'pan=7.1|c0=c0|c1=c1|c2=c2|c3=c3|c4=c4|c5=c5|c6=c6|c7=c7';
      default:
        return '';
    }
  }
  
  /// EQ 预设列表
  static const List<Map<String, String>> eqPresets = [
    {'id': 'flat', 'name': '平坦'},
    {'id': 'rock', 'name': '摇滚'},
    {'id': 'pop', 'name': '流行'},
    {'id': 'jazz', 'name': '爵士'},
    {'id': 'classical', 'name': '古典'},
    {'id': 'bass', 'name': '重低音'},
    {'id': 'treble', 'name': '高音增强'},
    {'id': 'custom', 'name': '自定义'},
  ];
  
  /// 声道配置列表
  static const List<Map<String, String>> channelConfigs = [
    {'id': 'auto', 'name': '自动'},
    {'id': 'stereo', 'name': '立体声'},
    {'id': '5.1', 'name': '5.1 环绕声'},
    {'id': '7.1', 'name': '7.1 环绕声'},
  ];
}
