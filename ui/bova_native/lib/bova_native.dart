import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';

typedef BovaPlayerHandle = Pointer<Void>;

typedef BovaCreateFunc = BovaPlayerHandle Function();
typedef BovaDestroyFunc = Void Function(BovaPlayerHandle);
typedef BovaOpenFunc = Int32 Function(BovaPlayerHandle, Pointer<Utf8>, Pointer<Utf8>);
typedef BovaPlayFunc = Int32 Function(BovaPlayerHandle);
typedef BovaPauseFunc = Int32 Function(BovaPlayerHandle);
typedef BovaSeekFunc = Int32 Function(BovaPlayerHandle, Int64, Int32);
typedef BovaStopFunc = Int32 Function(BovaPlayerHandle);
typedef BovaVersionStringFunc = Pointer<Utf8> Function();
typedef BovaStringFreeFunc = Void Function(Pointer<Utf8>);

class BovaNative {
  static DynamicLibrary? _lib;

  static DynamicLibrary get lib {
    if (_lib != null) return _lib!;
    
    if (Platform.isMacOS || Platform.isIOS) {
      _lib = DynamicLibrary.open('libbova_ffi.dylib');
    } else if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libbova_ffi.so');
    } else if (Platform.isWindows) {
      _lib = DynamicLibrary.open('bova_ffi.dll');
    } else if (Platform.isLinux) {
      _lib = DynamicLibrary.open('libbova_ffi.so');
    } else {
      throw UnsupportedError('Platform not supported');
    }
    
    return _lib!;
  }

  static final bovaCreate = lib
      .lookup<NativeFunction<BovaCreateFunc>>('bova_create')
      .asFunction<BovaPlayerHandle Function()>();

  static final bovaDestroy = lib
      .lookup<NativeFunction<BovaDestroyFunc>>('bova_destroy')
      .asFunction<void Function(BovaPlayerHandle)>();

  static final bovaOpen = lib
      .lookup<NativeFunction<BovaOpenFunc>>('bova_open')
      .asFunction<int Function(BovaPlayerHandle, Pointer<Utf8>, Pointer<Utf8>)>();

  static final bovaPlay = lib
      .lookup<NativeFunction<BovaPlayFunc>>('bova_play')
      .asFunction<int Function(BovaPlayerHandle)>();

  static final bovaPause = lib
      .lookup<NativeFunction<BovaPauseFunc>>('bova_pause')
      .asFunction<int Function(BovaPlayerHandle)>();

  static final bovaSeek = lib
      .lookup<NativeFunction<BovaSeekFunc>>('bova_seek')
      .asFunction<int Function(BovaPlayerHandle, int, int)>();

  static final bovaStop = lib
      .lookup<NativeFunction<BovaStopFunc>>('bova_stop')
      .asFunction<int Function(BovaPlayerHandle)>();

  static final bovaVersionString = lib
      .lookup<NativeFunction<BovaVersionStringFunc>>('bova_version_string')
      .asFunction<Pointer<Utf8> Function()>();

  static final bovaStringFree = lib
      .lookup<NativeFunction<BovaStringFreeFunc>>('bova_string_free')
      .asFunction<void Function(Pointer<Utf8>)>();

  /// 获取版本信息
  static String getVersion() {
    final versionPtr = bovaVersionString();
    final version = versionPtr.toDartString();
    bovaStringFree(versionPtr);
    return version;
  }
}