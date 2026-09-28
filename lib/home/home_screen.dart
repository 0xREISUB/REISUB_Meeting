import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/auth/login_screen.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/create_screen.dart';
import 'package:v_meeting/meeting/join_screen.dart';
import 'package:v_meeting/settings/about_screen.dart';
import 'package:v_meeting/settings/language_screen.dart';
import 'package:v_meeting/settings/settings_screen.dart';
import 'package:v_meeting/auth/server_config.dart';

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
              offset: const Offset(0, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              icon: const CircleAvatar(
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
                child: Icon(Icons.person),
              ),
              itemBuilder: (context) {
                return [
                  PopupMenuItem<int>(
                    value: 0,
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 20),
                        SizedBox(width: 12),
                        Text(l10n.profile),
                      ],
                    ),
                  ),
                  PopupMenuItem<int>(
                    value: 1,
                    child: Row(
                      children: [
                        Icon(Icons.settings_outlined, size: 20),
                        SizedBox(width: 12),
                        Text(l10n.settings),
                      ],
                    ),
                  ),
                  PopupMenuItem<int>(
                    value: 2,
                    child: Row(
                      children: [
                        Icon(Icons.language_outlined, size: 20),
                        SizedBox(width: 12),
                        Text(l10n.language),
                      ],
                    ),
                  ),
                  PopupMenuItem<int>(
                    value: 3,
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 20),
                        SizedBox(width: 12),
                        Text(l10n.about),
                      ],
                    ),
                  ),
                  PopupMenuItem<int>(
                    value: 4,
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text(
                          l10n.logout,
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ];
              },
              onSelected: (value) async {
                switch (value) {
                  case 0:
                    print('Profil');
                    break;
                  case 1:
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                    break;
                  case 2:
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LanguageScreen()),
                    );
                    break;
                  case 3:
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AboutScreen(),
                      ),
                    );
                    break;
                  case 4:
                    await ServerConfig.clearToken();
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) =>
                          false, // Tüm geçmişi siler ki geri tuşuyla anasayfaya dönülmesin
                    );
                    break;
                }
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact =
                constraints.maxWidth < 400 || constraints.maxHeight < 620;
            final verticalPadding = isCompact ? 20.0 : 32.0;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: verticalPadding,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - verticalPadding * 2)
                      .clamp(0, double.infinity),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // LOGO
                        Icon(
                          Icons.video_chat_rounded,
                          size: isCompact ? 72 : 100,
                          color: Colors.deepPurpleAccent,
                        ),
                        SizedBox(height: isCompact ? 16 : 24),
                        Text(
                          'REISUB Meeting',
                          style: TextStyle(
                            fontSize: isCompact ? 30 : 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        // AÇIK KAYNAK ALT BAŞLIĞI
                        Text(
                          l10n.appSubtitle,
                          style: TextStyle(
                            fontSize: isCompact ? 14 : 16,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isCompact ? 32 : 60),

                        // ODA KUR BUTONU
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: isCompact ? 16 : 20,
                            ),
                            backgroundColor: Colors.deepPurpleAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add_box, size: 24),
                          label: Text(
                            l10n.createRoom,
                            style: TextStyle(
                              fontSize: isCompact ? 16 : 18,
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
                        SizedBox(height: isCompact ? 12 : 20),

                        // ODAYA KATIL BUTONU
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: isCompact ? 16 : 20,
                            ),
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
                            style: TextStyle(
                              fontSize: isCompact ? 16 : 18,
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
          },
        ),
      ),
    );
  }
}
