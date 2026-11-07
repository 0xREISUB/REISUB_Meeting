import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/auth/auth_api.dart';
import 'package:v_meeting/auth/login_screen.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/auth/server_config.dart';
import 'device_test_screen.dart';
import 'meeting_preferences.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _serverHostController = TextEditingController();
  final TextEditingController _serverPortController = TextEditingController(
    text: '${ServerConfig.defaultPort}',
  );

  bool _isSavingServerSettings = false;
  bool _isLoadingServerSettings = true;

  @override
  void initState() {
    super.initState();
    _loadServerSettings();
  }

  Future<void> _loadServerSettings() async {
    try {
      final savedUrl = await ServerConfig.readUrl();
      if (!mounted || savedUrl == null) return;
      final uri = ServerConfig.parseUrl(savedUrl);
      if (uri == null) return;
      _serverHostController.text = ServerConfig.editableHost(uri);
      _serverPortController.text = uri.port.toString();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.serverSettingsReadFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingServerSettings = false);
    }
  }

  @override
  void dispose() {
    _serverHostController.dispose();
    _serverPortController.dispose();
    super.dispose();
  }

  Future<void> _saveServerSettings() async {
    if (_isLoadingServerSettings || _isSavingServerSettings) {
      return;
    }

    final newUrl = ServerConfig.buildUrl(
      address: _serverHostController.text,
      port: _serverPortController.text,
    );
    if (newUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.invalidServerAddressPort),
        ),
      );
      return;
    }

    setState(() => _isSavingServerSettings = true);
    try {
      final currentUrl = await ServerConfig.readUrl();
      await ref.read(authApiProvider).checkServer(newUrl);

      await ServerConfig.saveUrl(newUrl);
      final serverChanged =
          currentUrl != null &&
          ServerConfig.parseUrl(currentUrl) != Uri.parse(newUrl);
      if (serverChanged) await ServerConfig.clearToken();
      if (!mounted) {
        return;
      }

      if (serverChanged) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.serverSettingsSaved(newUrl),
          ),
        ),
      );
    } on ServerCheckException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.connectionError),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.serverSettingsSaveFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingServerSettings = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final preferences =
        ref.watch(meetingPreferencesProvider).value ??
        const MeetingPreferences();
    final updatePreferences = ref
        .read(meetingPreferencesProvider.notifier)
        .change;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _sectionTitle(context, l10n.general),

          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: Text(l10n.darkTheme),
            subtitle: Text(l10n.comingSoon),
            value: false,
            onChanged: null,
          ),

          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: Text(l10n.notifications),
            subtitle: Text(l10n.comingSoon),
            value: false,
            onChanged: null,
          ),

          const Divider(height: 32),

          _sectionTitle(context, l10n.meeting),

          SwitchListTile(
            secondary: const Icon(Icons.mic),
            title: Text(l10n.startWithMic),
            value: preferences.startWithMicrophone,
            onChanged: (value) => updatePreferences(startWithMicrophone: value),
          ),

          SwitchListTile(
            secondary: const Icon(Icons.videocam),
            title: Text(l10n.startWithCamera),
            value: preferences.startWithCamera,
            onChanged: (value) => updatePreferences(startWithCamera: value),
          ),

          SwitchListTile(
            secondary: const Icon(Icons.flip_camera_android),
            title: Text(l10n.mirrorCamera),
            value: preferences.mirrorCamera,
            onChanged: (value) => updatePreferences(mirrorCamera: value),
          ),

          SwitchListTile(
            secondary: const Icon(Icons.noise_control_off),
            title: Text(l10n.noiseSuppression),
            subtitle: Text(l10n.comingSoon),
            value: false,
            onChanged: null,
          ),

          SwitchListTile(
            secondary: const Icon(Icons.high_quality),
            title: Text(l10n.highQualityVideo),
            subtitle: Text(l10n.comingSoon),
            value: false,
            onChanged: null,
          ),

          const Divider(height: 32),

          _sectionTitle(context, l10n.serverSettings),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Card(
              elevation: 0,
              color: colorScheme.surfaceContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      key: const Key('server-host'),
                      enabled:
                          !_isLoadingServerSettings && !_isSavingServerSettings,
                      controller: _serverHostController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: l10n.serverAddress,
                        hintText: '192.168.1.10',
                        prefixIcon: const Icon(Icons.dns_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('server-port'),
                      enabled:
                          !_isLoadingServerSettings && !_isSavingServerSettings,
                      controller: _serverPortController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.serverPort,
                        hintText: '${ServerConfig.defaultPort}',
                        prefixIcon: const Icon(Icons.numbers_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _isLoadingServerSettings || _isSavingServerSettings
                            ? null
                            : _saveServerSettings,
                        icon: _isSavingServerSettings
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(l10n.saveServerSettings),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.serverSettingsHint,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Divider(height: 32),

          _sectionTitle(context, l10n.deviceTest),

          ListTile(
            leading: const Icon(Icons.mic_external_on),
            title: Text(l10n.testMicrophone),
            subtitle: Text(
              AppLocalizations.of(context)!.microphoneSelectionHint,
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DeviceTestScreen(camera: false),
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.videocam),
            title: Text(l10n.testCamera),
            subtitle: Text(AppLocalizations.of(context)!.cameraSelectionHint),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DeviceTestScreen(camera: true),
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.volume_up),
            title: Text(l10n.testSpeaker),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),

          const Divider(height: 32),

          _sectionTitle(context, l10n.application),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.version),
            subtitle: const Text("1.0.0"),
          ),

          ListTile(
            leading: const Icon(Icons.system_update_alt),
            title: Text(l10n.checkForUpdates),
            subtitle: Text(l10n.comingSoon),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  static Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
