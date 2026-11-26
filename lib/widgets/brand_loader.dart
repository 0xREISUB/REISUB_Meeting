import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:v_meeting/app/theme.dart';
import 'package:v_meeting/widgets/app_logo.dart';

/// The app's own loading sign: its logo, breathing in a soft purple glow,
/// with a ring of light running around it.
class BrandLoader extends StatefulWidget {
  const BrandLoader({super.key, this.size = 96, this.showName = true});

  /// The logo's side; the ring runs just outside it.
  final double size;

  /// Shows the app's name under the logo.
  final bool showName;

  @override
  State<BrandLoader> createState() => _BrandLoaderState();
}

class _BrandLoaderState extends State<BrandLoader>
    with TickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();
  late final _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _spin.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = widget.size * 1.42;
    final breath = CurvedAnimation(parent: _breath, curve: Curves.easeInOut);
    return Semantics(
      label: 'REISUB Meeting',
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: ring,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The glow, swelling and settling slowly.
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: breath,
                    builder: (context, _) => Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: brandColor.withValues(
                              alpha: 0.35 + 0.25 * breath.value,
                            ),
                            blurRadius:
                                widget.size * (0.6 + 0.3 * breath.value),
                            spreadRadius: widget.size * 0.06,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // The ring, on its own layer: only it repaints as it turns.
                RepaintBoundary(
                  child: RotationTransition(
                    turns: _spin,
                    child: CustomPaint(
                      size: Size.square(ring),
                      painter: const _RingPainter(),
                    ),
                  ),
                ),
                ScaleTransition(
                  scale: Tween(begin: 0.97, end: 1.03).animate(breath),
                  child: AppLogo(size: widget.size),
                ),
              ],
            ),
          ),
          if (widget.showName) ...[
            SizedBox(height: widget.size * 0.28),
            Text(
              'REISUB Meeting',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A thin circle of light, bright at its head and fading behind it, over
/// a faint track.
class _RingPainter extends CustomPainter {
  const _RingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.03;
    final rect = (Offset.zero & size).deflate(stroke);
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.06),
    );
    const sweep = math.pi * 1.35;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: -math.pi / 2 + sweep,
          colors: [
            brandColor.withValues(alpha: 0),
            brandColor,
            Color.lerp(brandColor, Colors.white, 0.6)!,
          ],
          stops: const [0, 0.75, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => false;
}
