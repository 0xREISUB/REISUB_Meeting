import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:v_meeting/app/window_controls.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/widgets/glass.dart' show glassMuted;

/// The app's own title bar on a computer, in place of the system's. It stays
/// out of the way: it comes down as soon as the pointer reaches the top of
/// the window, and goes back up once the pointer leaves it.
class AutoHideTitleBar extends StatefulWidget {
  const AutoHideTitleBar({
    super.key,
    required this.child,
    required this.controls,
    this.title = 'REISUB Meeting',
  });

  final Widget child;
  final WindowControls controls;
  final String title;

  static const height = 40.0;

  /// A moment's grace after the pointer leaves the bar, so brushing past
  /// its edge does not snap it shut.
  static const hideDelay = Duration(milliseconds: 250);

  /// The strip at the top of the window that brings the bar down.
  static const triggerHeight = 16.0;

  @override
  State<AutoHideTitleBar> createState() => _AutoHideTitleBarState();
}

class _AutoHideTitleBarState extends State<AutoHideTitleBar>
    with SingleTickerProviderStateMixin {
  // Slides the bar rather than laying it out again each frame, so it moves
  // smoothly at any refresh rate.
  late final _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 150),
  );
  late final _offset = Tween(
    begin: const Offset(0, -1.05),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic));

  bool _overBar = false;
  bool _maximized = false;
  Timer? _hideTimer;

  bool get _shown =>
      _slide.status == AnimationStatus.forward ||
      _slide.status == AnimationStatus.completed;

  @override
  void dispose() {
    _hideTimer?.cancel();
    _slide.dispose();
    super.dispose();
  }

  Future<void> _show() async {
    _hideTimer?.cancel();
    if (_shown) return;
    _slide.forward();
    setState(() {});
    // Should the pointer never reach the bar, it goes again.
    _scheduleHide(const Duration(milliseconds: 1500));
    final maximized = await widget.controls.isMaximized();
    if (mounted && maximized != _maximized) {
      setState(() => _maximized = maximized);
    }
  }

  void _hide() {
    _hideTimer?.cancel();
    _slide.reverse();
    setState(() {});
  }

  void _scheduleHide([Duration delay = AutoHideTitleBar.hideDelay]) {
    _hideTimer?.cancel();
    _hideTimer = Timer(delay, () {
      if (mounted && !_overBar) _hide();
    });
  }

  void _enterBar() {
    _overBar = true;
    _hideTimer?.cancel();
  }

  void _leaveBar() {
    _overBar = false;
    _scheduleHide();
  }

  Future<void> _toggleMaximize() async {
    await widget.controls.toggleMaximize();
    final maximized = await widget.controls.isMaximized();
    if (mounted) setState(() => _maximized = maximized);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: AutoHideTitleBar.triggerHeight,
          child: MouseRegion(
            key: const ValueKey('title-bar-trigger'),
            opaque: false,
            onEnter: (_) => _show(),
            onHover: (_) {
              if (!_shown) _show();
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: AutoHideTitleBar.height,
          child: IgnorePointer(
            ignoring: !_shown,
            child: SlideTransition(
              position: _offset,
              child: RepaintBoundary(
                child: MouseRegion(
                  key: const ValueKey('title-bar'),
                  onEnter: (_) => _enterBar(),
                  onExit: (_) => _leaveBar(),
                  child: _TitleBar(
                    title: widget.title,
                    maximized: _maximized,
                    onDrag: widget.controls.startDragging,
                    onMinimize: () {
                      _hide();
                      widget.controls.minimize();
                    },
                    onToggleMaximize: _toggleMaximize,
                    onClose: widget.controls.close,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Nearly black, with a touch of the brand's purple.
const _barColor = Color(0xF20E0B16);

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.title,
    required this.maximized,
    required this.onDrag,
    required this.onMinimize,
    required this.onToggleMaximize,
    required this.onClose,
  });

  final String title;
  final bool maximized;
  final VoidCallback onDrag;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMaximize;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Material: the bar sits above the app's pages, so its text would
    // otherwise have no style and show the debug underline.
    return Material(
      type: MaterialType.transparency,
      // Solid rather than blurred glass: a blur behind a moving bar would be
      // worked out again for the whole window on every frame.
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _barColor,
          border: Border(bottom: BorderSide(color: Color(0x14FFFFFF))),
          boxShadow: [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              // Pressing anywhere but the buttons moves the window.
              child: GestureDetector(
                key: const ValueKey('title-bar-drag'),
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => onDrag(),
                onDoubleTap: onToggleMaximize,
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/branding/logo.png',
                        width: 18,
                        height: 18,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: glassMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _CaptionButton(
              key: const ValueKey('title-bar-minimize'),
              icon: Icons.remove_rounded,
              tooltip: l10n.windowMinimize,
              onPressed: onMinimize,
            ),
            _CaptionButton(
              key: const ValueKey('title-bar-maximize'),
              icon: maximized
                  ? Icons.filter_none_rounded
                  : Icons.crop_square_rounded,
              iconSize: maximized ? 15 : 18,
              tooltip: maximized ? l10n.windowRestore : l10n.windowMaximize,
              onPressed: onToggleMaximize,
            ),
            _CaptionButton(
              key: const ValueKey('title-bar-close'),
              icon: Icons.close_rounded,
              tooltip: l10n.close,
              hoverColor: Colors.red.shade600,
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.iconSize = 18,
    this.hoverColor = const Color(0x1FFFFFFF),
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double iconSize;
  final Color hoverColor;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 46,
          height: AutoHideTitleBar.height,
          color: _hovered ? widget.hoverColor : Colors.transparent,
          child: Icon(widget.icon, size: widget.iconSize, color: Colors.white),
        ),
      ),
    );
    // A label, not a tooltip: the bar sits above the app's overlay.
    return Semantics(button: true, label: widget.tooltip, child: button);
  }
}
