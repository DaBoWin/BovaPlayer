import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/design_system.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';

const Color _adminAccent = Color(0xFFE11D48);
const Color _adminAccentSoft = Color(0xFFFCE7F3);
const Color _adminCanvas = Color(0xFFF1F3F6);
const Color _adminPanelBorder = Color(0xFFE7EAF0);

class RedemptionAdminPage extends StatefulWidget {
  const RedemptionAdminPage({super.key});

  @override
  State<RedemptionAdminPage> createState() => _RedemptionAdminPageState();
}

class _RedemptionAdminPageState extends State<RedemptionAdminPage> {
  List<dynamic> _codes = [];
  bool _isLoading = false;
  String _filter = 'all';

  Map<String, String> _buildFilters(S l10n) => {
    'all': l10n.redemptionFilterAll,
    'unused': l10n.redemptionFilterUnused,
    'used': l10n.redemptionFilterUsed,
    'expired': l10n.redemptionFilterExpired,
  };

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
        _showError(result['message'] ?? S.of(context).redemptionLoadFailed);
      }
    } catch (error) {
      setState(() => _isLoading = false);
      _showError(S.of(context).redemptionLoadError(error.toString()));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: DesignSystem.error),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: DesignSystem.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final filters = _buildFilters(l10n);

    return Scaffold(
      backgroundColor: _adminCanvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: DesignSystem.neutral900,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.redemptionTitle,
          style: const TextStyle(
            fontSize: DesignSystem.textLg,
            fontWeight: DesignSystem.weightSemibold,
            color: DesignSystem.neutral900,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: DesignSystem.space3),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                boxShadow: DesignSystem.shadowSm,
              ),
              child: IconButton(
                icon: const Icon(Icons.add_rounded,
                    size: 18, color: _adminAccent),
                onPressed: _showGenerateDialog,
                tooltip: l10n.redemptionGenerateTooltip,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCodes,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHero(l10n),
                  const SizedBox(height: DesignSystem.space5),
                  _buildFilterBar(filters),
                  const SizedBox(height: DesignSystem.space4),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(
                        child: CircularProgressIndicator(color: _adminAccent),
                      ),
                    )
                  else if (_codes.isEmpty)
                    _buildEmptyState(l10n)
                  else
                    ..._codes.map((code) => Padding(
                          padding: const EdgeInsets.only(
                              bottom: DesignSystem.space3),
                          child: _buildCodeCard(code, l10n),
                        )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(S l10n) {
    return _buildPanel(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              _adminAccentSoft.withValues(alpha: 0.55),
              const Color(0xFFF8FAFC),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DesignSystem.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignSystem.space3,
                  vertical: DesignSystem.space1,
                ),
                decoration: BoxDecoration(
                  color: _adminAccentSoft,
                  borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
                ),
                child: const Text(
                  'Admin Workspace',
                  style: TextStyle(
                    fontSize: DesignSystem.textXs,
                    fontWeight: DesignSystem.weightSemibold,
                    color: _adminAccent,
                  ),
                ),
              ),
              const SizedBox(height: DesignSystem.space4),
              Text(
                l10n.redemptionHeroTitle,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: DesignSystem.weightBold,
                  color: DesignSystem.neutral900,
                  letterSpacing: -0.8,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: DesignSystem.space3),
              Text(
                l10n.redemptionHeroDesc,
                style: const TextStyle(
                  fontSize: DesignSystem.textSm,
                  color: DesignSystem.neutral600,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(Map<String, String> filters) {
    return _buildPanel(
      child: Wrap(
        spacing: DesignSystem.space2,
        runSpacing: DesignSystem.space2,
        children: filters.entries.map((entry) {
          final isActive = _filter == entry.key;
          return ChoiceChip(
            label: Text(entry.value),
            selected: isActive,
            labelStyle: TextStyle(
              fontSize: DesignSystem.textSm,
              color: isActive ? Colors.white : DesignSystem.neutral600,
              fontWeight: isActive
                  ? DesignSystem.weightSemibold
                  : DesignSystem.weightMedium,
            ),
            selectedColor: _adminAccent,
            backgroundColor: const Color(0xFFF8FAFC),
            side: BorderSide(
              color: isActive ? _adminAccent : _adminPanelBorder,
            ),
            onSelected: (_) {
              setState(() => _filter = entry.key);
              _loadCodes();
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(S l10n) {
    return _buildPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _adminAccentSoft,
                borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
              ),
              child: const Icon(
                Icons.confirmation_number_outlined,
                color: _adminAccent,
                size: 28,
              ),
            ),
            const SizedBox(height: DesignSystem.space4),
            Text(
              l10n.redemptionEmpty,
              style: const TextStyle(
                fontSize: DesignSystem.textLg,
                fontWeight: DesignSystem.weightSemibold,
                color: DesignSystem.neutral900,
              ),
            ),
            const SizedBox(height: DesignSystem.space2),
            Text(
              l10n.redemptionEmptyHint,
              style: const TextStyle(
                fontSize: DesignSystem.textSm,
                color: DesignSystem.neutral600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeCard(dynamic code, S l10n) {
    final isUsed = code['is_used'] == true;
    final isExpired = code['is_expired'] == true;
    final codeType = code['code_type'] as String? ?? 'pro';
    final codeValue = code['code'] as String? ?? '';

    late final Color statusColor;
    late final String statusText;
    late final IconData statusIcon;

    if (isUsed) {
      statusColor = DesignSystem.neutral500;
      statusText = l10n.redemptionStatusUsed;
      statusIcon = Icons.check_circle_rounded;
    } else if (isExpired) {
      statusColor = DesignSystem.error;
      statusText = l10n.redemptionStatusExpired;
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = DesignSystem.success;
      statusText = l10n.redemptionStatusAvailable;
      statusIcon = Icons.radio_button_checked_rounded;
    }

    final typeColor = codeType == 'lifetime'
        ? DesignSystem.accent700
        : const Color(0xFFA21CAF);
    final typeBg = codeType == 'lifetime'
        ? const Color(0xFFFFFBEB)
        : const Color(0xFFFAF5FF);

    return _buildPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SelectableText(
                  codeValue,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: DesignSystem.weightSemibold,
                    color: isUsed || isExpired
                        ? DesignSystem.neutral400
                        : DesignSystem.neutral900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: DesignSystem.space3),
              IconButton(
                icon: const Icon(
                  Icons.content_copy_rounded,
                  size: 18,
                  color: DesignSystem.neutral600,
                ),
                tooltip: l10n.redemptionCopyTooltip,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: codeValue));
                  _showSuccess(l10n.redemptionCopied);
                },
              ),
            ],
          ),
          const SizedBox(height: DesignSystem.space3),
          Wrap(
            spacing: DesignSystem.space2,
            runSpacing: DesignSystem.space2,
            children: [
              _buildBadge(
                icon: statusIcon,
                label: statusText,
                color: statusColor,
                background: statusColor.withValues(alpha: 0.10),
              ),
              _buildBadge(
                icon: codeType == 'lifetime'
                    ? Icons.auto_awesome_outlined
                    : Icons.workspace_premium_outlined,
                label: codeType == 'lifetime' ? l10n.redemptionTypeLifetime : l10n.redemptionTypePro,
                color: typeColor,
                background: typeBg,
              ),
            ],
          ),
          const SizedBox(height: DesignSystem.space4),
          Wrap(
            spacing: DesignSystem.space4,
            runSpacing: DesignSystem.space3,
            children: [
              _buildMeta(l10n.redemptionCreatedAt, _formatDate(code['created_at'])),
              _buildMeta(l10n.redemptionExpiresAt, _formatDate(code['expires_at'])),
              if (code['used_by'] != null)
                _buildMeta(l10n.redemptionUsedBy, code['used_by'].toString()),
              if (code['used_at'] != null)
                _buildMeta(l10n.redemptionUsedAt, _formatDate(code['used_at'])),
            ],
          ),
          if ((code['note'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: DesignSystem.space4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(DesignSystem.space4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
                border: Border.all(color: _adminPanelBorder),
              ),
              child: Text(
                code['note'].toString(),
                style: const TextStyle(
                  fontSize: DesignSystem.textSm,
                  color: DesignSystem.neutral600,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignSystem.space3,
        vertical: DesignSystem.space2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: DesignSystem.textXs,
              fontWeight: DesignSystem.weightSemibold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeta(String label, String value) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: DesignSystem.textXs,
              color: DesignSystem.neutral500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
              fontSize: DesignSystem.textSm,
              fontWeight: DesignSystem.weightMedium,
              color: DesignSystem.neutral900,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr.toString());
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr.toString();
    }
  }

  void _showGenerateDialog() {
    final l10n = S.of(context);
    String selectedType = 'pro';
    final countController = TextEditingController(text: '1');
    final durationController = TextEditingController(text: '30');
    final expiresController = TextEditingController(text: '365');
    final noteController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
          ),
          title: Text(
            l10n.redemptionGenerateTitle,
            style: const TextStyle(
              color: DesignSystem.neutral900,
              fontWeight: DesignSystem.weightSemibold,
            ),
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.redemptionGenerateDesc,
                    style: const TextStyle(
                      fontSize: DesignSystem.textSm,
                      color: DesignSystem.neutral600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: DesignSystem.space4),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeOption(
                          emoji: '💎',
                          label: l10n.redemptionTypePro,
                          active: selectedType == 'pro',
                          activeColor: const Color(0xFFA21CAF),
                          onTap: () =>
                              setDialogState(() => selectedType = 'pro'),
                        ),
                      ),
                      const SizedBox(width: DesignSystem.space3),
                      Expanded(
                        child: _buildTypeOption(
                          emoji: '👑',
                          label: l10n.redemptionTypeLifetime,
                          active: selectedType == 'lifetime',
                          activeColor: DesignSystem.accent700,
                          onTap: () =>
                              setDialogState(() => selectedType = 'lifetime'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignSystem.space4),
                  _buildInputField(countController, l10n.redemptionGenerateCount, l10n.redemptionGenerateCountHint,
                      isNumber: true),
                  const SizedBox(height: DesignSystem.space3),
                  if (selectedType == 'pro') ...[
                    _buildInputField(
                        durationController, l10n.redemptionProDuration, l10n.redemptionProDurationHint,
                        isNumber: true),
                    const SizedBox(height: DesignSystem.space3),
                  ],
                  _buildInputField(expiresController, l10n.redemptionCodeExpiry, l10n.redemptionCodeExpiryHint,
                      isNumber: true),
                  const SizedBox(height: DesignSystem.space3),
                  _buildInputField(noteController, l10n.redemptionNote, l10n.redemptionNoteHint),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                l10n.cancel,
                style: const TextStyle(color: DesignSystem.neutral600),
              ),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _generateCodes(
                  type: selectedType,
                  count: int.tryParse(countController.text) ?? 1,
                  durationDays: int.tryParse(durationController.text) ?? 30,
                  expiresDays: int.tryParse(expiresController.text) ?? 365,
                  note: noteController.text.trim().isEmpty
                      ? null
                      : noteController.text.trim(),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: _adminAccent,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.redemptionGenerate),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      countController.dispose();
      durationController.dispose();
      expiresController.dispose();
      noteController.dispose();
    });
  }

  Widget _buildTypeOption({
    required String emoji,
    required String label,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: DesignSystem.space4),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.08)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
          border: Border.all(
            color: active ? activeColor : _adminPanelBorder,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: TextStyle(fontSize: active ? 24 : 20)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: DesignSystem.textSm,
                fontWeight: DesignSystem.weightSemibold,
                color: active ? activeColor : DesignSystem.neutral600,
              ),
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
      style: const TextStyle(color: DesignSystem.neutral900, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
          color: DesignSystem.neutral600,
          fontSize: DesignSystem.textSm,
        ),
        hintStyle: const TextStyle(
          color: DesignSystem.neutral400,
          fontSize: DesignSystem.textSm,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
          borderSide: const BorderSide(color: _adminPanelBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
          borderSide: const BorderSide(color: _adminAccent, width: 1.5),
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
    final l10n = S.of(context);
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
        _showSuccess(l10n.redemptionGenerateSuccess(codes?.length ?? count));

        if (codes != null && codes.length == 1) {
          await Clipboard.setData(ClipboardData(text: codes.first.toString()));
          _showSuccess(l10n.redemptionCopiedCode(codes.first.toString()));
        }

        await _loadCodes();
      } else {
        setState(() => _isLoading = false);
        _showError(result['message'] ?? l10n.redemptionGenerateFailed);
      }
    } catch (error) {
      setState(() => _isLoading = false);
      _showError(l10n.redemptionGenerateError(error.toString()));
    }
  }

  Widget _buildPanel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(DesignSystem.space5),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
        border: Border.all(color: _adminPanelBorder),
        boxShadow: DesignSystem.shadowSm,
      ),
      child: child,
    );
  }
}
