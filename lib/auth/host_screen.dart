import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:v_meeting/auth/login_screen.dart';
import 'package:v_meeting/auth/server_config.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

class HostScreen extends StatefulWidget {
  const HostScreen({super.key, this.dio});
  final Dio? dio;

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(
    text: '${ServerConfig.defaultPort}',
  );
  bool _isLoading = true;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _loadSavedHost();
  }

  Future<void> _loadSavedHost() async {
    try {
      final savedHost = await ServerConfig.readUrl();
      if (!mounted || savedHost == null) return;
      final uri = ServerConfig.parseUrl(savedHost);
      if (uri != null) {
        _hostController.text = ServerConfig.editableHost(uri);
        _portController.text = uri.port.toString();
      }
    } catch (_) {
      if (mounted) _showError('Kayıtlı sunucu ayarları okunamadı.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _connect() async {
    if (_isLoading || _isConnecting) return;
    final l10n = AppLocalizations.of(context)!;
    final host = ServerConfig.buildUrl(
      address: _hostController.text,
      port: _portController.text,
    );

    if (host == null) {
      _showError(l10n.connectionError);
      return;
    }

    setState(() => _isConnecting = true);
    try {
      final dio =
          widget.dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );
      final response = await dio.get<Map<String, dynamic>>('$host/ping');
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
    } catch (_) {
      if (mounted) _showError('Sunucu ayarları kaydedilemedi. Tekrar deneyin.');
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
                  key: const Key('server-host'),
                  enabled: !_isLoading && !_isConnecting,
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
                  key: const Key('server-port'),
                  enabled: !_isLoading && !_isConnecting,
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
                  onPressed: _isLoading || _isConnecting ? null : _connect,
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
