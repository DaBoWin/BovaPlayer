import 'package:flutter/material.dart';

import '../../../core/theme/design_system.dart';
import '../../../core/theme/bova_icons.dart';
import '../../../core/widgets/bova_button.dart';
import '../../../core/widgets/bova_card.dart';
import '../../../core/widgets/bova_text_field.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/media_source.dart';

class EmbySourceFormData {
  final String name;
  final String url;
  final String username;
  final String password;

  const EmbySourceFormData({
    required this.name,
    required this.url,
    required this.username,
    required this.password,
  });
}

class NetworkSourceFormData {
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final String shareName;
  final String workgroup;
  final bool savePassword;

  const NetworkSourceFormData({
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.shareName,
    required this.workgroup,
    required this.savePassword,
  });
}

Future<void> showAddSourcePickerSheet(
  BuildContext context, {
  required ValueChanged<SourceType> onSelected,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(DesignSystem.radiusXl)),
    ),
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DesignSystem.space4,
            DesignSystem.space3,
            DesignSystem.space4,
            DesignSystem.space5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
                ),
              ),
              const SizedBox(height: DesignSystem.space4),
              Text(
                S.of(context).mediaSourceAdd,
                style: TextStyle(
                  fontSize: DesignSystem.textLg,
                  fontWeight: DesignSystem.weightSemibold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: DesignSystem.space2),
              Text(
                S.of(context).mediaSourceSelectProtocol,
                style: TextStyle(
                  fontSize: DesignSystem.textSm,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: DesignSystem.space4),
              _SheetTile(
                icon: BovaIcons.cloudOutline,
                title: S.of(context).addEmbyServer,
                subtitle: S.of(context).mediaSourceEmbyDesc,
                onTap: () {
                  Navigator.pop(context);
                  onSelected(SourceType.emby);
                },
              ),
              _SheetTile(
                icon: BovaIcons.folderOutline,
                title: S.of(context).addSmbShare,
                subtitle: S.of(context).mediaSourceSmbDesc,
                onTap: () {
                  Navigator.pop(context);
                  onSelected(SourceType.smb);
                },
              ),
              _SheetTile(
                icon: BovaIcons.uploadOutline,
                title: S.of(context).addFtpServer,
                subtitle: S.of(context).mediaSourceFtpDesc,
                onTap: () {
                  Navigator.pop(context);
                  onSelected(SourceType.ftp);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showSourceOptionsSheet(
  BuildContext context, {
  required MediaSource source,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(DesignSystem.radiusXl)),
    ),
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DesignSystem.space4,
            DesignSystem.space3,
            DesignSystem.space4,
            DesignSystem.space5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
                ),
              ),
              const SizedBox(height: DesignSystem.space4),
              Text(
                source.name,
                style: TextStyle(
                  fontSize: DesignSystem.textLg,
                  fontWeight: DesignSystem.weightSemibold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: DesignSystem.space4),
              _ActionTile(
                icon: BovaIcons.editOutline,
                title: S.of(context).mediaSourceEdit,
                color: scheme.onSurface,
                onTap: () {
                  Navigator.pop(context);
                  onEdit();
                },
              ),
              _ActionTile(
                icon: BovaIcons.deleteOutline,
                title: S.of(context).mediaSourceDelete,
                color: scheme.error,
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<EmbySourceFormData?> showEmbySourceDialog(
  BuildContext context, {
  MediaSource? initialSource,
}) {
  final isEdit = initialSource != null;
  final nameCtrl = TextEditingController(text: initialSource?.name ?? '');
  final urlCtrl = TextEditingController(text: initialSource?.url ?? 'https://');
  final userCtrl = TextEditingController(text: initialSource?.username ?? '');
  final passCtrl = TextEditingController(text: initialSource?.password ?? '');

  return showDialog<EmbySourceFormData>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return AlertDialog(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
        ),
        title: Text(
          isEdit ? S.of(context).embyEditServer : S.of(context).embyAddServer,
          style: TextStyle(color: scheme.onSurface),
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(nameCtrl, S.of(context).embyServerName, S.of(context).embyServerNameHint),
                const SizedBox(height: DesignSystem.space4),
                _dialogField(urlCtrl, S.of(context).embyServerAddress, 'https://your-server:8096'),
                const SizedBox(height: DesignSystem.space4),
                _dialogField(userCtrl, S.of(context).embyUsername, ''),
                const SizedBox(height: DesignSystem.space4),
                _dialogField(passCtrl, S.of(context).embyPassword, '', obscure: true),
              ],
            ),
          ),
        ),
        actions: [
          BovaButton(
            text: S.of(context).cancel,
            style: BovaButtonStyle.ghost,
            onPressed: () => Navigator.pop(ctx),
          ),
          BovaButton(
            text: isEdit ? S.of(context).save : S.of(context).add,
            onPressed: () {
              final name = nameCtrl.text.trim();
              final url = urlCtrl.text.trim();
              final user = userCtrl.text.trim();
              if (name.isEmpty || url.isEmpty || user.isEmpty) {
                _showInlineError(ctx, S.of(ctx).mediaSourceFillRequired);
                return;
              }
              Navigator.pop(
                ctx,
                EmbySourceFormData(
                  name: name,
                  url: url,
                  username: user,
                  password: passCtrl.text,
                ),
              );
            },
          ),
        ],
      );
    },
  );
}

Future<NetworkSourceFormData?> showNetworkSourceDialog(
  BuildContext context, {
  required SourceType type,
  MediaSource? initialSource,
}) {
  final isEdit = initialSource != null;
  final parsedUri =
      initialSource != null ? Uri.tryParse(initialSource.url) : null;
  final nameCtrl = TextEditingController(text: initialSource?.name ?? '');
  final hostCtrl = TextEditingController(text: parsedUri?.host ?? '');
  final portCtrl = TextEditingController(
    text: parsedUri?.port.toString() ?? (type == SourceType.ftp ? '21' : '445'),
  );
  final userCtrl = TextEditingController(text: initialSource?.username ?? '');
  final passCtrl = TextEditingController(text: initialSource?.password ?? '');
  final shareNameCtrl = TextEditingController(
    text: type == SourceType.smb ? (initialSource?.shareName ?? '') : '',
  );
  final workgroupCtrl = TextEditingController(
    text: type == SourceType.smb
        ? (initialSource?.workgroup ?? 'WORKGROUP')
        : 'WORKGROUP',
  );
  var savePassword = initialSource?.password.isNotEmpty ?? true;

  return showDialog<NetworkSourceFormData>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
          ),
          title: Text(
            isEdit ? S.of(context).mediaSourceEdit : S.of(context).mediaSourceAdd,
            style: TextStyle(color: scheme.onSurface),
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField(nameCtrl, S.of(context).embyServerName, S.of(context).mediaSourceNameHint),
                  const SizedBox(height: DesignSystem.space4),
                  _dialogField(hostCtrl, S.of(context).mediaSourceHostAddress, '192.168.1.100'),
                  const SizedBox(height: DesignSystem.space4),
                  _dialogField(
                    portCtrl,
                    S.of(context).mediaSourcePort,
                    type == SourceType.ftp ? '21' : '445',
                    isNumber: true,
                  ),
                  const SizedBox(height: DesignSystem.space4),
                  _dialogField(userCtrl, S.of(context).embyUsername, ''),
                  const SizedBox(height: DesignSystem.space4),
                  _dialogField(passCtrl, S.of(context).embyPassword, '', obscure: true),
                  if (type == SourceType.smb) ...[
                    const SizedBox(height: DesignSystem.space4),
                    _dialogField(shareNameCtrl, S.of(context).mediaSourceShareName, S.of(context).mediaSourceShareNameHint),
                    const SizedBox(height: DesignSystem.space4),
                    _dialogField(workgroupCtrl, S.of(context).mediaSourceWorkgroup, 'WORKGROUP'),
                  ],
                  CheckboxListTile(
                    value: savePassword,
                    contentPadding: EdgeInsets.zero,
                    activeColor: scheme.primary,
                    title: Text(
                      S.of(context).mediaSourceSavePassword,
                      style: TextStyle(color: scheme.onSurface),
                    ),
                    onChanged: (value) {
                      setDialogState(() => savePassword = value ?? true);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            BovaButton(
              text: S.of(context).cancel,
              style: BovaButtonStyle.ghost,
              onPressed: () => Navigator.pop(ctx),
            ),
            BovaButton(
              text: isEdit ? S.of(context).save : S.of(context).add,
              onPressed: () {
                final name = nameCtrl.text.trim();
                final host = hostCtrl.text.trim();
                final port = int.tryParse(portCtrl.text.trim());
                if (name.isEmpty || host.isEmpty || port == null) {
                  _showInlineError(ctx, S.of(ctx).mediaSourceFillRequired);
                  return;
                }
                if (type == SourceType.smb && shareNameCtrl.text.trim().isEmpty) {
                  _showInlineError(ctx, S.of(ctx).mediaSourceEnterShareName);
                  return;
                }
                Navigator.pop(
                  ctx,
                  NetworkSourceFormData(
                    name: name,
                    host: host,
                    port: port,
                    username: userCtrl.text.trim(),
                    password: savePassword ? passCtrl.text : '',
                    shareName: shareNameCtrl.text.trim(),
                    workgroup: workgroupCtrl.text.trim(),
                    savePassword: savePassword,
                  ),
                );
              },
            ),
          ],
        );
      },
    ),
  );
}

Future<bool> showDeleteSourceDialog(
  BuildContext context,
  MediaSource source,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return AlertDialog(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
        ),
        title: Text(
          S.of(context).confirm,
          style: TextStyle(color: scheme.onSurface),
        ),
        content: Text(
          S.of(context).mediaSourceDeleteConfirm(source.name),
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        actions: [
          BovaButton(
            text: S.of(context).cancel,
            style: BovaButtonStyle.ghost,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          BovaButton(
            text: S.of(context).delete,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      );
    },
  );
  return result == true;
}

Widget _dialogField(
  TextEditingController controller,
  String label,
  String hint, {
  bool obscure = false,
  bool isNumber = false,
}) {
  if (obscure) {
    return _PasswordField(controller: controller, label: label, hint: hint);
  }
  return BovaTextField(
    controller: controller,
    label: label,
    hint: hint,
    keyboardType: isNumber ? TextInputType.number : TextInputType.text,
  );
}

void _showInlineError(BuildContext context, String message) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: scheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
      ),
    ),
  );
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SheetTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignSystem.space3),
      child: BovaCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
              ),
              child: Icon(icon, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: DesignSystem.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: DesignSystem.textBase,
                      fontWeight: DesignSystem.weightSemibold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: DesignSystem.space1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: DesignSystem.textSm,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(BovaIcons.chevronRight, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignSystem.space3),
      child: BovaCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: DesignSystem.space3),
            Text(
              title,
              style: TextStyle(
                fontSize: DesignSystem.textBase,
                fontWeight: DesignSystem.weightMedium,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BovaTextField(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint,
      obscureText: _obscureText,
      suffixIcon: IconButton(
        icon: Icon(
          _obscureText
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: scheme.onSurfaceVariant,
          size: 20,
        ),
        onPressed: () => setState(() => _obscureText = !_obscureText),
      ),
    );
  }
}
