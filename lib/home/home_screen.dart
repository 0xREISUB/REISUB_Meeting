import 'package:flutter/material.dart';
import 'package:v_meeting/app/orientation.dart';
import 'package:v_meeting/home/glass_nav_bar.dart';
import 'package:v_meeting/home/home_tab.dart';
import 'package:v_meeting/social/social_tab.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/settings/settings_view.dart';
import 'package:v_meeting/widgets/glass.dart';

/// The app's main screen: Social, Home and Settings tabs, switched from a
/// bar at the bottom. A tab slides in from its side, and the tabs can also
/// be swiped. Home is in front when it opens.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Index of each tab, left to right.
  static const socialTab = 0;
  static const homeTab = 1;
  static const settingsTab = 2;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = HomeScreen.homeTab;
  late final _pages = PageController(initialPage: _tab);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _select(int tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    _pages.animateToPage(
      tab,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PortraitOnPhone(
      child: Scaffold(
        extendBody: true,
        body: GlassBackground(
          child: PageView(
            key: const ValueKey('home-tabs'),
            controller: _pages,
            onPageChanged: (tab) => setState(() => _tab = tab),
            children: const [
              SocialTab(),
              HomeTab(),
              SafeArea(bottom: false, child: SettingsView(showTitle: true)),
            ],
          ),
        ),
        // The pages run under the floating bar, so it blurs them, and
        // only beside it they show through. Their scrolling ends with room
        // for the bar, so nothing stays hidden under it.
        bottomNavigationBar: GlassNavBar(
          key: const ValueKey('home-navigation'),
          selectedIndex: _tab,
          onSelected: _select,
          items: [
            GlassNavItem(
              icon: Icons.people_alt_outlined,
              selectedIcon: Icons.people_alt_rounded,
              label: l10n.social,
            ),
            GlassNavItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: l10n.homeTab,
            ),
            GlassNavItem(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings_rounded,
              label: l10n.settings,
            ),
          ],
        ),
      ),
    );
  }
}
