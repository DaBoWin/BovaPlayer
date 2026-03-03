import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../controllers/danmaku_controller.dart';
import '../widgets/danmaku_view.dart';
import '../../auth/presentation/pages/pricing_page.dart';

/// 弹幕设置面板
class DanmakuSettingsPanel extends StatefulWidget {
  final DanmakuController controller;
  
  const DanmakuSettingsPanel({
    super.key,
    required this.controller,
  });

  @override
  State<DanmakuSettingsPanel> createState() => _DanmakuSettingsPanelState();
}

class _DanmakuSettingsPanelState extends State<DanmakuSettingsPanel> {
  bool _isPro = false;
  
  @override
  void initState() {
    super.initState();
    _checkProStatus();
  }
  
  Future<void> _checkProStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    
    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        final accountType = userData['account_type'] as String?;
        setState(() {
          _isPro = accountType == 'pro' || accountType == 'lifetime';
        });
      } catch (e) {
        print('[弹幕设置] 解析用户信息失败: $e');
      }
    }
  }
  
  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.star, color: Color(0xFFF59E0B), size: 24),
            SizedBox(width: 8),
            Text(
              '升级到 Pro 版',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: const Text(
          '弹幕功能仅限 Pro 版和永久版用户使用。\n\n升级后可享受：\n• 实时弹幕显示\n• 弹幕自定义设置\n• 云同步功能\n• 更多高级功能',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '取消',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // 关闭弹幕设置面板
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PricingPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('查看方案'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
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
                widget.controller.config.enabled,
                (value) {
                  if (!_isPro) {
                    _showUpgradeDialog();
                  } else {
                    widget.controller.toggleEnabled();
                  }
                },
              ),
              
              const Divider(color: Colors.white24, height: 32),
              
              // 透明度
              _buildSliderItem(
                '透明度',
                widget.controller.config.opacity,
                0.0,
                1.0,
                (value) {
                  if (_isPro) {
                    widget.controller.setOpacity(value);
                  }
                },
                valueFormatter: (v) => '${(v * 100).toInt()}%',
                enabled: _isPro,
              ),
              
              const SizedBox(height: 16),
              
              // 字体大小
              _buildSliderItem(
                '字体大小',
                widget.controller.config.fontSize,
                12.0,
                48.0,
                (value) {
                  if (_isPro) {
                    widget.controller.setFontSize(value);
                  }
                },
                valueFormatter: (v) => '${v.toInt()}',
                enabled: _isPro,
              ),
              
              const SizedBox(height: 16),
              
              // 速度
              _buildSliderItem(
                '弹幕速度',
                widget.controller.config.speed,
                0.5,
                2.0,
                (value) {
                  if (_isPro) {
                    widget.controller.setSpeed(value);
                  }
                },
                valueFormatter: (v) => '${v.toStringAsFixed(1)}x',
                enabled: _isPro,
              ),
              
              const SizedBox(height: 16),
              
              // 显示区域
              _buildSliderItem(
                '显示区域',
                widget.controller.config.displayArea,
                0.25,
                1.0,
                (value) {
                  if (_isPro) {
                    widget.controller.setDisplayArea(value);
                  }
                },
                valueFormatter: (v) {
                  if (v >= 0.95) return '全屏';
                  if (v >= 0.65) return '3/4屏';
                  if (v >= 0.4) return '半屏';
                  return '1/4屏';
                },
                enabled: _isPro,
              ),
              
              const SizedBox(height: 20),
              
              // 弹幕信息
              if (widget.controller.hasDanmaku) ...[
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
                        widget.controller.currentVideoTitle ?? '未知视频',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '共 ${widget.controller.danmakuList.length} 条弹幕',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Pro 提示
              if (!_isPro) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '升级到 Pro 版解锁弹幕功能',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _showUpgradeDialog,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          backgroundColor: const Color(0xFFF59E0B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          '升级',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
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
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Column(
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
            ),
          ],
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: enabled ? Colors.blue : Colors.grey,
              inactiveTrackColor: Colors.white.withOpacity(0.2),
              thumbColor: enabled ? Colors.blue : Colors.grey,
              overlayColor: (enabled ? Colors.blue : Colors.grey).withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
  }
}
