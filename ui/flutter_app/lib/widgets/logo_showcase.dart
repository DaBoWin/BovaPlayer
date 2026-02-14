import 'package:flutter/material.dart';
import 'animated_logo.dart';

/// Logo 展示页面 - 用于测试和演示
class LogoShowcase extends StatelessWidget {
  const LogoShowcase({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('BovaPlayer Logo 展示'),
        backgroundColor: const Color(0xFF16213E),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              '动画版本',
              '适用于启动页、加载页',
              const AnimatedLogo(size: 200, animate: true),
            ),
            const SizedBox(height: 40),
            _buildSection(
              '静态版本',
              '适用于导航栏、工具栏',
              const StaticLogo(size: 120),
            ),
            const SizedBox(height: 40),
            _buildSection(
              '自定义颜色 - 暖金色',
              '匹配参考设计的配色',
              const AnimatedLogo(
                size: 150,
                animate: true,
                colors: [
                  Color(0xFFD4A574),
                  Color(0xFFC8956E),
                  Color(0xFFA67C52),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _buildSection(
              '自定义颜色 - 蓝色',
              '可根据主题动态切换',
              const AnimatedLogo(
                size: 150,
                animate: true,
                colors: [
                  Color(0xFF4A90E2),
                  Color(0xFF357ABD),
                  Color(0xFF2E5C8A),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _buildSection(
              '自定义颜色 - 紫色',
              '深色主题配色',
              const AnimatedLogo(
                size: 150,
                animate: true,
                colors: [
                  Color(0xFF9B59B6),
                  Color(0xFF8E44AD),
                  Color(0xFF6C3483),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _buildSizeComparison(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSection(String title, String description, Widget logo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(child: logo),
        ),
      ],
    );
  }
  
  Widget _buildSizeComparison() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '不同尺寸对比',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '从小到大: 32, 64, 96, 128, 200',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: const [
              AnimatedLogo(size: 32, animate: true),
              AnimatedLogo(size: 64, animate: true),
              AnimatedLogo(size: 96, animate: true),
              AnimatedLogo(size: 128, animate: true),
              AnimatedLogo(size: 200, animate: true),
            ],
          ),
        ),
      ],
    );
  }
}
