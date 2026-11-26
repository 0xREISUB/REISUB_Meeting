import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/auth/auth_api.dart';
import 'package:v_meeting/auth/account.dart';
import 'package:v_meeting/app/version.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/auth/server_config.dart';
import 'package:v_meeting/auth/server_policy.dart';
import 'package:v_meeting/app/invite.dart';
import 'package:v_meeting/auth/login_screen.dart';
import 'package:v_meeting/desktop/desktop_background.dart';
import 'package:v_meeting/settings/about_screen.dart';
import 'package:v_meeting/settings/language_screen.dart';
import 'package:v_meeting/settings/server_terms_screen.dart';
import 'device_test_screen.dart';
import 'meeting_preferences.dart';
import 'package:v_meeting/widgets/glass.dart';

/// The settings list, shown in the settings tab and in [SettingsScreen]:
/// general and meeting choices, the server, device tests, the account and
/// the app.
class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key, this.showTitle = false});

  /// A large title above the list, for the tab, which has no title bar.
  final bool showTitle;

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
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
      if (serverChanged) {
        // Sessions belong to the previous server.
        await ServerConfig.clearSessions();
        ref.read(signedInProvider.notifier).refresh();
      }
      ref.invalidate(serverPolicyProvider);
      if (!mounted) {
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
    final desktop = desktopBackgroundSupported
        ? ref.watch(desktopSettingsProvider).value
        : null;
    final preferences =
        ref.watch(meetingPreferencesProvider).value ??
        const MeetingPreferences();
    final updatePreferences = ref
        .read(meetingPreferencesProvider.notifier)
        .change;

    final signedIn = ref.watch(signedInProvider).value ?? false;
    return ListView(
      // Room at the end for the bottom bar, in the tab, or the system's.
      padding: EdgeInsets.only(
        top: 12,
        bottom: 12 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (widget.showTitle)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Text(
              l10n.settings,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        GlassSection(
          title: l10n.general,
          children: [
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
          ],
        ),

        GlassSection(
          title: l10n.meeting,
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.mic),
              title: Text(l10n.startWithMic),
              value: preferences.startWithMicrophone,
              onChanged: (value) =>
                  updatePreferences(startWithMicrophone: value),
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
          ],
        ),

        GlassSection(
          title: l10n.serverSettings,
          children: [
            // The web app always uses the server it was loaded from; another
            // address would only fail on the browser's cross-origin rules.
            if (kIsWeb)
              ListTile(
                key: const Key('web-server-info'),
                leading: const Icon(Icons.dns_outlined),
                title: Text(_serverHostController.text),
                subtitle: Text(l10n.webServerFixed),
              )
            else
              Padding(
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
          ],
        ),

        GlassSection(
          title: l10n.deviceTest,
          children: [
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
          ],
        ),

        GlassSection(
          title: l10n.account,
          children: [
            if (signedIn)
              ListTile(
                key: const ValueKey('settings-logout'),
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text(
                  l10n.logout,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: _logOut,
              )
            else
              ListTile(
                key: const ValueKey('settings-login'),
                leading: const Icon(Icons.login),
                title: Text(l10n.login),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _open(const LoginScreen()),
              ),
          ],
        ),

        GlassSection(
          title: l10n.application,
          children: [
            ListTile(
              key: const ValueKey('settings-language'),
              leading: const Icon(Icons.language_outlined),
              title: Text(l10n.language),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _open(const LanguageScreen()),
            ),

            // On a computer: whether closing the window keeps the app
            // running, for notifications, and whether it starts at login.
            if (desktopBackgroundSupported) ...[
              SwitchListTile(
                key: const ValueKey('settings-run-in-background'),
                secondary: const Icon(Icons.notifications_active_outlined),
                title: Text(l10n.runInBackground),
                subtitle: Text(l10n.runInBackgroundHint),
                value: desktop?.runInBackground ?? true,
                onChanged: desktop == null
                    ? null
                    : (on) => ref
                          .read(desktopSettingsProvider.notifier)
                          .setRunInBackground(on),
              ),
              SwitchListTile(
                key: const ValueKey('settings-start-at-login'),
                secondary: const Icon(Icons.login_rounded),
                title: Text(l10n.startAtLogin),
                subtitle: Text(l10n.startAtLoginHint),
                value: desktop?.startAtLogin ?? false,
                onChanged: desktop == null
                    ? null
                    : (on) => ref
                          .read(desktopSettingsProvider.notifier)
                          .setStartAtLogin(on),
              ),
            ],

            ListTile(
              key: const ValueKey('settings-server-terms'),
              leading: const Icon(Icons.gavel_rounded),
              title: Text(l10n.serverTerms),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _open(const ServerTermsScreen()),
            ),

            ListTile(
              key: const ValueKey('settings-about'),
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.about),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _open(const AboutScreen()),
            ),

            ListTile(
              leading: const Icon(Icons.tag_rounded),
              title: Text(l10n.version),
              subtitle: const Text(appVersion),
            ),

            ListTile(
              leading: const Icon(Icons.system_update_alt),
              title: Text(l10n.checkForUpdates),
              subtitle: Text(l10n.comingSoon),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {},
            ),
          ],
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  /// Back to a guest, unless the server takes none: then the start screen
  /// asks to log in again.
  Future<void> _logOut() async {
    await ref.read(signedInProvider.notifier).signOut();
    ref.invalidate(serverPolicyProvider);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const StartGate()),
      (_) => false,
    );
  }
}
