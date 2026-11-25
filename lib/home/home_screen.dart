import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/app/orientation.dart';
import 'package:v_meeting/home/glass_nav_bar.dart';
import 'package:v_meeting/home/home_tab.dart';
import 'package:v_meeting/social/notifications.dart';
import 'package:v_meeting/social/social_api.dart';
import 'package:v_meeting/social/social_tab.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/settings/settings_view.dart';
import 'package:v_meeting/widgets/glass.dart';

/// The app's main screen: Social, Home and Settings tabs, switched from a
/// bar at the bottom. A tab slides in from its side, and the tabs can also
/// be swiped. Home is in front when it opens.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  /// Index of each tab, left to right.
  static const socialTab = 0;
  static const homeTab = 1;
  static const settingsTab = 2;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = HomeScreen.homeTab;
  late final _pages = PageController(initialPage: _tab);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// The social overview refreshes often while its tab shows.
  bool _socialShown = false;

  void _shown(int tab) {
    setState(() => _tab = tab);
    final social = tab == HomeScreen.socialTab;
    if (social == _socialShown) return;
    _socialShown = social;
    ref.read(socialTabShownProvider.notifier).set(social);
    final overview = ref.read(socialOverviewProvider.notifier);
    social ? overview.show() : overview.hide();
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
    // Keeps the social overview refreshing in the background while the
    // app is open, so friends see the user online on any tab.
    ref.listen(socialOverviewProvider, (_, _) {});
    // A notification asked for a chat: to the social tab, which opens it.
    ref.listen(socialOpenRequestProvider, (_, target) {
      if (target != null) _select(HomeScreen.socialTab);
    });
    final waiting = ref.watch(socialOverviewProvider).value?.waiting ?? 0;
    return PortraitOnPhone(
      child: Scaffold(
        extendBody: true,
        body: GlassBackground(
          child: PageView(
            key: const ValueKey('home-tabs'),
            controller: _pages,
            // Builds the pages beside the one shown ahead of time; with Home
            // in the middle, all of them. Kept alive too, so sliding to a
            // tab never builds it in the middle of the slide.
            allowImplicitScrolling: true,
            onPageChanged: _shown,
            children: const [
              _KeptAlive(child: SocialTab()),
              _KeptAlive(child: HomeTab()),
              _KeptAlive(
                child: SafeArea(
                  bottom: false,
                  child: SettingsView(showTitle: true),
                ),
              ),
            ],
          ),
        ),
        // The pages run under the floating bar, so it blurs them, and
        // only beside it they show through. Their scrolling ends with room
        // for the bar, so nothing stays hidden under it.
        // Its own layer: its bead's slide repaints the bar alone.
        bottomNavigationBar: RepaintBoundary(
          child: GlassNavBar(
            key: const ValueKey('home-navigation'),
            selectedIndex: _tab,
            onSelected: _select,
            items: [
              GlassNavItem(
                icon: Icons.people_alt_outlined,
                selectedIcon: Icons.people_alt_rounded,
                label: l10n.social,
                badge: waiting,
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
      ),
    );
  }
}

/// Keeps a tab built while another shows.
class _KeptAlive extends StatefulWidget {
  const _KeptAlive({required this.child});

  final Widget child;

  @override
  State<_KeptAlive> createState() => _KeptAliveState();
}

class _KeptAliveState extends State<_KeptAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
