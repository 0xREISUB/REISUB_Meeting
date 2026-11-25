import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:v_meeting/app/theme.dart';

// The app's liquid glass: frosted surfaces the page shows through, blurred
// and a little more vivid, with light catching their top edge.

/// The faint white wash that makes a surface read as glass.
const glassFill = Color(0x14FFFFFF);

/// The thin rim of a glass surface where no light falls on it.
const glassStroke = Color(0x24FFFFFF);

/// The dark base under glass laid over busy content, such as video.
const glassShade = Color(0x8C16141C);

/// Light text on glass, a little softer than white.
const glassMuted = Color(0xB3FFFFFF);

/// The brand purple, lightened for text and icons on glass.
const glassAccent = Color(0xFFC4AFFF);

/// Blur, then lift the colours a little, as glass does.
ImageFilter glassFilter({double sigma = 24}) => ImageFilter.compose(
  outer: _saturate(1.6),
  inner: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
);

/// Raises colour saturation by [amount] (1 leaves it as it is).
ColorFilter _saturate(double amount) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  final s = amount;
  return ColorFilter.matrix([
    r * (1 - s) + s, g * (1 - s), b * (1 - s), 0, 0, //
    r * (1 - s), g * (1 - s) + s, b * (1 - s), 0, 0, //
    r * (1 - s), g * (1 - s), b * (1 - s) + s, 0, 0, //
    0, 0, 0, 1, 0,
  ]);
}

/// A pane of glass: a faint wash with light catching its top edge.
///
/// Only with [blur] does it frost what lies behind. That is costly: the
/// blur is worked out again on every frame that anything behind it moves.
/// Over the app's still background it looks the same without, so only
/// panes over moving content, such as video or a list scrolling under the
/// bottom bar, turn it on.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 20,
    this.blur = false,
    this.sigma = 24,
    this.tint,
    this.padding,
    this.shadow = true,
    this.shape = BoxShape.rectangle,
  });

  final Widget child;
  final double radius;
  final bool blur;
  final double sigma;

  /// Colours the glass, as a coloured pane would; null for clear glass.
  final Color? tint;
  final EdgeInsetsGeometry? padding;
  final bool shadow;
  final BoxShape shape;

  bool get _circle => shape == BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    final tint = this.tint;
    final colors = tint != null
        ? [tint.withValues(alpha: 0.55), tint.withValues(alpha: 0.30)]
        : [const Color(0x1FFFFFFF), const Color(0x0AFFFFFF)];
    Widget pane = CustomPaint(
      foregroundPainter: GlassEdgePainter(radius: radius, circle: _circle),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: shape,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
    if (blur) {
      pane = BackdropFilter(
        filter: glassFilter(sigma: sigma),
        child: pane,
      );
    }
    pane = _circle
        ? ClipOval(child: pane)
        : ClipRRect(borderRadius: BorderRadius.circular(radius), child: pane);
    if (!shadow) return pane;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: _circle ? null : BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            // Soft and close, as it shows a little through the glass.
            color: (tint ?? Colors.black).withValues(
              alpha: tint == null ? 0.18 : 0.30,
            ),
            blurRadius: 20,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: pane,
    );
  }
}

/// The rim of the glass: bright where light falls on the top edge, fading
/// out towards the bottom.
class GlassEdgePainter extends CustomPainter {
  const GlassEdgePainter({required this.radius, this.circle = false});

  final double radius;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x73FFFFFF), Color(0x14FFFFFF), Color(0x29FFFFFF)],
        stops: [0, 0.6, 1],
      ).createShader(rect);
    if (circle) {
      canvas.drawOval(rect, paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(GlassEdgePainter old) =>
      old.radius != radius || old.circle != circle;
}

/// Soft brand-coloured light behind a page, so the glass on it has
/// something to frost.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final glow = Theme.of(context).colorScheme.primary;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Its own layer: drawn once, not again whenever the page moves.
        RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: pageBackground),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-1.1, -1.2),
                    radius: 1.1,
                    colors: [glow.withValues(alpha: 0.18), Colors.transparent],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(1.2, 1.1),
                    radius: 1.1,
                    colors: [glow.withValues(alpha: 0.22), Colors.transparent],
                  ),
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

/// A round glass button, as in the meeting's controls. [tint] colours it,
/// say red for a muted microphone.
class GlassIconButton extends StatefulWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tint,
    this.size = 52,
    this.iconSize = 24,
    this.tooltip,
    this.blur = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? tint;
  final double size;
  final double iconSize;
  final String? tooltip;
  final bool blur;

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    Widget button = GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _down ? 0.92 : 1,
        child: SizedBox.square(
          dimension: widget.size,
          child: GlassSurface(
            shape: BoxShape.circle,
            blur: widget.blur,
            tint: widget.tint,
            shadow: widget.tint != null,
            child: Center(
              child: Icon(
                widget.icon,
                size: widget.iconSize,
                color: widget.onPressed == null ? Colors.white38 : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip, child: button);
    }
    return Semantics(button: true, child: button);
  }
}

/// Opens [builder] as a glass dialog: the page behind is dimmed and blurred.
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: builder(context),
    ),
  );
}

/// A titled group of rows on one pane of glass, as in the settings, with
/// a faint line between the rows.
class GlassSection extends StatelessWidget {
  const GlassSection({
    super.key,
    required this.title,
    required this.children,
    this.radius = 22,
  });

  final String title;
  final List<Widget> children;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: glassMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          GlassSurface(
            radius: radius,
            shadow: false,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0)
                      const Divider(
                        height: 1,
                        indent: 56,
                        color: Color(0x14FFFFFF),
                      ),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A wide glass button with an icon and a label. [tint] colours the glass,
/// for the main action; without it the glass is clear.
class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tint,
    this.height = 58,
    this.fontSize = 17,
    this.radius,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? tint;
  final double height;
  final double fontSize;

  /// The corners' radius; a pill when null.
  final double? radius;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _down = false;

  void _press(bool down) {
    if (widget.onPressed != null) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final color = enabled ? Colors.white : Colors.white38;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: _down ? 0.97 : 1,
          child: SizedBox(
            height: widget.height,
            child: GlassSurface(
              radius: widget.radius ?? widget.height / 2,
              tint: enabled ? widget.tint : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, color: color, size: 22),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small round drop of glass inside a larger pane, which already blurs:
/// clear, or coloured by [tint].
BoxDecoration glassDrop({Color? tint}) => BoxDecoration(
  shape: BoxShape.circle,
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: tint == null
        ? const [Color(0x29FFFFFF), Color(0x0FFFFFFF)]
        : [tint.withValues(alpha: 0.95), tint.withValues(alpha: 0.70)],
  ),
  border: Border.all(
    color: tint == null ? glassStroke : const Color(0x40FFFFFF),
  ),
);

/// The colour behind small badges sitting on a glass drop.
const glassBadgeRim = Color(0xFF2A2830);

/// Smoked glass, the tint for panes over video: light shows through it
/// but white icons on it stay clear over a bright picture.
const glassSmoke = Color(0xFF1C1A22);

/// A bottom sheet of smoked glass. Its route should have a transparent
/// background, so the meeting shows blurred through it.
class GlassSheet extends StatelessWidget {
  const GlassSheet({super.key, required this.child, this.height});

  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    const radius = 14.0;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(radius)),
      child: BackdropFilter(
        filter: glassFilter(sigma: 30),
        child: CustomPaint(
          foregroundPainter: const GlassEdgePainter(radius: radius),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  glassSmoke.withValues(alpha: 0.78),
                  glassSmoke.withValues(alpha: 0.88),
                ],
              ),
            ),
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      ),
    );
  }
}

/// The tinted drop of glass behind the chosen tab or segment.
class GlassBead extends StatelessWidget {
  const GlassBead({super.key, required this.accent, this.radius = 28});

  final Color accent;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: GlassEdgePainter(radius: radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
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

/// A row of choices on glass, with a tinted bead that flows to the chosen
/// one, as in the bottom bar.
class GlassSegmented extends StatelessWidget {
  const GlassSegmented({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.badges = const {},
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// A count to show beside a choice, by its index.
  final Map<int, int> badges;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: GlassSurface(
        radius: 14,
        shadow: false,
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slot = constraints.maxWidth / labels.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutBack,
                  left: slot * selectedIndex,
                  top: 0,
                  bottom: 0,
                  width: slot,
                  child: const GlassBead(accent: brandColor, radius: 10),
                ),
                Row(
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: i == selectedIndex,
                          child: InkWell(
                            key: ValueKey('segment-$i'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => onSelected(i),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: AnimatedDefaultTextStyle(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall!
                                          .copyWith(
                                            color: i == selectedIndex
                                                ? Colors.white
                                                : glassMuted,
                                            fontWeight: i == selectedIndex
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                      child: Text(
                                        labels[i],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  if ((badges[i] ?? 0) > 0) ...[
                                    const SizedBox(width: 6),
                                    GlassCountBadge(count: badges[i]!),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A small red count, for things waiting for an answer.
class GlassCountBadge extends StatelessWidget {
  const GlassCountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
