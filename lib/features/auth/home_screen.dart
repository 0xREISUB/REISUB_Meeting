import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'join_screen.dart'; // Katılma ekranına gitmek için
import 'create_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // PROFİL RESMİ VE AÇILIR MENÜ
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: PopupMenuButton<int>(
              tooltip: 'Profile Menu',
              // Menünün tam yuvarlağın altında açılması için aşağı itiyoruz
              offset: const Offset(0, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              // Profil resmi için yuvarlak avatar
              icon: const CircleAvatar(
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
                child: Icon(Icons.person),
              ),
              // 7 Adet Placeholder Sekmesi
              itemBuilder: (context) {
                return List.generate(7, (index) {
                  return PopupMenuItem<int>(
                    value: index,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.space_dashboard_outlined,
                          size: 20,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Text('Placeholder ${index + 1}'),
                      ],
                    ),
                  );
                });
              },
              onSelected: (value) {
                print('Seçilen sekme: Placeholder ${value + 1}');
              },
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LOGO
                const Icon(
                  Icons.video_chat_rounded,
                  size: 100,
                  color: Colors.deepPurpleAccent,
                ),
                const SizedBox(height: 24),
                const Text(
                  'REISUB Meeting',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                // AÇIK KAYNAK ALT BAŞLIĞI
                Text(
                  l10n.appSubtitle,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),

                // ODA KUR BUTONU
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_box, size: 24),
                  label: Text(
                    l10n.createRoom,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // ODAYA KATIL BUTONU
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    foregroundColor: Colors.deepPurpleAccent,
                    side: const BorderSide(
                      color: Colors.deepPurpleAccent,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.login, size: 24),
                  label: Text(
                    l10n.joinMeeting,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const JoinScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
