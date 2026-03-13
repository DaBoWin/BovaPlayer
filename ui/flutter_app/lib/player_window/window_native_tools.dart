import 'dart:ffi';
import 'dart:io';

typedef _ReleaseCaptureNative = Int32 Function();
typedef _ReleaseCaptureDart = int Function();
typedef _GetForegroundWindowNative = IntPtr Function();
typedef _GetForegroundWindowDart = int Function();
typedef _IsWindowEnabledNative = Int32 Function(IntPtr hWnd);
typedef _IsWindowEnabledDart = int Function(int hWnd);
typedef _EnableWindowNative = Int32 Function(IntPtr hWnd, Int32 enable);
typedef _EnableWindowDart = int Function(int hWnd, int enable);
typedef _GetWindowLongPtrNative = IntPtr Function(IntPtr hWnd, Int32 index);
typedef _GetWindowLongPtrDart = int Function(int hWnd, int index);
typedef _SetWindowLongPtrNative = IntPtr Function(
  IntPtr hWnd,
  Int32 index,
  IntPtr newLong,
);
typedef _SetWindowLongPtrDart = int Function(int hWnd, int index, int newLong);

final _ReleaseCaptureDart? _releaseCapture = () {
  if (!Platform.isWindows) {
    return null;
  }
  final user32 = DynamicLibrary.open('user32.dll');
  return user32.lookupFunction<_ReleaseCaptureNative, _ReleaseCaptureDart>(
    'ReleaseCapture',
  );
}();
final _GetForegroundWindowDart? _getForegroundWindow = () {
  if (!Platform.isWindows) {
    return null;
  }
  final user32 = DynamicLibrary.open('user32.dll');
  return user32.lookupFunction<
    _GetForegroundWindowNative,
    _GetForegroundWindowDart
  >('GetForegroundWindow');
}();
final _IsWindowEnabledDart? _isWindowEnabled = () {
  if (!Platform.isWindows) {
    return null;
  }
  final user32 = DynamicLibrary.open('user32.dll');
  return user32.lookupFunction<_IsWindowEnabledNative, _IsWindowEnabledDart>(
    'IsWindowEnabled',
  );
}();
final _EnableWindowDart? _enableWindow = () {
  if (!Platform.isWindows) {
    return null;
  }
  final user32 = DynamicLibrary.open('user32.dll');
  return user32.lookupFunction<_EnableWindowNative, _EnableWindowDart>(
    'EnableWindow',
  );
}();
final _GetWindowLongPtrDart? _getWindowLongPtr = () {
  if (!Platform.isWindows) {
    return null;
  }
  final user32 = DynamicLibrary.open('user32.dll');
  return user32.lookupFunction<
    _GetWindowLongPtrNative,
    _GetWindowLongPtrDart
  >('GetWindowLongPtrW');
}();
final _SetWindowLongPtrDart? _setWindowLongPtr = () {
  if (!Platform.isWindows) {
    return null;
  }
  final user32 = DynamicLibrary.open('user32.dll');
  return user32.lookupFunction<
    _SetWindowLongPtrNative,
    _SetWindowLongPtrDart
  >('SetWindowLongPtrW');
}();

const int _gwlStyle = -16;
const int _gwlExStyle = -20;
const int _wsDisabled = 0x08000000;
const int _wsExLayered = 0x00080000;
const int _wsExTransparent = 0x00000020;

void releaseMouseCapture() {
  if (!Platform.isWindows) {
    return;
  }
  final result = _releaseCapture?.call();
  print('[NativeWindow] ReleaseCapture result=$result');
}

void ensureForegroundWindowInteractive() {
  if (!Platform.isWindows) {
    return;
  }
  final hwnd = _getForegroundWindow?.call() ?? 0;
  if (hwnd == 0) {
    print('[NativeWindow] ensureForegroundWindowInteractive skipped: hwnd=0');
    return;
  }
  final styleBefore = _getWindowLongPtr?.call(hwnd, _gwlStyle) ?? 0;
  final exStyleBefore = _getWindowLongPtr?.call(hwnd, _gwlExStyle) ?? 0;
  final enabledBefore = (_isWindowEnabled?.call(hwnd) ?? 0) != 0;
  print(
    '[NativeWindow] before hwnd=$hwnd enabled=$enabledBefore '
    'style=0x${styleBefore.toRadixString(16)} '
    'exStyle=0x${exStyleBefore.toRadixString(16)}',
  );
  if (!enabledBefore) {
    _enableWindow?.call(hwnd, 1);
  }
  final styleAfter = styleBefore & ~_wsDisabled;
  final exStyleAfter = exStyleBefore & ~_wsExTransparent & ~_wsExLayered;
  if (styleAfter != styleBefore) {
    _setWindowLongPtr?.call(hwnd, _gwlStyle, styleAfter);
  }
  if (exStyleAfter != exStyleBefore) {
    _setWindowLongPtr?.call(hwnd, _gwlExStyle, exStyleAfter);
  }
  final enabledNow = (_isWindowEnabled?.call(hwnd) ?? 0) != 0;
  final styleNow = _getWindowLongPtr?.call(hwnd, _gwlStyle) ?? 0;
  final exStyleNow = _getWindowLongPtr?.call(hwnd, _gwlExStyle) ?? 0;
  print(
    '[NativeWindow] after hwnd=$hwnd enabled=$enabledNow '
    'style=0x${styleNow.toRadixString(16)} '
    'exStyle=0x${exStyleNow.toRadixString(16)}',
  );
}
