import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _serverHostController =
      TextEditingController(text: '192.168.1.10');
  final TextEditingController _serverPortController =
      TextEditingController(text: '3000');

  bool startWithMic = true;
  bool startWithCamera = true;
  bool mirrorCamera = false;

  @override
  void dispose() {
    _serverHostController.dispose();
    _serverPortController.dispose();
    super.dispose();
  }

  void _saveServerSettings() {
    final host = _serverHostController.text.trim();
    final port = int.tryParse(_serverPortController.text.trim());

    if (host.isEmpty || port == null || port <= 0 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen geçerli bir sunucu IP/host ve port girin.'),
        ),
      );
      return;
    }

    // Şimdilik placeholder.
    // Burada ileride shared_preferences ile kaydedebilir,
    // API client için baseUrl oluşturabilirsin.
    // Örnek: http://$host:$port

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sunucu ayarları kaydedildi: $host:$port'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        centerTitle: true,
      ),
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
            value: startWithMic,
            onChanged: (value) {
              setState(() => startWithMic = value);
            },
          ),

          SwitchListTile(
            secondary: const Icon(Icons.videocam),
            title: Text(l10n.startWithCamera),
            value: startWithCamera,
            onChanged: (value) {
              setState(() => startWithCamera = value);
            },
          ),

          SwitchListTile(
            secondary: const Icon(Icons.flip_camera_android),
            title: Text(l10n.mirrorCamera),
            value: mirrorCamera,
            onChanged: (value) {
              setState(() => mirrorCamera = value);
            },
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
                      controller: _serverPortController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.serverPort,
                        hintText: '3000',
                        prefixIcon: const Icon(Icons.numbers_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveServerSettings,
                        icon: const Icon(Icons.save),
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
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),

          ListTile(
            leading: const Icon(Icons.videocam),
            title: Text(l10n.testCamera),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
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
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}