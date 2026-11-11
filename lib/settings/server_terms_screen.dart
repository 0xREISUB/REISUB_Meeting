import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/auth/server_config.dart';
import 'package:v_meeting/auth/server_policy.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

/// The rules the saved server sets, read again each time this opens.
class ServerTermsScreen extends ConsumerStatefulWidget {
  const ServerTermsScreen({super.key});

  @override
  ConsumerState<ServerTermsScreen> createState() => _ServerTermsScreenState();
}

class _ServerTermsScreenState extends ConsumerState<ServerTermsScreen> {
  late final Future<String?> _serverUrl = ServerConfig.readUrl();

  @override
  void initState() {
    super.initState();
    // The server may have changed its rules since the app started.
    ref.invalidate(serverPolicyProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final policy = ref.watch(serverPolicyProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.serverTerms)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l10n.serverTermsIntro,
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 8),
          FutureBuilder<String?>(
            future: _serverUrl,
            builder: (context, snapshot) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.dns_rounded),
              title: Text(l10n.serverAddress),
              subtitle: Text(snapshot.data ?? '—'),
            ),
          ),
          const Divider(),
          if (policy.isLoading && !policy.hasValue)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (policy.value case final terms?)
            ..._terms(l10n, terms)
          else
            Column(
              children: [
                ListTile(
                  key: const ValueKey('server-terms-unavailable'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.cloud_off_rounded,
                    color: Colors.redAccent,
                  ),
                  title: Text(l10n.serverTermsUnavailable),
                ),
                TextButton.icon(
                  onPressed: () => ref.invalidate(serverPolicyProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.retry),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _terms(AppLocalizations l10n, ServerPolicy terms) => [
    if (!terms.reported)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(l10n.serverTermsUnreported),
      ),
    ListTile(
      key: const ValueKey('server-term-guests'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        terms.guestsAllowed
            ? Icons.no_accounts_rounded
            : Icons.lock_person_rounded,
        color: terms.guestsAllowed ? Colors.greenAccent : Colors.amber,
      ),
      title: Text(l10n.guestAccess),
      subtitle: Text(
        terms.guestsAllowed ? l10n.guestsAllowedValue : l10n.guestsRefusedValue,
      ),
    ),
  ];
}
