import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../widgets/custom_app_bar.dart';
import '../providers/auth_provider.dart';

/// 兑换码管理页面（管理员）
class RedemptionAdminPage extends StatefulWidget {
  const RedemptionAdminPage({super.key});

  @override
  State<RedemptionAdminPage> createState() => _RedemptionAdminPageState();
}

class _RedemptionAdminPageState extends State<RedemptionAdminPage> {
  List<dynamic> _codes = [];
  bool _isLoading = false;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadCodes();
  }

  Future<void> _loadCodes() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.listCodes(filter: _filter);

      if (result['success'] == true) {
        setState(() {
          _codes = (result['codes'] as List?) ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showError(result['message'] ?? '加载失败');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('加载失败: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF10B981)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: CustomAppBar(
        showBackButton: true,
        title: '兑换码管理',
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF1F2937)),
            onPressed: _showGenerateDialog,
            tooltip: '生成兑换码',
          ),
        ],
      ),
      body: Column(
        children: [
          // 筛选栏
          _buildFilterBar(),
          // 列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _codes.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无兑换码',
                          style: TextStyle(color: Color(0xFF9CA3AF)),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCodes,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _codes.length,
                          itemBuilder: (ctx, i) => _buildCodeCard(_codes[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = {
      'all': '全部',
      'unused': '未使用',
      'used': '已使用',
      'expired': '已过期',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: filters.entries.map((e) {
          final isActive = _filter == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                e.value,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
              selected: isActive,
              selectedColor: const Color(0xFF1F2937),
              backgroundColor: const Color(0xFFF3F4F6),
              onSelected: (_) {
                setState(() => _filter = e.key);
                _loadCodes();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCodeCard(dynamic code) {
    final isUsed = code['is_used'] == true;
    final isExpired = code['is_expired'] == true;
    final codeType = code['code_type'] as String? ?? 'pro';
    final codeStr = code['code'] as String? ?? '';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isUsed) {
      statusColor = const Color(0xFF6B7280);
      statusText = '已使用';
      statusIcon = Icons.check_circle;
    } else if (isExpired) {
      statusColor = Colors.red;
      statusText = '已过期';
      statusIcon = Icons.cancel;
    } else {
      statusColor = const Color(0xFF10B981);
      statusText = '可用';
      statusIcon = Icons.radio_button_unchecked;
    }

    final typeColor = codeType == 'lifetime'
        ? const Color(0xFFF59E0B)
        : const Color(0xFF3B82F6);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 兑换码 + 复制按钮
            Row(
              children: [
                Expanded(
                  child: Text(
                    codeStr,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isUsed || isExpired
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF1F2937),
                      letterSpacing: 1.0,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                if (!isUsed && !isExpired)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    color: const Color(0xFF6B7280),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: codeStr));
                      _showSuccess('已复制: $codeStr');
                    },
                    tooltip: '复制',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // 类型 + 状态
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    codeType == 'lifetime' ? '永久版' : 'Pro ${code['duration_days'] ?? 30}天',
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
                const Spacer(),
                if (code['expires_at'] != null)
                  Text(
                    '过期: ${_formatDate(code['expires_at'])}',
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            // 使用者信息
            if (isUsed && code['used_by_email'] != null) ...[
              const SizedBox(height: 6),
              Text(
                '使用者: ${code['used_by_email']}  时间: ${_formatDate(code['used_at'])}',
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 11,
                ),
              ),
            ],
            // 备注
            if (code['note'] != null && (code['note'] as String).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '备注: ${code['note']}',
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr.toString();
    }
  }

  void _showGenerateDialog() {
    String selectedType = 'pro';
    final countCtrl = TextEditingController(text: '1');
    final durationCtrl = TextEditingController(text: '30');
    final expiresCtrl = TextEditingController(text: '365');
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '生成兑换码',
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 类型选择
                const Text(
                  '类型',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => selectedType = 'pro'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selectedType == 'pro'
                                ? const Color(0xFF3B82F6).withOpacity(0.1)
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selectedType == 'pro'
                                  ? const Color(0xFF3B82F6)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '💎',
                                style: TextStyle(fontSize: selectedType == 'pro' ? 24 : 20),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Pro 版',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selectedType == 'pro'
                                      ? const Color(0xFF3B82F6)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => selectedType = 'lifetime'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selectedType == 'lifetime'
                                ? const Color(0xFFF59E0B).withOpacity(0.1)
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selectedType == 'lifetime'
                                  ? const Color(0xFFF59E0B)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '👑',
                                style: TextStyle(fontSize: selectedType == 'lifetime' ? 24 : 20),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '永久版',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selectedType == 'lifetime'
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 数量
                _buildInputField(countCtrl, '生成数量', '1-100', isNumber: true),
                const SizedBox(height: 12),

                // Pro 有效天数
                if (selectedType == 'pro') ...[
                  _buildInputField(durationCtrl, 'Pro 有效天数', '如 30、90、365', isNumber: true),
                  const SizedBox(height: 12),
                ],

                // 码过期天数
                _buildInputField(expiresCtrl, '兑换码过期天数', '生成后多少天内有效', isNumber: true),
                const SizedBox(height: 12),

                // 备注
                _buildInputField(noteCtrl, '备注（可选）', '如: 送给XXX'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                '取消',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _generateCodes(
                  type: selectedType,
                  count: int.tryParse(countCtrl.text) ?? 1,
                  durationDays: int.tryParse(durationCtrl.text) ?? 30,
                  expiresDays: int.tryParse(expiresCtrl.text) ?? 365,
                  note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F2937),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('生成'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
    TextEditingController controller,
    String label,
    String hint, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Color(0xFF1F2937), fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1F2937), width: 2),
        ),
      ),
    );
  }

  Future<void> _generateCodes({
    required String type,
    required int count,
    required int durationDays,
    required int expiresDays,
    String? note,
  }) async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.generateCodes(
        type: type,
        count: count,
        durationDays: durationDays,
        expiresDays: expiresDays,
        note: note,
      );

      if (result['success'] == true) {
        final codes = result['codes'] as List?;
        _showSuccess('成功生成 ${codes?.length ?? count} 个兑换码');

        // 如果只生成了一个，自动复制
        if (codes != null && codes.length == 1) {
          Clipboard.setData(ClipboardData(text: codes.first.toString()));
          _showSuccess('已复制: ${codes.first}');
        }

        await _loadCodes();
      } else {
        setState(() => _isLoading = false);
        _showError(result['message'] ?? '生成失败');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('生成失败: $e');
    }
  }
}
