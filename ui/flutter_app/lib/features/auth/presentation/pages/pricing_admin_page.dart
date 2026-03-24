import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/design_system.dart';
import '../../../../features/billing/domain/entities/pricing_config.dart';
import '../../../../features/billing/presentation/providers/billing_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';

const Color _pricingAdminAccent = Color(0xFF2563EB);
const Color _pricingAdminAccentSoft = Color(0xFFDBEAFE);
const Color _pricingAdminCanvas = Color(0xFFF1F5F9);
const Color _pricingAdminPanelBorder = Color(0xFFE2E8F0);

class PricingAdminPage extends StatefulWidget {
  const PricingAdminPage({super.key});

  @override
  State<PricingAdminPage> createState() => _PricingAdminPageState();
}

class _PricingAdminPageState extends State<PricingAdminPage> {
  String _filter = 'all';
  bool _hasRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPricingConfigs(force: true);
    });
  }

  Future<void> _loadPricingConfigs({bool force = false}) async {
    final billingProvider = context.read<BillingProvider>();
    if (!force && (billingProvider.isLoadingPricingConfigs || _hasRequested)) {
      return;
    }

    _hasRequested = true;
    try {
      await billingProvider.loadPricingConfigs(includeInactive: true);
    } catch (error) {
      if (!mounted) return;
      _showError(S.of(context).pricingAdminLoadFailed(error.toString()));
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

  List<PricingConfig> _filterConfigs(List<PricingConfig> configs) {
    final sorted = [...configs]
      ..sort((a, b) {
        final orderCompare = a.sortOrder.compareTo(b.sortOrder);
        if (orderCompare != 0) return orderCompare;
        return a.planId.compareTo(b.planId);
      });

    switch (_filter) {
      case 'active':
        return sorted.where((item) => item.isActive).toList(growable: false);
      case 'inactive':
        return sorted.where((item) => !item.isActive).toList(growable: false);
      default:
        return sorted;
    }
  }

  String _formatPrice(double price) {
    if (price == price.roundToDouble()) {
      return '¥${price.toStringAsFixed(0)}';
    }
    return '¥${price.toStringAsFixed(1)}';
  }

  String _formatStorage(int storageQuotaMb) {
    if (storageQuotaMb <= 0) {
      return '—';
    }
    if (storageQuotaMb >= 1024) {
      final gb = storageQuotaMb / 1024;
      if (gb == gb.roundToDouble()) {
        return '${gb.toStringAsFixed(0)} GB';
      }
      return '${gb.toStringAsFixed(1)} GB';
    }
    return '$storageQuotaMb MB';
  }

  String _formatPeriod(PricingConfig config) {
    final l10n = S.of(context);
    switch (config.billingPeriod.trim()) {
      case 'month':
      case 'monthly':
        return l10n.pricingAdminPeriodMonth;
      case 'year':
      case 'yearly':
        return l10n.pricingAdminPeriodYear;
      case 'lifetime':
      case 'one_time':
        return l10n.pricingAdminPeriodOneTime;
      default:
        return config.billingPeriod;
    }
  }

  String _formatLimit(int limit) {
    if (limit < 0) {
      return S.of(context).pricingUnlimited;
    }
    return '$limit';
  }

  Color _planColor(PricingConfig config) {
    if (config.planId == 'lifetime') {
      return DesignSystem.accent700;
    }
    if (config.isActive) {
      return _pricingAdminAccent;
    }
    return DesignSystem.neutral500;
  }

  Future<void> _showEditDialog(PricingConfig config) async {
    final updated = await showDialog<PricingConfig>(
      context: context,
      builder: (_) => _PricingConfigEditorDialog(config: config),
    );

    if (updated == null || !mounted) {
      return;
    }

    final billingProvider = context.read<BillingProvider>();
    final l10n = S.of(context);
    try {
      await billingProvider.updatePricingConfig(config: updated);
      if (!mounted) return;
      _showSuccess(l10n.pricingAdminUpdateSuccess(updated.displayName));
    } catch (error) {
      if (!mounted) return;
      _showError(l10n.pricingAdminUpdateFailed(error.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final billingProvider = context.watch<BillingProvider>();
    final configs = _filterConfigs(billingProvider.pricingConfigs);
    final l10n = S.of(context);

    return Scaffold(
      backgroundColor: _pricingAdminCanvas,
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
          l10n.pricingAdminTitle,
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
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: _pricingAdminAccent,
                ),
                onPressed: billingProvider.isLoadingPricingConfigs
                    ? null
                    : () => _loadPricingConfigs(force: true),
                tooltip: l10n.pricingAdminRefreshTooltip,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadPricingConfigs(force: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHero(billingProvider),
                  const SizedBox(height: DesignSystem.space5),
                  _buildFilterBar(),
                  const SizedBox(height: DesignSystem.space4),
                  if (billingProvider.isLoadingPricingConfigs &&
                      billingProvider.pricingConfigs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _pricingAdminAccent,
                        ),
                      ),
                    )
                  else if (configs.isEmpty)
                    _buildEmptyState()
                  else
                    ...configs.map(
                      (config) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: DesignSystem.space3),
                        child: _buildConfigCard(config, billingProvider),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BillingProvider billingProvider) {
    final totalPlans = billingProvider.pricingConfigs.length;
    final activePlans = billingProvider.pricingConfigs.where((item) => item.isActive).length;
    final highestPrice = billingProvider.pricingConfigs.isEmpty
        ? '—'
        : _formatPrice(
            billingProvider.pricingConfigs
                .map((item) => item.priceCny)
                .reduce((a, b) => a > b ? a : b),
          );
    final l10n = S.of(context);

    return _buildPanel(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              _pricingAdminAccentSoft.withValues(alpha: 0.7),
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
                  color: _pricingAdminAccentSoft,
                  borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
                ),
                child: Text(
                  l10n.pricingAdminWorkspace,
                  style: const TextStyle(
                    fontSize: DesignSystem.textXs,
                    fontWeight: DesignSystem.weightSemibold,
                    color: _pricingAdminAccent,
                  ),
                ),
              ),
              const SizedBox(height: DesignSystem.space4),
              Text(
                l10n.pricingAdminHeadline,
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
                l10n.pricingAdminDescription,
                style: const TextStyle(
                  fontSize: DesignSystem.textSm,
                  color: DesignSystem.neutral600,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: DesignSystem.space5),
              Wrap(
                spacing: DesignSystem.space4,
                runSpacing: DesignSystem.space3,
                children: [
                  _StatChip(label: l10n.pricingAdminStatTotalPlans, value: '$totalPlans'),
                  _StatChip(label: l10n.pricingAdminStatActivePlans, value: '$activePlans'),
                  _StatChip(label: l10n.pricingAdminStatHighestPrice, value: highestPrice),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final l10n = S.of(context);
    final filters = <String, String>{
      'all': l10n.pricingAdminFilterAll,
      'active': l10n.pricingAdminFilterActive,
      'inactive': l10n.pricingAdminFilterInactive,
    };

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
            selectedColor: _pricingAdminAccent,
            backgroundColor: const Color(0xFFF8FAFC),
            side: BorderSide(
              color: isActive ? _pricingAdminAccent : _pricingAdminPanelBorder,
            ),
            onSelected: (_) {
              setState(() => _filter = entry.key);
            },
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = S.of(context);

    return _buildPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          children: [
            const Icon(
              Icons.sell_outlined,
              color: _pricingAdminAccent,
              size: 30,
            ),
            const SizedBox(height: DesignSystem.space4),
            Text(
              l10n.pricingAdminEmptyTitle,
              style: const TextStyle(
                fontSize: DesignSystem.textLg,
                fontWeight: DesignSystem.weightSemibold,
                color: DesignSystem.neutral900,
              ),
            ),
            const SizedBox(height: DesignSystem.space2),
            Text(
              l10n.pricingAdminEmptyHint,
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

  Widget _buildConfigCard(
    PricingConfig config,
    BillingProvider billingProvider,
  ) {
    final accent = _planColor(config);
    final l10n = S.of(context);

    return _buildPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: DesignSystem.space2,
                      runSpacing: DesignSystem.space2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          config.displayName,
                          style: const TextStyle(
                            fontSize: DesignSystem.textLg,
                            fontWeight: DesignSystem.weightSemibold,
                            color: DesignSystem.neutral900,
                          ),
                        ),
                        _Badge(
                          label: config.planId,
                          color: accent,
                          background: accent.withValues(alpha: 0.10),
                        ),
                        _Badge(
                          label: config.isActive
                              ? l10n.pricingAdminStatusActive
                              : l10n.pricingAdminStatusInactive,
                          color: config.isActive
                              ? DesignSystem.success
                              : DesignSystem.neutral500,
                          background: (config.isActive
                                  ? DesignSystem.success
                                  : DesignSystem.neutral500)
                              .withValues(alpha: 0.10),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignSystem.space2),
                    Text(
                      config.description,
                      style: const TextStyle(
                        fontSize: DesignSystem.textSm,
                        color: DesignSystem.neutral600,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DesignSystem.space3),
              FilledButton.tonalIcon(
                onPressed: billingProvider.isUpdatingPricingConfig
                    ? null
                    : () => _showEditDialog(config),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.edit),
                style: FilledButton.styleFrom(
                  foregroundColor: accent,
                  backgroundColor: accent.withValues(alpha: 0.10),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignSystem.space4),
          Wrap(
            spacing: DesignSystem.space4,
            runSpacing: DesignSystem.space3,
            children: [
              _MetaItem(label: l10n.pricingAdminPriceLabel, value: _formatPrice(config.priceCny)),
              _MetaItem(label: l10n.pricingAdminPeriodLabel, value: _formatPeriod(config)),
              _MetaItem(label: l10n.pricingAdminServersLabel, value: _formatLimit(config.maxServers)),
              _MetaItem(label: l10n.pricingAdminDevicesLabel, value: _formatLimit(config.maxDevices)),
              _MetaItem(label: l10n.pricingAdminStorageLabel, value: _formatStorage(config.storageQuotaMb)),
              _MetaItem(label: l10n.pricingAdminSortLabel, value: '${config.sortOrder}'),
            ],
          ),
          const SizedBox(height: DesignSystem.space4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DesignSystem.space4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
              border: Border.all(color: _pricingAdminPanelBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pricingAdminPaymentCopyTitle,
                  style: const TextStyle(
                    fontSize: DesignSystem.textSm,
                    fontWeight: DesignSystem.weightSemibold,
                    color: DesignSystem.neutral900,
                  ),
                ),
                const SizedBox(height: DesignSystem.space2),
                Text(
                  l10n.pricingAdminPaymentSubject(config.subject),
                  style: const TextStyle(
                    fontSize: DesignSystem.textXs,
                    color: DesignSystem.neutral700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: DesignSystem.space1),
                Text(
                  l10n.pricingAdminPaymentBody(config.body),
                  style: const TextStyle(
                    fontSize: DesignSystem.textXs,
                    color: DesignSystem.neutral700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(DesignSystem.space5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
        border: Border.all(color: _pricingAdminPanelBorder),
        boxShadow: DesignSystem.shadowMd,
      ),
      child: child,
    );
  }
}

class _PricingConfigEditorDialog extends StatefulWidget {
  const _PricingConfigEditorDialog({required this.config});

  final PricingConfig config;

  @override
  State<_PricingConfigEditorDialog> createState() =>
      _PricingConfigEditorDialogState();
}

class _PricingConfigEditorDialogState extends State<_PricingConfigEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _subjectController;
  late final TextEditingController _bodyController;
  late final TextEditingController _durationController;
  late final TextEditingController _maxServersController;
  late final TextEditingController _maxDevicesController;
  late final TextEditingController _storageController;
  late final TextEditingController _sortOrderController;

  late String _billingPeriod;
  late String _accountType;
  late String _subscriptionType;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final config = widget.config;
    _displayNameController = TextEditingController(text: config.displayName);
    _descriptionController = TextEditingController(text: config.description);
    _priceController = TextEditingController(text: config.priceCny.toString());
    _subjectController = TextEditingController(text: config.subject);
    _bodyController = TextEditingController(text: config.body);
    _durationController = TextEditingController(
      text: config.durationDays?.toString() ?? '',
    );
    _maxServersController = TextEditingController(text: '${config.maxServers}');
    _maxDevicesController = TextEditingController(text: '${config.maxDevices}');
    _storageController = TextEditingController(text: '${config.storageQuotaMb}');
    _sortOrderController = TextEditingController(text: '${config.sortOrder}');
    _billingPeriod = config.billingPeriod;
    _accountType = config.accountType;
    _subscriptionType = config.subscriptionType;
    _isActive = config.isActive;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    _durationController.dispose();
    _maxServersController.dispose();
    _maxDevicesController.dispose();
    _storageController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  int? _parseOptionalInt(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  int _parseRequiredInt(String value, {int fallback = 0}) {
    return int.tryParse(value.trim()) ?? fallback;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    final nextConfig = widget.config.copyWith(
      displayName: _displayNameController.text.trim(),
      description: _descriptionController.text.trim(),
      priceCny: double.parse(_priceController.text.trim()),
      billingPeriod: _billingPeriod,
      subject: _subjectController.text.trim(),
      body: _bodyController.text.trim(),
      subscriptionType: _subscriptionType,
      accountType: _accountType,
      durationDays: _parseOptionalInt(_durationController.text),
      maxServers: _parseRequiredInt(_maxServersController.text),
      maxDevices: _parseRequiredInt(_maxDevicesController.text),
      storageQuotaMb: _parseRequiredInt(_storageController.text),
      isActive: _isActive,
      sortOrder: _parseRequiredInt(_sortOrderController.text),
    );

    if (!mounted) return;
    Navigator.of(context).pop(nextConfig);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);

    return AlertDialog(
      title: Text(l10n.pricingAdminEditPlanTitle(widget.config.planId)),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(
                  controller: _displayNameController,
                  label: l10n.pricingAdminFieldDisplayName,
                ),
                _buildTextField(
                  controller: _descriptionController,
                  label: l10n.pricingAdminFieldDescription,
                  maxLines: 3,
                ),
                _buildTextField(
                  controller: _priceController,
                  label: l10n.pricingAdminFieldPriceCny,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    final parsed = double.tryParse((value ?? '').trim());
                    if (parsed == null || parsed < 0) {
                      return l10n.pricingAdminInvalidPrice;
                    }
                    return null;
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown<String>(
                        label: l10n.pricingAdminFieldBillingPeriod,
                        initialValue: _billingPeriod,
                        items: const ['month', 'year', 'lifetime', 'one_time'],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _billingPeriod = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: DesignSystem.space3),
                    Expanded(
                      child: _buildDropdown<String>(
                        label: l10n.pricingAdminFieldAccountType,
                        initialValue: _accountType,
                        items: const ['pro', 'lifetime', 'free'],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _accountType = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignSystem.space3),
                _buildDropdown<String>(
                  label: l10n.pricingAdminFieldSubscriptionType,
                  initialValue: _subscriptionType,
                  items: const ['subscription', 'one_time'],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _subscriptionType = value);
                    }
                  },
                ),
                _buildTextField(
                  controller: _durationController,
                  label: l10n.pricingAdminFieldDurationDaysOptional,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final trimmed = (value ?? '').trim();
                    if (trimmed.isEmpty) return null;
                    if (int.tryParse(trimmed) == null) {
                      return l10n.pricingAdminInvalidInteger;
                    }
                    return null;
                  },
                ),
                _buildTextField(
                  controller: _maxServersController,
                  label: l10n.pricingAdminFieldMaxServers,
                  keyboardType: TextInputType.number,
                  validator: _validateLimitInt,
                ),
                _buildTextField(
                  controller: _maxDevicesController,
                  label: l10n.pricingAdminFieldMaxDevices,
                  keyboardType: TextInputType.number,
                  validator: _validateLimitInt,
                ),
                _buildTextField(
                  controller: _storageController,
                  label: l10n.pricingAdminFieldStorageQuotaMb,
                  keyboardType: TextInputType.number,
                  validator: _validateRequiredInt,
                ),
                _buildTextField(
                  controller: _sortOrderController,
                  label: l10n.pricingAdminFieldSortOrder,
                  keyboardType: TextInputType.number,
                  validator: _validateRequiredInt,
                ),
                _buildTextField(
                  controller: _subjectController,
                  label: l10n.pricingAdminFieldPaymentSubject,
                ),
                _buildTextField(
                  controller: _bodyController,
                  label: l10n.pricingAdminFieldPaymentBody,
                  maxLines: 3,
                ),
                const SizedBox(height: DesignSystem.space2),
                SwitchListTile.adaptive(
                  value: _isActive,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.pricingAdminEnablePlan),
                  subtitle: Text(l10n.pricingAdminEnablePlanHint),
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignSystem.space3),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator ??
            (value) {
              if ((value ?? '').trim().isEmpty) {
                return S.of(context).pricingAdminRequired;
              }
              return null;
            },
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T initialValue,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    final normalizedItems = _normalizedDropdownItems(items);
    final normalizedInitialValue = _normalizeDropdownValue(initialValue);
    final effectiveInitialValue = normalizedItems.contains(normalizedInitialValue)
        ? normalizedInitialValue
        : normalizedItems.isNotEmpty
        ? normalizedItems.first
        : null;

    return DropdownButtonFormField<T>(
      initialValue: effectiveInitialValue,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: normalizedItems
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(_formatDropdownItem(item)),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        if (value == null) {
          onChanged(null);
          return;
        }
        onChanged(_normalizeDropdownValue(value));
      },
    );
  }

  List<T> _normalizedDropdownItems<T>(List<T> items) {
    final result = <T>[];
    final seen = <String>{};

    for (final item in items) {
      final normalized = _normalizeDropdownValue(item);
      final key = normalized.toString();
      if (seen.add(key)) {
        result.add(normalized);
      }
    }

    return result;
  }

  T _normalizeDropdownValue<T>(T value) {
    if (value is String) {
      switch (value) {
        case 'monthly':
          return 'month' as T;
        case 'yearly':
          return 'year' as T;
        case 'pro_monthly':
        case 'pro_yearly':
          return 'subscription' as T;
        case 'lifetime':
          return 'one_time' as T;
      }
    }

    return value;
  }

  String _formatDropdownItem<T>(T item) {
    final l10n = S.of(context);
    final value = item.toString();
    switch (value) {
      case 'month':
        return l10n.pricingAdminPeriodMonth;
      case 'year':
        return l10n.pricingAdminPeriodYear;
      case 'lifetime':
        return l10n.pricingPlanLifetime;
      case 'one_time':
        return l10n.pricingAdminPeriodOneTime;
      case 'pro':
        return l10n.pricingPlanPro;
      case 'free':
        return l10n.pricingPlanFree;
      case 'subscription':
        return l10n.pricingStarter;
      default:
        return value;
    }
  }

  String? _validateLimitInt(String? value) {
    final parsed = int.tryParse((value ?? '').trim());
    if (parsed == null || parsed < -1) {
      return S.of(context).pricingAdminInvalidInteger;
    }
    return null;
  }

  String? _validateRequiredInt(String? value) {
    final parsed = int.tryParse((value ?? '').trim());
    if (parsed == null || parsed < 0) {
      return S.of(context).pricingAdminInvalidNonNegativeInteger;
    }
    return null;
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignSystem.space4,
        vertical: DesignSystem.space3,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
      ),
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
          const SizedBox(height: DesignSystem.space1),
          Text(
            value,
            style: const TextStyle(
              fontSize: DesignSystem.textLg,
              fontWeight: DesignSystem.weightSemibold,
              color: DesignSystem.neutral900,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignSystem.space3,
        vertical: DesignSystem.space1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: DesignSystem.textXs,
          fontWeight: DesignSystem.weightSemibold,
          color: color,
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: DesignSystem.textXs,
            color: DesignSystem.neutral500,
          ),
        ),
        const SizedBox(height: DesignSystem.space1),
        Text(
          value,
          style: const TextStyle(
            fontSize: DesignSystem.textSm,
            fontWeight: DesignSystem.weightSemibold,
            color: DesignSystem.neutral900,
          ),
        ),
      ],
    );
  }
}
