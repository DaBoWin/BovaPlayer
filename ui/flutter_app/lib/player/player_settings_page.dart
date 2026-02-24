import 'package:flutter/material.dart';
import 'player_config.dart';

class PlayerSettingsPage extends StatefulWidget {
  const PlayerSettingsPage({super.key});

  @override
  State<PlayerSettingsPage> createState() => _PlayerSettingsPageState();
}

class _PlayerSettingsPageState extends State<PlayerSettingsPage> {
  final _config = PlayerConfig();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    await _config.load();
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text(
            '播放器设置',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F2937),
          elevation: 0,
          iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF1F2937)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          '播放器设置',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: '视频设置',
            children: [
              _buildSwitchTile(
                title: '硬件解码',
                subtitle: '使用 GPU 加速解码，降低 CPU 占用',
                value: _config.hardwareDecodeEnabled,
                onChanged: (value) async {
                  await _config.setHardwareDecode(value);
                  setState(() {});
                  _showRestartHint();
                },
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          _buildSection(
            title: '音频设置',
            children: [
              _buildSwitchTile(
                title: '响度归一化',
                subtitle: '自动调整音量，避免音量忽大忽小',
                value: _config.loudnessNormEnabled,
                onChanged: (value) async {
                  await _config.setLoudnessNorm(value);
                  setState(() {});
                  _showRestartHint();
                },
              ),
              
              _buildSwitchTile(
                title: '均衡器',
                subtitle: '调整音频频段增益',
                value: _config.eqEnabled,
                onChanged: (value) async {
                  await _config.setEq(value);
                  setState(() {});
                  _showRestartHint();
                },
              ),
              
              if (_config.eqEnabled) ...[
                _buildDropdownTile(
                  title: 'EQ 预设',
                  value: _config.eqPreset,
                  items: PlayerConfig.eqPresets,
                  onChanged: (value) async {
                    await _config.setEq(true, preset: value);
                    setState(() {});
                    _showRestartHint();
                  },
                ),
                
                if (_config.eqPreset == 'custom')
                  _buildCustomEqTile(),
              ],
              
              _buildDropdownTile(
                title: '声道配置',
                value: _config.audioChannels,
                items: PlayerConfig.channelConfigs,
                onChanged: (value) async {
                  await _config.setAudioChannels(value);
                  setState(() {});
                  _showRestartHint();
                },
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(color: Color(0xFF1F2937)),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF1F2937),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String value,
    required List<Map<String, String>> items,
    required ValueChanged<String> onChanged,
  }) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(color: Color(0xFF1F2937)),
      ),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item['id'],
            child: Text(item['name']!),
          );
        }).toList(),
        onChanged: (newValue) {
          if (newValue != null) {
            onChanged(newValue);
          }
        },
      ),
    );
  }

  Widget _buildCustomEqTile() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '自定义均衡器',
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(10, (index) {
            final frequencies = ['60Hz', '170Hz', '310Hz', '600Hz', '1kHz', '3kHz', '6kHz', '12kHz', '14kHz', '16kHz'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      frequencies[index],
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _config.eqBands[index],
                      min: -12.0,
                      max: 12.0,
                      divisions: 48,
                      label: '${_config.eqBands[index].toStringAsFixed(1)} dB',
                      activeColor: const Color(0xFF1F2937),
                      onChanged: (value) {
                        setState(() {
                          _config.eqBands[index] = value;
                        });
                      },
                      onChangeEnd: (value) async {
                        await _config.setEq(true, bands: _config.eqBands);
                        _showRestartHint();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${_config.eqBands[index].toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: const Color(0xFFFEF3C7),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFFDE68A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline,
              color: Color(0xFFD97706),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '修改设置后需要重新打开视频才能生效',
                style: const TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRestartHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('设置已保存，重新打开视频后生效'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF1F2937),
      ),
    );
  }
}
