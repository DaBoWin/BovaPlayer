import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 生成主图标
  await generateIcon('assets/icon.png', 512, false);
  
  // 生成前景图标（用于 adaptive icon）
  await generateIcon('assets/icon_foreground.png', 512, true);
  
  print('图标生成完成！');
  exit(0);
}

Future<void> generateIcon(String path, int size, bool transparentBg) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  
  if (!transparentBg) {
    // 绘制背景
    final bgPaint = Paint()..color = const Color(0xFF1A1A2E);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), bgPaint);
  }
  
  // 绘制 Logo
  final center = Offset(size / 2, size / 2);
  final scale = size / 512.0;
  
  // 左侧三角形
  final leftTriangle = Path()
    ..moveTo(150 * scale, 150 * scale)
    ..lineTo(250 * scale, 256 * scale)
    ..lineTo(150 * scale, 362 * scale)
    ..close();
  
  final leftPaint = Paint()
    ..color = const Color(0xFF9D4EDD)
    ..style = PaintingStyle.fill;
  
  canvas.drawPath(leftTriangle, leftPaint);
  
  // 左侧三角形描边
  final leftStrokePaint = Paint()
    ..color = const Color(0xFFC77DFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4 * scale;
  
  canvas.drawPath(leftTriangle, leftStrokePaint);
  
  // 右侧三角形
  final rightTriangle = Path()
    ..moveTo(250 * scale, 256 * scale)
    ..lineTo(362 * scale, 150 * scale)
    ..lineTo(362 * scale, 362 * scale)
    ..close();
  
  final rightPaint = Paint()
    ..color = const Color(0xFF7B2CBF)
    ..style = PaintingStyle.fill;
  
  canvas.drawPath(rightTriangle, rightPaint);
  
  // 右侧三角形描边
  final rightStrokePaint = Paint()
    ..color = const Color(0xFF9D4EDD)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4 * scale;
  
  canvas.drawPath(rightTriangle, rightStrokePaint);
  
  // 转换为图片
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  
  // 保存文件
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(byteData!.buffer.asUint8List());
  
  print('已生成: $path');
}
