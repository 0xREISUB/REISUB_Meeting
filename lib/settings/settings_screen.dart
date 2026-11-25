import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/settings/settings_view.dart';
import 'package:v_meeting/widgets/glass.dart';

/// The settings as a screen of their own, with a title bar. The home
/// screen's settings tab shows the same [SettingsView].
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: AppBar(
      title: Text(AppLocalizations.of(context)!.settings),
      centerTitle: true,
    ),
    body: GlassBackground(
      child: SafeArea(bottom: false, child: SettingsView()),
    ),
  );
}
