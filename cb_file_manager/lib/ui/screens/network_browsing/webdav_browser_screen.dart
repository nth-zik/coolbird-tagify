import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:remixicon/remixicon.dart' as remix;
import 'package:path/path.dart' as path;

import '../../../bloc/network_browsing/network_browsing_bloc.dart';
import '../../../bloc/network_browsing/network_browsing_event.dart';
import '../../../bloc/network_browsing/network_browsing_state.dart';
import '../../../services/network_browsing/network_service_base.dart';
import '../../../services/network_credentials_service.dart';
import '../../../models/database/network_credentials.dart';
import '../../tab_manager/core/tab_manager.dart';
import '../../utils/fluent_background.dart';
import '../system_screen.dart';
import 'network_connection_dialog.dart';

/// Screen for browsing WebDAV directories
class WebDAVBrowserScreen extends StatefulWidget {
  final String tabId;

  const WebDAVBrowserScreen({
    Key? key,
    required this.tabId,
  }) : super(key: key);

  @override
  State<WebDAVBrowserScreen> createState() => _WebDAVBrowserScreenState();
}

class _WebDAVBrowserScreenState extends State<WebDAVBrowserScreen>
    with WidgetsBindingObserver {
  final NetworkCredentialsService _credentialsService =
      NetworkCredentialsService();
  late NetworkBrowsingBloc _networkBloc;

  List<NetworkCredentials> _savedCredentials = [];
  Set<int> _connectingCredentialIds = {};
  Map<String, int> _pendingTabCredentialMap = {};

  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _basePathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _networkBloc = BlocProvider.of<NetworkBrowsingBloc>(context, listen: false);

    _setupBlocListener();
    _refreshData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hostController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _portController.dispose();
    _basePathController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshData();
  }

  void _setupBlocListener() {
    _networkBloc.stream.listen((state) {
      if (!mounted) return;

      if (state.lastSuccessfullyConnectedPath != null) {
        _handleSuccessfulConnection(state.lastSuccessfullyConnectedPath!);
      }

      bool hadError = false;
      if (state.errorMessage != null && _connectingCredentialIds.isNotEmpty) {
        hadError = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi kết nối: ${state.errorMessage}')),
        );
      }

      setState(() {
        if (hadError || state.lastSuccessfullyConnectedPath != null) {
          _connectingCredentialIds.clear();
        }
      });
    });
  }

  void _handleSuccessfulConnection(String connectionPath) {
    if (!connectionPath.startsWith('#network/WebDAV/')) return;

    final host = Uri.decodeComponent(connectionPath.split('/')[2]);

    final credentialId = _pendingTabCredentialMap[host];
    if (credentialId != null) {
      _openTabForConnection(connectionPath, host);
      _pendingTabCredentialMap.remove(host);
    }
  }

  void _refreshData() {
    if (mounted) {
      setState(() {
        _loadSavedCredentials();
      });
      _networkBloc.add(const NetworkServicesListRequested());
    }
  }

  void _loadSavedCredentials() {
    try {
      _savedCredentials =
          _credentialsService.getCredentialsByServiceType('WebDAV');
    } catch (e) {
      debugPrint('Lỗi khi tải thông tin đăng nhập đã lưu: $e');
    }
  }

  void _connectToWebDAVServer() {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: _networkBloc,
        child: const NetworkConnectionDialog(initialService: 'WebDAV'),
      ),
    ).then((_) => _refreshData());
  }

  void _connectWithSavedCredentials(NetworkCredentials credentials) {
    setState(() {
      _connectingCredentialIds.add(credentials.id);
      _pendingTabCredentialMap[credentials.host] = credentials.id;
    });

    // Parse additional options
    Map<String, dynamic> additionalOptions = {};
    if (credentials.additionalOptions != null) {
      try {
        additionalOptions = Map<String, dynamic>.from(
          jsonDecode(credentials.additionalOptions!),
        );
      } catch (e) {
        debugPrint('Error parsing additional options: $e');
      }
    }

    _networkBloc.add(NetworkConnectionRequested(
      serviceName: 'WebDAV',
      host: credentials.host,
      username: credentials.username,
      password: credentials.password,
      port: credentials.port,
      additionalOptions: additionalOptions,
    ));
  }

  void _openTabForConnection(String path, String name) {
    final tabBloc = BlocProvider.of<TabManagerBloc>(context, listen: false);
    tabBloc.add(AddTab(
      path: path,
      name: '$name (WebDAV)',
      switchToTab: true,
    ));
  }

  void _editConnection(NetworkCredentials credentials) {
    // Pre-fill the form with existing credentials
    _hostController.text = credentials.host;
    _usernameController.text = credentials.username;
    _passwordController.text = credentials.password;
    _portController.text = credentials.port?.toString() ?? '443';

    // Parse additional options for base path
    if (credentials.additionalOptions != null) {
      try {
        final options = jsonDecode(credentials.additionalOptions!);
        _basePathController.text = options['basePath'] ?? '/webdav';
      } catch (e) {
        _basePathController.text = '/webdav';
      }
    } else {
      _basePathController.text = '/webdav';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit WebDAV Connection'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'Host',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _basePathController,
                decoration: const InputDecoration(
                  labelText: 'Base Path',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateConnection(credentials);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _updateConnection(NetworkCredentials oldCredentials) {
    try {
      final additionalOptions = {
        'basePath': _basePathController.text.trim(),
        'useSSL': true, // Default for WebDAV
      };

      _credentialsService.saveCredentials(
        serviceType: 'WebDAV',
        host: _hostController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        port: int.tryParse(_portController.text),
        additionalOptions: additionalOptions,
      );

      _refreshData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update connection: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteConnection(NetworkCredentials credentials) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Connection'),
        content: Text(
            'Are you sure you want to delete the connection to "${credentials.host}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              try {
                _credentialsService.deleteCredentials(credentials.id);
                _refreshData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Connection deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete connection: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _addSampleConnection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Sample WebDAV Connection'),
        content: const Text(
          'This will add a sample connection to the DLP Test Site WebDAV server:\n\n'
          'Host: www.dlp-test.com\n'
          'Username: www.dlp-test.com\\WebDAV\n'
          'Password: WebDAV\n'
          'Port: 443\n'
          'Base Path: /webdav\n\n'
          'Do you want to add this sample connection?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _addDLPTestConnection();
            },
            child: const Text('Add Sample'),
          ),
        ],
      ),
    );
  }

  void _addDLPTestConnection() {
    try {
      final additionalOptions = {
        'basePath': '/webdav',
        'useSSL': true,
      };

      _credentialsService.saveCredentials(
        serviceType: 'WebDAV',
        host: 'www.dlp-test.com',
        username: 'www.dlp-test.com\\WebDAV',
        password: 'WebDAV',
        port: 443,
        additionalOptions: additionalOptions,
      );

      _refreshData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sample connection added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add sample connection: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SystemScreen(
      title: 'WebDAV Connections',
      systemId: '#webdav',
      icon: remix.Remix.global_line,
      showAppBar: true,
      actions: [
        IconButton(
          icon: const Icon(remix.Remix.refresh_line),
          onPressed: _refreshData,
          tooltip: 'Làm mới',
        ),
        IconButton(
          icon: const Icon(remix.Remix.add_line),
          onPressed: _connectToWebDAVServer,
          tooltip: 'Add Connection',
        ),
      ],
      child: BlocBuilder<NetworkBrowsingBloc, NetworkBrowsingState>(
        bloc: _networkBloc,
        builder: (context, state) {
          final activeConnections = state.connections.entries
              .where((entry) => (entry.value).serviceName == 'WebDAV')
              .toList();

          if (activeConnections.isEmpty && _savedCredentials.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    remix.Remix.global_line,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Không có kết nối WebDAV nào.',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Thêm kết nối mới hoặc kết nối mẫu để bắt đầu.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _connectToWebDAVServer,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Connection'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _addSampleConnection,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Add Sample'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(8.0),
            children: [
              if (activeConnections.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 8.0),
                  child: Text('Kết nối đang hoạt động',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                ...activeConnections.map(_buildActiveConnectionItem),
                const Divider(),
              ],
              if (_savedCredentials.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 8.0),
                  child: Text('Kết nối đã lưu',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                ..._savedCredentials.map(_buildSavedConnectionItem),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildActiveConnectionItem(
      MapEntry<String, NetworkServiceBase> entry) {
    String host = 'Unknown';
    try {
      host = Uri.parse(entry.value.basePath).host;
    } catch (_) {}

    return ListTile(
      leading: const Icon(remix.Remix.global_line, color: Colors.green),
      title: Text(host),
      subtitle: const Text('Đang kết nối'),
      onTap: () => _openTabForConnection(entry.key, host),
    );
  }

  Widget _buildSavedConnectionItem(NetworkCredentials credentials) {
    final isConnecting = _connectingCredentialIds.contains(credentials.id);

    return ListTile(
      leading: const Icon(remix.Remix.global_line, color: Colors.blue),
      title: Text(credentials.host),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(credentials.username),
          if (credentials.port != null) Text('Port: ${credentials.port}'),
          Text('Last connected: ${_formatDate(credentials.lastConnected)}'),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isConnecting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.0),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.orange),
              onPressed: () => _editConnection(credentials),
              tooltip: 'Edit Connection',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteConnection(credentials),
              tooltip: 'Delete Connection',
            ),
            IconButton(
              icon: const Icon(remix.Remix.arrow_right_circle_line, color: Colors.green),
              onPressed: () => _connectWithSavedCredentials(credentials),
              tooltip: 'Kết nối',
            ),
          ],
        ],
      ),
      onTap:
          isConnecting ? null : () => _connectWithSavedCredentials(credentials),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}
