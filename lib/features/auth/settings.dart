import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

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
            value: true,
            onChanged: (value) {},
          ),

          SwitchListTile(
            secondary: const Icon(Icons.videocam),
            title: Text(l10n.startWithCamera),
            value: true,
            onChanged: (value) {},
          ),

          SwitchListTile(
            secondary: const Icon(Icons.flip_camera_android),
            title: Text(l10n.mirrorCamera),
            value: false,
            onChanged: (value) {},
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