import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/danmaku_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/presentation/providers/auth_provider.dart';
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

  void _checkProStatus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      setState(() {
        _isPro = authProvider.user?.isPro ?? false;
      });
    });
  }

  void _showUpgradeDialog() {
    final l10n = S.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.star, color: Color(0xFFF59E0B), size: 24),
            const SizedBox(width: 8),
            Text(
              l10n.danmakuUpgradeToPro,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          l10n.danmakuUpgradeDesc,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Colors.white60),
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
            child: Text(l10n.danmakuViewPlans),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
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
                  Text(
                    l10n.danmakuSettings,
                    style: const TextStyle(
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
                l10n.danmakuShowDanmaku,
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
                l10n.danmakuOpacity,
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
                l10n.danmakuFontSize,
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
                l10n.danmakuSpeed,
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
                l10n.danmakuDisplayArea,
                widget.controller.config.displayArea,
                0.25,
                1.0,
                (value) {
                  if (_isPro) {
                    widget.controller.setDisplayArea(value);
                  }
                },
                valueFormatter: (v) {
                  if (v >= 0.95) return l10n.danmakuFullScreen;
                  if (v >= 0.65) return l10n.danmakuThreeQuarters;
                  if (v >= 0.4) return l10n.danmakuHalfScreen;
                  return l10n.danmakuQuarterScreen;
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
                        widget.controller.currentVideoTitle ?? l10n.danmakuUnknownVideo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.danmakuCount(widget.controller.danmakuList.length),
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
                      Expanded(
                        child: Text(
                          l10n.danmakuUpgradeUnlock,
                          style: const TextStyle(
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
                        child: Text(
                          l10n.danmakuUpgrade,
                          style: const TextStyle(
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
    ),
    );
  }
}
