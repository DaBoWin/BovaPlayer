import 'package:flutter/material.dart';
import 'models/network_connection.dart';
import 'models/network_file.dart';
import 'services/connection_manager.dart';
import 'services/ftp_service.dart';
import 'services/smb_service.dart';
import 'services/local_proxy_server.dart';
import 'player_window/desktop_player_window.dart';
import 'l10n/generated/app_localizations.dart';

class NetworkBrowserPage extends StatefulWidget {
  const NetworkBrowserPage({super.key});

  @override
  State<NetworkBrowserPage> createState() => _NetworkBrowserPageState();
}

class _NetworkBrowserPageState extends State<NetworkBrowserPage> {
  final ConnectionManager _connectionManager = ConnectionManager();
  final FTPService _ftpService = FTPService();
  final SMBService _smbService = SMBService();
  final LocalProxyServer _proxyServer = LocalProxyServer();

  List<NetworkConnection> _connections = [];
  NetworkConnection? _currentConnection;
  List<NetworkFile> _files = [];
  String _currentPath = '/';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConnections();
    _startProxyServer();
  }

  @override
  void dispose() {
    _ftpService.disconnect();
    _smbService.disconnect();
    _proxyServer.stop();
    super.dispose();
  }

  Future<void> _startProxyServer() async {
    try {
      await _proxyServer.start();
    } catch (e) {
      print('[NetworkBrowser] Failed to start proxy server: $e');
    }
  }

  Future<void> _loadConnections() async {
    setState(() => _isLoading = true);
    try {
      final connections = await _connectionManager.getConnections();
      setState(() {
        _connections = connections;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = S.of(context).netBrowserLoadConnectionsFailed(e.toString());
        _isLoading = false;
      });
    }
  }

  Future<void> _connectToServer(NetworkConnection connection) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      bool success = false;

      if (connection.protocol == NetworkProtocol.ftp) {
        success = await _ftpService.connect(connection);
      } else if (connection.protocol == NetworkProtocol.smb) {
        success = await _smbService.connect(connection);
      }

      if (success) {
        await _connectionManager.updateLastConnected(connection.id);
        setState(() {
          _currentConnection = connection;
          _currentPath = '/';
        });
        await _loadDirectory('/');
      } else {
        setState(() {
          _errorMessage = S.of(context).netBrowserConnectionFailed;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = S.of(context).netBrowserConnectionError(e.toString());
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDirectory(String path) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<NetworkFile> files = [];

      if (_currentConnection?.protocol == NetworkProtocol.ftp) {
        files = await _ftpService.listDirectory(path);
      } else if (_currentConnection?.protocol == NetworkProtocol.smb) {
        files = await _smbService.listDirectory(path);
      }

      setState(() {
        _files = files;
        _currentPath = path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = S.of(context).netBrowserLoadDirFailed(e.toString());
        _isLoading = false;
      });
    }
  }

  void _onFileSelected(NetworkFile file) {
    if (file.isDirectory) {
      _loadDirectory(file.path);
    } else if (file.isVideo) {
      _playVideo(file);
    }
  }

  Future<void> _playVideo(NetworkFile file) async {
    if (_currentConnection == null) return;

    try {
      final proxyUrl =
          _proxyServer.createProxyUrl(_currentConnection!, file.path);

      debugPrint('[NetworkBrowser] Playing video: ${file.name}');
      debugPrint('[NetworkBrowser] Proxy URL: $proxyUrl');

      if (mounted) {
        await DesktopPlayerLauncher.openPlayer(
          context: context,
          url: proxyUrl,
          title: file.name,
          httpHeaders: const {},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).netBrowserPlayFailed(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddConnectionDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddConnectionDialog(
        onSave: (connection) async {
          await _connectionManager.saveConnection(connection);
          await _loadConnections();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentConnection == null
            ? l10n.netBrowserTitle
            : '${_currentConnection!.displayName} - $_currentPath'),
        actions: [
          if (_currentConnection != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _ftpService.disconnect();
                setState(() {
                  _currentConnection = null;
                  _files = [];
                  _currentPath = '/';
                });
              },
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _currentConnection == null
          ? FloatingActionButton(
              onPressed: _showAddConnectionDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody() {
    final l10n = S.of(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _currentConnection == null
                  ? _loadConnections
                  : () => _loadDirectory(_currentPath),
              child: Text(l10n.netBrowserRetry),
            ),
          ],
        ),
      );
    }

    if (_currentConnection == null) {
      return _buildConnectionList();
    }

    return _buildFileList();
  }

  Widget _buildConnectionList() {
    final l10n = S.of(context);
    if (_connections.isEmpty) {
      return Center(
        child: Text(l10n.netBrowserNoConnections),
      );
    }

    return ListView.builder(
      itemCount: _connections.length,
      itemBuilder: (context, index) {
        final connection = _connections[index];
        return ListTile(
          leading: Icon(
            connection.protocol == NetworkProtocol.ftp
                ? Icons.folder_shared
                : Icons.storage,
          ),
          title: Text(connection.displayName),
          subtitle: Text(
              '${connection.protocolName} - ${connection.host}:${connection.port}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              await _connectionManager.deleteConnection(connection.id);
              await _loadConnections();
            },
          ),
          onTap: () => _connectToServer(connection),
        );
      },
    );
  }

  Widget _buildFileList() {
    final l10n = S.of(context);
    if (_files.isEmpty) {
      return Center(child: Text(l10n.netBrowserDirEmpty));
    }

    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        return ListTile(
          leading: Icon(
            file.isDirectory
                ? Icons.folder
                : (file.isVideo ? Icons.movie : Icons.insert_drive_file),
          ),
          title: Text(file.name),
          subtitle: file.isDirectory ? null : Text(file.sizeFormatted),
          onTap: () => _onFileSelected(file),
        );
      },
    );
  }
}

class _AddConnectionDialog extends StatefulWidget {
  final Function(NetworkConnection) onSave;

  const _AddConnectionDialog({required this.onSave});

  @override
  State<_AddConnectionDialog> createState() => _AddConnectionDialogState();
}

class _AddConnectionDialogState extends State<_AddConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '21');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _shareNameController = TextEditingController();
  final _workgroupController = TextEditingController(text: 'WORKGROUP');

  NetworkProtocol _protocol = NetworkProtocol.ftp;
  bool _savePassword = true;

  @override
  void initState() {
    super.initState();
    _updateDefaultPort();
  }

  void _updateDefaultPort() {
    if (_protocol == NetworkProtocol.ftp) {
      _portController.text = '21';
    } else if (_protocol == NetworkProtocol.smb) {
      _portController.text = '445';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return AlertDialog(
      title: Text(l10n.netBrowserAddConnection),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<NetworkProtocol>(
                value: _protocol,
                decoration: InputDecoration(labelText: l10n.netBrowserProtocol),
                items: const [
                  DropdownMenuItem(
                      value: NetworkProtocol.ftp, child: Text('FTP')),
                  DropdownMenuItem(
                      value: NetworkProtocol.smb, child: Text('SMB')),
                ],
                onChanged: (value) {
                  setState(() {
                    _protocol = value!;
                    _updateDefaultPort();
                  });
                },
              ),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: l10n.netBrowserName),
                validator: (v) => v?.isEmpty ?? true ? l10n.netBrowserEnterName : null,
              ),
              TextFormField(
                controller: _hostController,
                decoration: InputDecoration(labelText: l10n.netBrowserHost),
                validator: (v) => v?.isEmpty ?? true ? l10n.netBrowserEnterHost : null,
              ),
              TextFormField(
                controller: _portController,
                decoration: InputDecoration(labelText: l10n.netBrowserPort),
                keyboardType: TextInputType.number,
                validator: (v) => v?.isEmpty ?? true ? l10n.netBrowserEnterPort : null,
              ),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: l10n.netBrowserUsername),
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: l10n.netBrowserPassword),
                obscureText: true,
              ),
              if (_protocol == NetworkProtocol.smb) ...[
                TextFormField(
                  controller: _shareNameController,
                  decoration: InputDecoration(
                    labelText: l10n.netBrowserShareName,
                    hintText: l10n.netBrowserShareHint,
                  ),
                  validator: (v) => v?.isEmpty ?? true ? l10n.netBrowserEnterShareName : null,
                ),
                TextFormField(
                  controller: _workgroupController,
                  decoration: InputDecoration(
                    labelText: l10n.netBrowserWorkgroup,
                    hintText: l10n.netBrowserWorkgroupHint,
                  ),
                ),
              ],
              CheckboxListTile(
                title: Text(l10n.netBrowserSavePassword),
                value: _savePassword,
                onChanged: (v) => setState(() => _savePassword = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final connection = NetworkConnection(
        id: ConnectionManager().generateId(),
        protocol: _protocol,
        name: _nameController.text,
        host: _hostController.text,
        port: int.parse(_portController.text),
        username: _usernameController.text,
        password: _passwordController.text,
        shareName:
            _protocol == NetworkProtocol.smb ? _shareNameController.text : null,
        workgroup:
            _protocol == NetworkProtocol.smb ? _workgroupController.text : null,
        lastConnected: DateTime.now(),
        savePassword: _savePassword,
      );

      widget.onSave(connection);
      Navigator.pop(context);
    }
  }
}
