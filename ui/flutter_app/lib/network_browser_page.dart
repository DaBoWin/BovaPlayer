import 'package:flutter/material.dart';
import 'network/network_protocol.dart';
import 'network/network_manager.dart';
import 'unified_player_page.dart';

class NetworkBrowserPage extends StatefulWidget {
  const NetworkBrowserPage({super.key});

  @override
  State<NetworkBrowserPage> createState() => _NetworkBrowserPageState();
}

class _NetworkBrowserPageState extends State<NetworkBrowserPage> {
  final _networkManager = NetworkManager();
  
  NetworkProtocol _selectedProtocol = NetworkProtocol.ftp;
  String _currentPath = '/';
  List<NetworkFile> _files = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // FTP 配置
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '21');
  final _usernameController = TextEditingController(text: 'anonymous');
  final _passwordController = TextEditingController();
  bool _passiveMode = true;
  
  // SMB 配置
  final _shareNameController = TextEditingController();
  final _workgroupController = TextEditingController();
  
  List<NetworkConnection> _connectionHistory = [];

  @override
  void initState() {
    super.initState();
    _loadConnectionHistory();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _shareNameController.dispose();
    _workgroupController.dispose();
    super.dispose();
  }

  Future<void> _loadConnectionHistory() async {
    final history = await _networkManager.getConnectionHistory();
    setState(() {
      _connectionHistory = history;
    });
  }

  Future<void> _connect() async {
    if (_hostController.text.isEmpty) {
      _showError('请输入服务器地址');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final connection = NetworkConnection(
        protocol: _selectedProtocol,
        host: _hostController.text.trim(),
        port: int.tryParse(_portController.text) ?? 
              (_selectedProtocol == NetworkProtocol.smb ? 445 : 21),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        passive: _passiveMode,
        shareName: _selectedProtocol == NetworkProtocol.smb 
            ? _shareNameController.text.trim() 
            : null,
        workgroup: _selectedProtocol == NetworkProtocol.smb 
            ? _workgroupController.text.trim() 
            : null,
      );

      final success = await _networkManager.connect(connection);
      
      if (success) {
        await _loadDirectory('/');
        await _loadConnectionHistory();
      } else {
        _showError('连接失败');
      }
    } catch (e) {
      _showError('连接错误: $e');
    } finally {
      setState(() {
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
      final files = await _networkManager.listDirectory(path);
      setState(() {
        _currentPath = path;
        _files = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('加载目录失败: $e');
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _playFile(NetworkFile file) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final url = await _networkManager.getPlayableUrl(file.path);
      
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UnifiedPlayerPage(
            url: url,
            title: file.name,
          ),
        ),
      );
    } catch (e) {
      _showError('播放失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _goBack() {
    if (_currentPath == '/' || _currentPath.isEmpty) return;
    
    final parts = _currentPath.split('/');
    parts.removeLast();
    final parentPath = parts.isEmpty ? '/' : parts.join('/');
    _loadDirectory(parentPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          '网络播放',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
        actions: [
          if (_networkManager.isConnected)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () async {
                await _networkManager.disconnect();
                setState(() {
                  _files = [];
                  _currentPath = '/';
                });
              },
              tooltip: '断开连接',
            ),
        ],
      ),
      body: _networkManager.isConnected
          ? _buildFileBrowser()
          : _buildConnectionForm(),
    );
  }

  Widget _buildConnectionForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 协议选择
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '选择协议',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildProtocolChip(NetworkProtocol.ftp, 'FTP'),
                      _buildProtocolChip(NetworkProtocol.smb, 'SMB'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 连接配置
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '连接配置',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _hostController,
                    label: '服务器地址',
                    hint: '例如: 192.168.1.100',
                    icon: Icons.dns,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  _buildTextField(
                    controller: _portController,
                    label: '端口',
                    hint: '21',
                    icon: Icons.settings_ethernet,
                    keyboardType: TextInputType.number,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  _buildTextField(
                    controller: _usernameController,
                    label: '用户名',
                    hint: 'anonymous',
                    icon: Icons.person,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  _buildTextField(
                    controller: _passwordController,
                    label: '密码',
                    hint: '可选',
                    icon: Icons.lock,
                    obscureText: true,
                  ),
                  
                  if (_selectedProtocol == NetworkProtocol.smb) ...[
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _shareNameController,
                      label: '共享名称',
                      hint: '例如: share',
                      icon: Icons.folder_shared,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _workgroupController,
                      label: '工作组',
                      hint: '可选，例如: WORKGROUP',
                      icon: Icons.workspaces,
                    ),
                  ],
                  
                  if (_selectedProtocol == NetworkProtocol.ftp) ...[
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text(
                        '被动模式',
                        style: TextStyle(color: Color(0xFF1F2937)),
                      ),
                      subtitle: const Text(
                        '推荐开启',
                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                      ),
                      value: _passiveMode,
                      onChanged: (value) {
                        setState(() {
                          _passiveMode = value;
                        });
                      },
                      activeColor: const Color(0xFF1F2937),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 连接按钮
          ElevatedButton(
            onPressed: _isLoading ? null : _connect,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F2937),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    '连接',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
          
          // 连接历史
          if (_connectionHistory.isNotEmpty) ...[
            const SizedBox(height: 30),
            const Text(
              '最近连接',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._connectionHistory.map((conn) => _buildHistoryItem(conn)),
          ],
        ],
      ),
    );
  }

  Widget _buildProtocolChip(NetworkProtocol protocol, String label) {
    final isSelected = _selectedProtocol == protocol;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedProtocol = protocol;
            // 更新默认端口
            if (protocol == NetworkProtocol.ftp) {
              _portController.text = '21';
            } else if (protocol == NetworkProtocol.smb) {
              _portController.text = '445';
            }
          });
        }
      },
      backgroundColor: const Color(0xFFF3F4F6),
      selectedColor: const Color(0xFF1F2937),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF6B7280),
      ),
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFF1F2937)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF6B7280)),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        prefixIcon: Icon(icon, color: Color(0xFF6B7280)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1F2937), width: 2),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(NetworkConnection conn) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(
          conn.protocol == NetworkProtocol.ftp ? Icons.cloud : Icons.folder_shared,
          color: const Color(0xFF1F2937),
        ),
        title: Text(
          conn.displayName,
          style: const TextStyle(color: Color(0xFF1F2937)),
        ),
        subtitle: Text(
          conn.username ?? 'anonymous',
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF9CA3AF), size: 16),
        onTap: () {
          _hostController.text = conn.host;
          _portController.text = conn.port.toString();
          _usernameController.text = conn.username ?? '';
          setState(() {
            _selectedProtocol = conn.protocol;
            _passiveMode = conn.passive;
          });
        },
      ),
    );
  }

  Widget _buildFileBrowser() {
    return Column(
      children: [
        // 面包屑导航
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              if (_currentPath != '/')
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
                  onPressed: _goBack,
                ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    _currentPath.isEmpty ? '/' : _currentPath,
                    style: const TextStyle(color: Color(0xFF1F2937), fontSize: 14),
                  ),
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1F2937)),
                  ),
                ),
            ],
          ),
        ),
        
        // 文件列表
        Expanded(
          child: _files.isEmpty
              ? Center(
                  child: Text(
                    _isLoading ? '加载中...' : '目录为空',
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    return _buildFileItem(file);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFileItem(NetworkFile file) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(
          file.isDirectory ? Icons.folder : Icons.video_file,
          color: file.isDirectory ? const Color(0xFFF59E0B) : const Color(0xFF1F2937),
          size: 32,
        ),
        title: Text(
          file.name,
          style: const TextStyle(color: Color(0xFF1F2937)),
        ),
        subtitle: file.isDirectory
            ? null
            : Text(
                file.displaySize,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF9CA3AF), size: 16),
        onTap: () {
          if (file.isDirectory) {
            _loadDirectory(file.path);
          } else if (file.isVideoFile) {
            _playFile(file);
          } else {
            _showError('不支持的文件类型');
          }
        },
      ),
    );
  }
}
