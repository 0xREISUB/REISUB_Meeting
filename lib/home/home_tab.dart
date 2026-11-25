import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/create_screen.dart';
import 'package:v_meeting/meeting/join_screen.dart';
import 'package:v_meeting/widgets/app_logo.dart';

/// The home tab: the app's name and the buttons to create or join a
/// meeting.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
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
                minHeight: (constraints.maxHeight - verticalPadding * 2).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // LOGO
                      AppLogo(size: isCompact ? 112 : 144),
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
    );
  }
}
