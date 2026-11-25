import 'package:flutter/material.dart';
import 'package:v_meeting/app/theme.dart';
import 'package:v_meeting/widgets/glass.dart';

/// One tab in a [GlassNavBar].
class GlassNavItem {
  const GlassNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// A floating tab bar of frosted glass: the page shows blurred and a little
/// more vivid through it, light catches its top edge, and a tinted bead of
/// glass flows to the chosen tab.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<GlassNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const height = 68.0;
  static const _radius = 34.0;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    // The app's own purple, as on its buttons.
    const accent = brandColor;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottom + 14),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: GlassSurface(
            radius: _radius,
            sigma: 28,
            child: Container(
              height: height,
              padding: const EdgeInsets.all(6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final slot = constraints.maxWidth / items.length;
                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutBack,
                        left: slot * selectedIndex,
                        top: 0,
                        bottom: 0,
                        width: slot,
                        child: _GlassBead(accent: accent),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < items.length; i++)
                            Expanded(
                              child: _GlassTab(
                                item: items[i],
                                selected: i == selectedIndex,
                                accent: accent,
                                onTap: () => onSelected(i),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tinted drop of glass behind the chosen tab.
class _GlassBead extends StatelessWidget {
  const _GlassBead({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: const GlassEdgePainter(radius: 28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.42),
              accent.withValues(alpha: 0.16),
            ],
          ),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 18),
          ],
        ),
      ),
    );
  }
}

class _GlassTab extends StatelessWidget {
  const _GlassTab({
    required this.item,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Color.lerp(accent, Colors.white, 0.65)!
        : Colors.white.withValues(alpha: 0.72);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        splashColor: Colors.white.withValues(alpha: 0.06),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              scale: selected ? 1.1 : 1,
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              // On the theme's label style, which carries the font.
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                color: color,
                fontSize: 11.5,
                letterSpacing: 0.2,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
