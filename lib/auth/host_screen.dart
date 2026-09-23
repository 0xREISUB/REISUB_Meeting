import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:v_meeting/auth/login_screen.dart';
import 'package:v_meeting/auth/server_config.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

class HostScreen extends StatefulWidget {
  const HostScreen({super.key});

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '8080');
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _loadSavedHost();
  }

  Future<void> _loadSavedHost() async {
    final savedHost = await ServerConfig.readUrl();
    if (mounted && savedHost != null) {
      final uri = Uri.tryParse(savedHost);
      if (uri != null && uri.host.isNotEmpty) {
        _hostController.text = uri.host;
        _portController.text = (uri.hasPort ? uri.port : 8080).toString();
      } else {
        _hostController.text = savedHost;
      }
    }
  }

  String _buildServerUrl() {
    final address = _hostController.text.trim().replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    final port = int.tryParse(_portController.text.trim());
    if (address.isEmpty || port == null || port < 1 || port > 65535) {
      return '';
    }

    final hasProtocol =
        address.startsWith('http://') || address.startsWith('https://');
    final protocol = hasProtocol ? Uri.tryParse(address)?.scheme : 'http';
    final host = hasProtocol ? Uri.tryParse(address)?.host : address;
    if (protocol == null || host == null || host.isEmpty) {
      return '';
    }
    return '$protocol://$host:$port';
  }

  Future<void> _connect() async {
    final l10n = AppLocalizations.of(context)!;
    final host = _buildServerUrl();

    if (host.isEmpty) {
      _showError(l10n.connectionError);
      return;
    }

    setState(() => _isConnecting = true);
    try {
      final response = await Dio().get<Map<String, dynamic>>('$host/ping');
      final pingResponse = response.data;

      if (response.statusCode != 200 ||
          pingResponse?['message'] != 'pong' ||
          pingResponse?['status'] != 'active') {
        throw const FormatException('Invalid server response');
      }

      await ServerConfig.saveUrl(host);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } on DioException catch (_) {
      if (mounted) {
        _showError(l10n.connectionError);
      }
    } on FormatException catch (_) {
      if (mounted) {
        _showError(l10n.connectionError);
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.dns_rounded,
                  size: 100,
                  color: Colors.deepPurpleAccent,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.serverSettings,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _hostController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.serverAddress,
                    hintText: l10n.serverSettingsHint,
                    prefixIcon: const Icon(Icons.link),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.serverPort,
                    prefixIcon: const Icon(Icons.numbers),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) => _isConnecting ? null : _connect(),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isConnecting ? null : _connect,
                  icon: _isConnecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(
                    l10n.saveServerSettings,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
