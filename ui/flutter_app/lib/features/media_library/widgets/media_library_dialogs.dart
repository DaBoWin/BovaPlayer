import 'package:flutter/material.dart';

import '../../../core/theme/design_system.dart';
import '../../../core/theme/bova_icons.dart';
import '../../../core/widgets/bova_button.dart';
import '../../../core/widgets/bova_card.dart';
import '../../../core/widgets/bova_text_field.dart';
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
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(DesignSystem.radiusXl)),
    ),
    builder: (context) => SafeArea(
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
                color: DesignSystem.neutral300,
                borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
              ),
            ),
            const SizedBox(height: DesignSystem.space4),
            const Text(
              '添加媒体源',
              style: TextStyle(
                fontSize: DesignSystem.textLg,
                fontWeight: DesignSystem.weightSemibold,
                color: DesignSystem.neutral900,
              ),
            ),
            const SizedBox(height: DesignSystem.space2),
            const Text(
              '选择一种协议，继续配置新的内容入口。',
              style: TextStyle(
                fontSize: DesignSystem.textSm,
                color: DesignSystem.neutral600,
              ),
            ),
            const SizedBox(height: DesignSystem.space4),
            _SheetTile(
              icon: BovaIcons.cloudOutline,
              title: 'Emby 服务器',
              subtitle: '连接媒体服务与元数据管理',
              onTap: () {
                Navigator.pop(context);
                onSelected(SourceType.emby);
              },
            ),
            _SheetTile(
              icon: BovaIcons.folderOutline,
              title: 'SMB 共享',
              subtitle: '添加局域网共享目录',
              onTap: () {
                Navigator.pop(context);
                onSelected(SourceType.smb);
              },
            ),
            _SheetTile(
              icon: BovaIcons.uploadOutline,
              title: 'FTP 服务器',
              subtitle: '访问远程文件服务器',
              onTap: () {
                Navigator.pop(context);
                onSelected(SourceType.ftp);
              },
            ),
          ],
        ),
      ),
    ),
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
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(DesignSystem.radiusXl)),
    ),
    builder: (context) => SafeArea(
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
                color: DesignSystem.neutral300,
                borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
              ),
            ),
            const SizedBox(height: DesignSystem.space4),
            Text(
              source.name,
              style: const TextStyle(
                fontSize: DesignSystem.textLg,
                fontWeight: DesignSystem.weightSemibold,
                color: DesignSystem.neutral900,
              ),
            ),
            const SizedBox(height: DesignSystem.space4),
            _ActionTile(
              icon: BovaIcons.editOutline,
              title: '编辑媒体源',
              color: DesignSystem.neutral800,
              onTap: () {
                Navigator.pop(context);
                onEdit();
              },
            ),
            _ActionTile(
              icon: BovaIcons.deleteOutline,
              title: '删除媒体源',
              color: DesignSystem.error,
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    ),
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
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
      ),
      title: Text(isEdit ? '编辑 Emby 服务器' : '添加 Emby 服务器'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(nameCtrl, '名称', '我的 Emby'),
              const SizedBox(height: DesignSystem.space4),
              _dialogField(urlCtrl, '服务器地址', 'https://your-server:8096'),
              const SizedBox(height: DesignSystem.space4),
              _dialogField(userCtrl, '用户名', ''),
              const SizedBox(height: DesignSystem.space4),
              _dialogField(passCtrl, '密码', '', obscure: true),
            ],
          ),
        ),
      ),
      actions: [
        BovaButton(
          text: '取消',
          style: BovaButtonStyle.ghost,
          onPressed: () => Navigator.pop(ctx),
        ),
        BovaButton(
          text: isEdit ? '保存' : '添加',
          onPressed: () {
            final name = nameCtrl.text.trim();
            final url = urlCtrl.text.trim();
            final user = userCtrl.text.trim();
            if (name.isEmpty || url.isEmpty || user.isEmpty) {
              _showInlineError(ctx, '请填写所有必填字段');
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
    ),
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
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
        ),
        title: Text(isEdit ? '编辑媒体源' : '添加媒体源'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(nameCtrl, '名称', '例如：家庭服务器'),
                const SizedBox(height: DesignSystem.space4),
                _dialogField(hostCtrl, '主机地址', '192.168.1.100'),
                const SizedBox(height: DesignSystem.space4),
                _dialogField(
                  portCtrl,
                  '端口',
                  type == SourceType.ftp ? '21' : '445',
                  isNumber: true,
                ),
                const SizedBox(height: DesignSystem.space4),
                _dialogField(userCtrl, '用户名', ''),
                const SizedBox(height: DesignSystem.space4),
                _dialogField(passCtrl, '密码', '', obscure: true),
                if (type == SourceType.smb) ...[
                  const SizedBox(height: DesignSystem.space4),
                  _dialogField(shareNameCtrl, '共享名', '例如：share, movies'),
                  const SizedBox(height: DesignSystem.space4),
                  _dialogField(workgroupCtrl, '工作组', 'WORKGROUP'),
                ],
                CheckboxListTile(
                  value: savePassword,
                  contentPadding: EdgeInsets.zero,
                  activeColor: DesignSystem.accent600,
                  title: const Text('保存密码'),
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
            text: '取消',
            style: BovaButtonStyle.ghost,
            onPressed: () => Navigator.pop(ctx),
          ),
          BovaButton(
            text: isEdit ? '保存' : '添加',
            onPressed: () {
              final name = nameCtrl.text.trim();
              final host = hostCtrl.text.trim();
              final port = int.tryParse(portCtrl.text.trim());
              if (name.isEmpty || host.isEmpty || port == null) {
                _showInlineError(ctx, '请填写所有必填字段');
                return;
              }
              if (type == SourceType.smb && shareNameCtrl.text.trim().isEmpty) {
                _showInlineError(ctx, '请输入共享名');
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
      ),
    ),
  );
}

Future<bool> showDeleteSourceDialog(
  BuildContext context,
  MediaSource source,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
      ),
      title: const Text('确认删除'),
      content: Text('确定要删除“${source.name}”吗？'),
      actions: [
        BovaButton(
          text: '取消',
          style: BovaButtonStyle.ghost,
          onPressed: () => Navigator.pop(ctx, false),
        ),
        BovaButton(
          text: '删除',
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
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
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: DesignSystem.error,
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
                color: DesignSystem.neutral100,
                borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
              ),
              child: Icon(icon, color: DesignSystem.neutral800),
            ),
            const SizedBox(width: DesignSystem.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: DesignSystem.textBase,
                      fontWeight: DesignSystem.weightSemibold,
                      color: DesignSystem.neutral900,
                    ),
                  ),
                  const SizedBox(height: DesignSystem.space1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: DesignSystem.textSm,
                      color: DesignSystem.neutral600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(BovaIcons.chevronRight, color: DesignSystem.neutral500),
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
          color: DesignSystem.neutral500,
          size: 20,
        ),
        onPressed: () => setState(() => _obscureText = !_obscureText),
      ),
    );
  }
}
