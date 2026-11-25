import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/create_screen.dart';
import 'package:v_meeting/meeting/join_screen.dart';
import 'package:v_meeting/widgets/app_logo.dart';
import 'package:v_meeting/widgets/glass.dart';
import 'package:v_meeting/app/theme.dart';

/// The home tab: the app's name and the buttons to create or join a
/// meeting.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Not the bottom: the bar floats there, beside it the page goes on.
    final barRoom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact =
              constraints.maxWidth < 400 || constraints.maxHeight < 620;
          final verticalPadding = isCompact ? 20.0 : 32.0;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              verticalPadding,
              24,
              verticalPadding + barRoom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    (constraints.maxHeight - verticalPadding * 2 - barRoom)
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
                          color: glassMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isCompact ? 32 : 60),

                      GlassButton(
                        tint: brandColor,
                        height: isCompact ? 56 : 62,
                        fontSize: isCompact ? 16 : 18,
                        icon: Icons.add_box_rounded,
                        label: l10n.createRoom,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreateScreen(),
                          ),
                        ),
                      ),
                      SizedBox(height: isCompact ? 12 : 16),
                      GlassButton(
                        height: isCompact ? 56 : 62,
                        fontSize: isCompact ? 16 : 18,
                        icon: Icons.login_rounded,
                        label: l10n.joinMeeting,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const JoinScreen(),
                          ),
                        ),
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
