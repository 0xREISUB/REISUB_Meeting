import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/app/theme.dart';
import 'package:v_meeting/auth/auth_api.dart';
import 'package:v_meeting/app/invite.dart';
import 'package:v_meeting/auth/server_config.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/widgets/app_logo.dart';
import 'package:v_meeting/widgets/language_menu_button.dart';

class HostScreen extends ConsumerStatefulWidget {
  const HostScreen({super.key});

  @override
  ConsumerState<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends ConsumerState<HostScreen> {
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
      if (mounted) {
        _showError(AppLocalizations.of(context)!.serverSettingsReadFailed);
      }
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
      await ref.read(authApiProvider).checkServer(host);
      await ServerConfig.saveUrl(host);
      if (mounted) {
        final next = startHome(ref);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => next),
        );
      }
    } on ServerCheckException {
      if (mounted) _showError(l10n.connectionError);
    } catch (_) {
      if (mounted) _showError(l10n.serverSettingsSaveFailed);
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  void _showError(String message) => showErrorSnackBar(context, message);

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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [LanguageMenuButton(), SizedBox(width: 8)],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppLogo(),
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
                  ),
                  onSubmitted: (_) => _isConnecting ? null : _connect(),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
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
