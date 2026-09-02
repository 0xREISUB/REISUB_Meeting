import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.about),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            /// Logo
            CircleAvatar(
              radius: 50,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.video_chat_rounded,
                size: 50,
                color: colorScheme.primary,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "REISUB Meeting",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              "v1.0.0",
              style: TextStyle(
                color: Colors.grey.shade400,
              ),
            ),

            const SizedBox(height: 30),

            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.about),
                subtitle: Text(l10n.appSubtitle),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(l10n.developer),
                subtitle: const Text("Yusuf Enes Metin (0xREISUB)"),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: ListTile(
                leading: const Icon(Icons.code),
                title: Text(l10n.technologies),
                subtitle: const Text(
                  "Flutter\n"
                  "Dart\n"
                  "Riverpod\n"
                  "Material 3",
                ),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(l10n.licenses),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: "REISUB Meeting",
                    applicationVersion: "1.0.0",
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: ListTile(
                leading: const Icon(Icons.email_outlined),
                title: Text(l10n.contact),
                subtitle: const Text("yusufenes4124@gmail.com"),
              ),
            ),

            const SizedBox(height: 40),

            Text(
              l10n.madeWithFlutter,
              style: TextStyle(
                color: Colors.grey.shade500,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "© 2026 Yusuf Enes Metin",
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}