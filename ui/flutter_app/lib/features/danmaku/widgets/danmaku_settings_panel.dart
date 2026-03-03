import 'package:flutter/material.dart';
import '../controllers/danmaku_controller.dart';
import '../widgets/danmaku_view.dart';

/// 弹幕设置面板
class DanmakuSettingsPanel extends StatelessWidget {
  final DanmakuController controller;
  
  const DanmakuSettingsPanel({
    super.key,
    required this.controller,
  });
  
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  const Icon(Icons.settings, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '弹幕设置',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // 弹幕开关
              _buildSwitchItem(
                '显示弹幕',
                controller.config.enabled,
                (value) => controller.toggleEnabled(),
              ),
              
              const Divider(color: Colors.white24, height: 32),
              
              // 透明度
              _buildSliderItem(
                '透明度',
                controller.config.opacity,
                0.0,
                1.0,
                (value) => controller.setOpacity(value),
                valueFormatter: (v) => '${(v * 100).toInt()}%',
              ),
              
              const SizedBox(height: 16),
              
              // 字体大小
              _buildSliderItem(
                '字体大小',
                controller.config.fontSize,
                12.0,
                48.0,
                (value) => controller.setFontSize(value),
                valueFormatter: (v) => '${v.toInt()}',
              ),
              
              const SizedBox(height: 16),
              
              // 速度
              _buildSliderItem(
                '弹幕速度',
                controller.config.speed,
                0.5,
                2.0,
                (value) => controller.setSpeed(value),
                valueFormatter: (v) => '${v.toStringAsFixed(1)}x',
              ),
              
              const SizedBox(height: 16),
              
              // 显示区域
              _buildSliderItem(
                '显示区域',
                controller.config.displayArea,
                0.25,
                1.0,
                (value) => controller.setDisplayArea(value),
                valueFormatter: (v) {
                  if (v >= 0.95) return '全屏';
                  if (v >= 0.65) return '3/4屏';
                  if (v >= 0.4) return '半屏';
                  return '1/4屏';
                },
              ),
              
              const SizedBox(height: 20),
              
              // 弹幕信息
              if (controller.hasDanmaku) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.currentVideoTitle ?? '未知视频',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '共 ${controller.danmakuList.length} 条弹幕',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildSwitchItem(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.blue,
        ),
      ],
    );
  }
  
  Widget _buildSliderItem(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    String Function(double)? valueFormatter,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Text(
              valueFormatter?.call(value) ?? value.toStringAsFixed(1),
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.blue,
              inactiveTrackColor: Colors.white.withOpacity(0.2),
              thumbColor: Colors.blue,
              overlayColor: Colors.blue.withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
