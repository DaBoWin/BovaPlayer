import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// 延迟加载动态库
ffi.DynamicLibrary? _libInstance;

ffi.DynamicLibrary _getLib() {
  if (_libInstance != null) return _libInstance!;
  
  if (Platform.isMacOS) {
    // 尝试从多个位置加载
    final locations = [
      '@executable_path/../Frameworks/libbova_ffi.dylib',
      'libbova_ffi.dylib',
    ];
    
    for (final loc in locations) {
      try {
        print('[MPV] Trying to load from: $loc');
        _libInstance = ffi.DynamicLibrary.open(loc);
        print('[MPV] Successfully loaded from: $loc');
        return _libInstance!;
      } catch (e) {
        print('[MPV] Failed to load from $loc: $e');
      }
    }
    
    throw Exception('Failed to load libbova_ffi.dylib from any location');
  } else if (Platform.isLinux) {
    _libInstance = ffi.DynamicLibrary.open('libbova_ffi.so');
    return _libInstance!;
  } else if (Platform.isWindows) {
    _libInstance = ffi.DynamicLibrary.open('bova_ffi.dll');
    return _libInstance!;
  } else if (Platform.isAndroid) {
    _libInstance = ffi.DynamicLibrary.open('libbova_ffi.so');
    return _libInstance!;
  } else {
    throw UnsupportedError('Unsupported platform');
  }
}

// FFI函数签名
typedef _CreatePlayerNative = ffi.Int64 Function();
typedef _CreatePlayerDart = int Function();

typedef _OpenMediaNative = ffi.Int32 Function(
  ffi.Int64 playerId,
  ffi.Pointer<Utf8> url,
  ffi.Int32 hwaccel,
);
typedef _OpenMediaDart = int Function(int playerId, ffi.Pointer<Utf8> url, int hwaccel);

typedef _PlayNative = ffi.Int32 Function(ffi.Int64 playerId);
typedef _PlayDart = int Function(int playerId);

typedef _PauseNative = ffi.Int32 Function(ffi.Int64 playerId);
typedef _PauseDart = int Function(int playerId);

typedef _StopNative = ffi.Int32 Function(ffi.Int64 playerId);
typedef _StopDart = int Function(int playerId);

typedef _GetDurationNative = ffi.Double Function(ffi.Int64 playerId);
typedef _GetDurationDart = double Function(int playerId);

typedef _GetPositionNative = ffi.Double Function(ffi.Int64 playerId);
typedef _GetPositionDart = double Function(int playerId);

typedef _SeekNative = ffi.Int32 Function(ffi.Int64 playerId, ffi.Double position);
typedef _SeekDart = int Function(int playerId, double position);

typedef _IsPlayingNative = ffi.Int32 Function(ffi.Int64 playerId);
typedef _IsPlayingDart = int Function(int playerId);

typedef _GetVideoWidthNative = ffi.Int32 Function(ffi.Int64 playerId);
typedef _GetVideoWidthDart = int Function(int playerId);

typedef _GetVideoHeightNative = ffi.Int32 Function(ffi.Int64 playerId);
typedef _GetVideoHeightDart = int Function(int playerId);

typedef _GetLatestFrameNative = ffi.Pointer<ffi.Uint8> Function(
  ffi.Int64 playerId,
  ffi.Pointer<ffi.Int32> outWidth,
  ffi.Pointer<ffi.Int32> outHeight,
  ffi.Pointer<ffi.Size> outDataLen,
);
typedef _GetLatestFrameDart = ffi.Pointer<ffi.Uint8> Function(
  int playerId,
  ffi.Pointer<ffi.Int32> outWidth,
  ffi.Pointer<ffi.Int32> outHeight,
  ffi.Pointer<ffi.Size> outDataLen,
);

typedef _FreeFrameDataNative = ffi.Void Function(ffi.Pointer<ffi.Uint8> data, ffi.Size dataLen);
typedef _FreeFrameDataDart = void Function(ffi.Pointer<ffi.Uint8> data, int dataLen);

// 绑定FFI函数（延迟初始化）
_CreatePlayerDart? _createPlayer;
_OpenMediaDart? _openMedia;
_PlayDart? _play;
_PauseDart? _pause;
_StopDart? _stop;
_GetDurationDart? _getDuration;
_GetPositionDart? _getPosition;
_SeekDart? _seek;
_IsPlayingDart? _isPlaying;
_GetVideoWidthDart? _getVideoWidth;
_GetVideoHeightDart? _getVideoHeight;
_GetLatestFrameDart? _getLatestFrame;
_FreeFrameDataDart? _freeFrameData;

void _initBindings() {
  if (_createPlayer != null) return; // 已初始化
  
  final lib = _getLib();
  _createPlayer = lib.lookupFunction<_CreatePlayerNative, _CreatePlayerDart>('bova_mpv_create_player');
  _openMedia = lib.lookupFunction<_OpenMediaNative, _OpenMediaDart>('bova_mpv_open_media');
  _play = lib.lookupFunction<_PlayNative, _PlayDart>('bova_mpv_play');
  _pause = lib.lookupFunction<_PauseNative, _PauseDart>('bova_mpv_pause');
  _stop = lib.lookupFunction<_StopNative, _StopDart>('bova_mpv_stop');
  _getDuration = lib.lookupFunction<_GetDurationNative, _GetDurationDart>('bova_mpv_get_duration');
  _getPosition = lib.lookupFunction<_GetPositionNative, _GetPositionDart>('bova_mpv_get_position');
  _seek = lib.lookupFunction<_SeekNative, _SeekDart>('bova_mpv_seek');
  _isPlaying = lib.lookupFunction<_IsPlayingNative, _IsPlayingDart>('bova_mpv_is_playing');
  _getVideoWidth = lib.lookupFunction<_GetVideoWidthNative, _GetVideoWidthDart>('bova_mpv_get_video_width');
  _getVideoHeight = lib.lookupFunction<_GetVideoHeightNative, _GetVideoHeightDart>('bova_mpv_get_video_height');
  _getLatestFrame = lib.lookupFunction<_GetLatestFrameNative, _GetLatestFrameDart>('bova_mpv_get_latest_frame');
  _freeFrameData = lib.lookupFunction<_FreeFrameDataNative, _FreeFrameDataDart>('bova_mpv_free_frame_data');
  
  print('[MPV] FFI bindings initialized successfully');
}

class MpvPlayer {
  int? _playerId;
  
  /// 创建播放器实例
  bool create() {
    try {
      _initBindings();
      _playerId = _createPlayer!();
      print('[MPV] Player created with ID: $_playerId');
      return _playerId != null && _playerId! > 0;
    } catch (e) {
      print('[MPV] Failed to create player: $e');
      return false;
    }
  }
  
  /// 打开媒体
  bool openMedia(String url, {bool hwaccel = true}) {
    if (_playerId == null) return false;
    
    print('[MPV] Opening media: $url');
    final urlPtr = url.toNativeUtf8();
    try {
      final result = _openMedia!(_playerId!, urlPtr, hwaccel ? 1 : 0);
      print('[MPV] Open media result: $result');
      return result == 0;
    } catch (e) {
      print('[MPV] Failed to open media: $e');
      return false;
    } finally {
      malloc.free(urlPtr);
    }
  }
  
  /// 播放
  bool play() {
    if (_playerId == null) return false;
    try {
      return _play!(_playerId!) == 0;
    } catch (e) {
      print('[MPV] Failed to play: $e');
      return false;
    }
  }
  
  /// 暂停
  bool pause() {
    if (_playerId == null) return false;
    try {
      return _pause!(_playerId!) == 0;
    } catch (e) {
      print('[MPV] Failed to pause: $e');
      return false;
    }
  }
  
  /// 停止
  bool stop() {
    if (_playerId == null) return false;
    try {
      final result = _stop!(_playerId!) == 0;
      _playerId = null;
      return result;
    } catch (e) {
      print('[MPV] Failed to stop: $e');
      return false;
    }
  }
  
  /// 获取时长（秒）
  double getDuration() {
    if (_playerId == null) return 0.0;
    try {
      return _getDuration!(_playerId!);
    } catch (e) {
      print('[MPV] Failed to get duration: $e');
      return 0.0;
    }
  }
  
  /// 获取当前位置（秒）
  double getPosition() {
    if (_playerId == null) return 0.0;
    try {
      return _getPosition!(_playerId!);
    } catch (e) {
      return 0.0;
    }
  }
  
  /// 跳转
  bool seek(double position) {
    if (_playerId == null) return false;
    try {
      return _seek!(_playerId!, position) == 0;
    } catch (e) {
      print('[MPV] Failed to seek: $e');
      return false;
    }
  }
  
  /// 是否正在播放
  bool isPlaying() {
    if (_playerId == null) return false;
    try {
      return _isPlaying!(_playerId!) != 0;
    } catch (e) {
      return false;
    }
  }
  
  /// 获取视频宽度
  int getVideoWidth() {
    if (_playerId == null) return 0;
    try {
      return _getVideoWidth!(_playerId!);
    } catch (e) {
      return 0;
    }
  }
  
  /// 获取视频高度
  int getVideoHeight() {
    if (_playerId == null) return 0;
    try {
      return _getVideoHeight!(_playerId!);
    } catch (e) {
      return 0;
    }
  }
  
  /// 获取最新视频帧（RGBA格式）
  Uint8List? getLatestFrame() {
    if (_playerId == null) return null;
    
    final widthPtr = malloc<ffi.Int32>();
    final heightPtr = malloc<ffi.Int32>();
    final dataLenPtr = malloc<ffi.Size>();
    
    try {
      final dataPtr = _getLatestFrame!(_playerId!, widthPtr, heightPtr, dataLenPtr);
      
      if (dataPtr == ffi.nullptr) {
        return null;
      }
      
      final dataLen = dataLenPtr.value;
      if (dataLen == 0) {
        return null;
      }
      
      // 复制数据到Dart
      final data = Uint8List.fromList(
        dataPtr.asTypedList(dataLen),
      );
      
      // 释放原始数据
      _freeFrameData!(dataPtr, dataLen);
      
      return data;
    } catch (e) {
      return null;
    } finally {
      malloc.free(widthPtr);
      malloc.free(heightPtr);
      malloc.free(dataLenPtr);
    }
  }
  
  /// 释放资源
  void dispose() {
    if (_playerId != null) {
      stop();
    }
  }
}
