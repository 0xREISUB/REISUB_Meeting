import 'package:v_meeting/l10n/app_localizations.dart';

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:v_meeting/meeting/meeting_member.dart';
import 'package:v_meeting/meeting/widgets/participant_tile.dart';
import 'package:v_meeting/meeting/widgets/meeting_tap_listener.dart';
import 'package:v_meeting/meeting/widgets/members_panel.dart';
import 'package:v_meeting/widgets/glass.dart';

/// The participants panel floating over the main video on wide screens. It
/// starts in the bottom-right corner, can be dragged to any corner, and
/// shows up to five people or, collapsed, only one.
class FloatingMembers extends StatefulWidget {
  const FloatingMembers({
    super.key,
    required this.members,
    required this.mainMember,
    required this.corner,
    required this.collapsed,
    required this.solo,
    required this.tileWidth,
    required this.onTileWidthChanged,
    required this.onCornerChanged,
    required this.onCollapsedChanged,
    required this.onShowAll,
    this.compact = false,
    this.onDismiss,
  });

  final List<MemberEntry> members;
  final MemberEntry mainMember;
  final Alignment corner;
  final bool collapsed;

  /// The person a single tile shows; see [soloMember].
  final MemberEntry? solo;

  /// The phone's form: one tile without a title, over the whole page, that
  /// can be dragged to the top centre and let go to put it away.
  final bool compact;
  final VoidCallback? onDismiss;

  /// Preview width chosen by resizing; null for the default.
  final double? tileWidth;
  final ValueChanged<double> onTileWidthChanged;
  final ValueChanged<Alignment> onCornerChanged;
  final ValueChanged<bool> onCollapsedChanged;
  final VoidCallback onShowAll;

  @override
  State<FloatingMembers> createState() => _FloatingMembersState();
}

class _FloatingMembersState extends State<FloatingMembers> {
  /// Room around the panel; on wide screens the top leaves space for the
  /// frame's buttons.
  EdgeInsets get _margin => widget.compact
      ? const EdgeInsets.all(12)
      : const EdgeInsets.fromLTRB(16, 64, 16, 16);
  double get _minTileWidth => widget.compact ? 96 : 120;

  /// Whether the panel, while dragged, is over the drop zone that puts it
  /// away (phones).
  bool _inDismissZone = false;

  final _panelKey = GlobalKey();

  /// Where the panel is while it is being dragged.
  Alignment? _dragAlignment;

  /// The preview width when a resize began, and how far the grip has moved
  /// since. Several moves can arrive before the next frame, so each one is
  /// applied to the start width rather than to the last built one.
  double _resizeStartWidth = 0;
  Offset _resizeDistance = Offset.zero;

  void _onDragUpdate(DragUpdateDetails details, Size area) {
    final panel = _panelKey.currentContext?.size;
    if (panel == null) return;
    final freeWidth = area.width - panel.width - _margin.horizontal;
    final freeHeight = area.height - panel.height - _margin.vertical;
    final current = _dragAlignment ?? widget.corner;
    final next = Alignment(
      freeWidth <= 0
          ? current.x
          : (current.x + details.delta.dx * 2 / freeWidth).clamp(-1.0, 1.0),
      freeHeight <= 0
          ? current.y
          : (current.y + details.delta.dy * 2 / freeHeight).clamp(-1.0, 1.0),
    );
    var inZone = false;
    if (widget.onDismiss != null) {
      final center = Offset(
        _margin.left + math.max(0, freeWidth) * (next.x + 1) / 2,
        _margin.top + math.max(0, freeHeight) * (next.y + 1) / 2,
      ).translate(panel.width / 2, panel.height / 2);
      inZone =
          center.dy < area.height * 0.22 &&
          (center.dx - area.width / 2).abs() < area.width * 0.2;
      if (inZone && !_inDismissZone) HapticFeedback.mediumImpact();
    }
    setState(() {
      _dragAlignment = next;
      _inDismissZone = inZone;
    });
  }

  void _onDragEnd(DragEndDetails _) {
    final alignment = _dragAlignment;
    if (alignment == null) return;
    if (_inDismissZone) {
      setState(() {
        _dragAlignment = null;
        _inDismissZone = false;
      });
      widget.onDismiss?.call();
      return;
    }
    // Settle in the nearest corner.
    widget.onCornerChanged(
      Alignment(alignment.x < 0 ? -1 : 1, alignment.y < 0 ? -1 : 1),
    );
    setState(() => _dragAlignment = null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = constraints.biggest;
        final compact = widget.compact;
        final shown = compact
            ? 1
            : MembersPanel.previewCount(
                widget.members,
                widget.mainMember,
                collapsed: widget.collapsed,
              );
        // Widest previews that still let every shown one fit in the frame.
        double widthFitting(int count) => compact
            ? math.min(
                area.width * 0.7,
                (area.height - _margin.vertical) * 16 / 9,
              )
            : math.min(
                area.width * 0.6,
                (area.height -
                        _margin.vertical -
                        MembersPanel.chromeFor(count)) *
                    16 /
                    (9 * count),
              );
        // On wide screens the default is sized for five people, so the
        // panel keeps its width as people come and go or it is collapsed.
        final defaultWidth = compact
            ? math.min(170.0, area.shortestSide * 0.42)
            : math.min(
                math.min(200.0, area.width * 0.24),
                widthFitting(MembersPanel.slots),
              );
        final maxWidth = widthFitting(shown);
        final minWidth = math.min(_minTileWidth, maxWidth);
        final tileWidth = (widget.tileWidth ?? defaultWidth).clamp(
          minWidth,
          maxWidth,
        );
        if (tileWidth < (compact ? 64 : 80)) return const SizedBox.shrink();
        final solo = widget.solo;
        if (compact && solo == null) return const SizedBox.shrink();
        final anchorRight = widget.corner.x > 0;
        final anchorBottom = widget.corner.y > 0;
        final dragging = _dragAlignment != null;
        final panelLayer = AnimatedAlign(
          duration: dragging
              ? Duration.zero
              : const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: _dragAlignment ?? widget.corner,
          child: Padding(
            padding: _margin,
            child: Listener(
              // Taps on the panel are not taps on the video.
              onPointerDown: (event) =>
                  MeetingTapListener.ignorePointer(context, event.pointer),
              child: RawGestureDetector(
                gestures: {
                  PanGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        PanGestureRecognizer
                      >(
                        // A smaller slop than the page view's swipe, so a
                        // drag that starts on the panel moves the panel
                        // instead of turning the page (tablets).
                        () => PanGestureRecognizer(debugOwner: this)
                          ..gestureSettings = const DeviceGestureSettings(
                            touchSlop: 6,
                          ),
                        (recognizer) => recognizer
                          ..onUpdate = (details) {
                            _onDragUpdate(details, area);
                          }
                          ..onEnd = _onDragEnd,
                      ),
                },
                child: MouseRegion(
                  cursor: _dragAlignment == null
                      ? SystemMouseCursors.grab
                      : SystemMouseCursors.grabbing,
                  child: Stack(
                    children: [
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _inDismissZone ? 0.4 : 1,
                        child: compact
                            ? _SoloTile(
                                key: _panelKey,
                                member: solo!,
                                tileWidth: tileWidth,
                              )
                            : MembersPanel(
                                key: _panelKey,
                                members: widget.members,
                                mainMember: widget.mainMember,
                                solo: solo,
                                tileWidth: tileWidth,
                                collapsed: widget.collapsed,
                                onCollapsedChanged: widget.onCollapsedChanged,
                                onShowAll: widget.onShowAll,
                              ),
                      ),
                      // In the corner away from the anchored one, so the
                      // panel grows into the video.
                      Positioned(
                        left: anchorRight ? 0 : null,
                        right: anchorRight ? null : 0,
                        top: anchorBottom ? 0 : null,
                        bottom: anchorBottom ? null : 0,
                        child: _ResizeHandle(
                          towardsLeft: anchorRight,
                          towardsTop: anchorBottom,
                          onStart: () {
                            _resizeStartWidth = tileWidth;
                            _resizeDistance = Offset.zero;
                          },
                          onDrag: (delta) {
                            _resizeDistance += delta;
                            final moved = _resizeDistance;
                            // Outward grows; vertical movement counts as
                            // the width change it would cause.
                            final grow =
                                (anchorRight ? -moved.dx : moved.dx) +
                                (anchorBottom ? -moved.dy : moved.dy) *
                                    16 /
                                    (9 * shown);
                            widget.onTileWidthChanged(
                              (_resizeStartWidth + grow).clamp(
                                minWidth,
                                maxWidth,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        if (!compact) return panelLayer;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Where to let go to put the video away; shown while dragging.
            if (dragging)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: AnimatedContainer(
                    key: const ValueKey('meeting-pip-dismiss-target'),
                    duration: const Duration(milliseconds: 150),
                    width: _inDismissZone ? 60 : 48,
                    height: _inDismissZone ? 60 : 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _inDismissZone
                          ? Colors.redAccent.withValues(alpha: 0.9)
                          : glassShade,
                      border: Border.all(color: glassStroke),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
              ),
            panelLayer,
          ],
        );
      },
    );
  }
}

/// The phone's floating video: one person, as a rounded 16:9 tile.
class _SoloTile extends StatelessWidget {
  const _SoloTile({super.key, required this.member, required this.tileWidth});

  final MemberEntry member;
  final double tileWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('meeting-pip'),
      width: tileWidth,
      height: tileWidth * 9 / 16,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: MeetingParticipantTile(
        key: ValueKey('pip-${member.id}'),
        member: member,
      ),
    );
  }
}

/// A tab high on the right edge after the phone's floating video was put away;
/// pulling it left or tapping it brings the video back.
class PipRestoreTab extends StatelessWidget {
  const PipRestoreTab({super.key, required this.onRestore});

  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    var pulled = 0.0;
    return Tooltip(
      message: AppLocalizations.of(context)!.showPictureInPicture,
      child: RawGestureDetector(
        key: const ValueKey('meeting-pip-restore'),
        behavior: HitTestBehavior.opaque,
        gestures: {
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                () => TapGestureRecognizer(debugOwner: this),
                (recognizer) => recognizer.onTap = onRestore,
              ),
          // Claims the drag before the page view can turn the page.
          HorizontalDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                HorizontalDragGestureRecognizer
              >(
                () => HorizontalDragGestureRecognizer(debugOwner: this)
                  ..gestureSettings = const DeviceGestureSettings(touchSlop: 4),
                (recognizer) => recognizer
                  ..onStart = (_) {
                    pulled = 0;
                  }
                  ..onUpdate = (details) {
                    pulled += details.delta.dx;
                  }
                  ..onEnd = (_) {
                    if (pulled < -12) onRestore();
                  },
              ),
        },
        child: SizedBox(
          width: 36,
          height: 72,
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 20,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [glassShade, glassShade.withValues(alpha: 0.7)],
                ),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
                border: Border.all(color: glassStroke),
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                size: 18,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The person a single floating tile shows: the sharer's camera during a
/// screen share, otherwise whoever was on the main video before the current
/// person, else you, else anyone else on the call. Null when nobody but the
/// main person is there.
MemberEntry? soloMember(
  List<MemberEntry> members,
  MemberEntry mainMember, {
  String? previousMainId,
}) {
  if (mainMember.isScreenShare) {
    for (final member in members) {
      if (member.id == mainMember.id) return member;
    }
  }
  final others = [
    for (final member in members)
      if (member.id != mainMember.id) member,
  ];
  if (others.isEmpty) return null;
  for (final member in others) {
    if (member.id == previousMainId) return member;
  }
  for (final member in others) {
    if (member.isLocal) return member;
  }
  return others.first;
}

/// A grip in a corner of the floating panel; dragging it resizes the panel.
class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({
    required this.towardsLeft,
    required this.towardsTop,
    required this.onStart,
    required this.onDrag,
  });

  /// Which corner the grip sits in.
  final bool towardsLeft;
  final bool towardsTop;
  final VoidCallback onStart;
  final ValueChanged<Offset> onDrag;

  @override
  Widget build(BuildContext context) {
    final diagonal = towardsLeft == towardsTop
        ? SystemMouseCursors.resizeUpLeftDownRight
        : SystemMouseCursors.resizeUpRightDownLeft;
    return RawGestureDetector(
      key: const ValueKey('meeting-island-resize'),
      behavior: HitTestBehavior.opaque,
      gestures: {
        PanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
              // Wins over the panel's own drag, which moves it.
              () => PanGestureRecognizer(debugOwner: this)
                ..gestureSettings = const DeviceGestureSettings(touchSlop: 1),
              (recognizer) => recognizer
                // Count the movement from the press, not from when the
                // drag was recognised.
                ..dragStartBehavior = DragStartBehavior.down
                ..onStart = (_) {
                  onStart();
                }
                ..onUpdate = (details) {
                  onDrag(details.delta);
                },
            ),
      },
      child: MouseRegion(
        cursor: diagonal,
        child: SizedBox.square(
          dimension: 20,
          child: CustomPaint(
            painter: _GripPainter(left: towardsLeft, top: towardsTop),
          ),
        ),
      ),
    );
  }
}

/// Two short diagonal strokes pointing into a corner.
class _GripPainter extends CustomPainter {
  const _GripPainter({required this.left, required this.top});

  final bool left;
  final bool top;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    // Drawn for the top-left corner, then mirrored.
    Offset at(double x, double y) =>
        Offset(left ? x : size.width - x, top ? y : size.height - y);
    canvas.drawLine(at(5, 12), at(12, 5), paint);
    canvas.drawLine(at(5, 8), at(8, 5), paint);
  }

  @override
  bool shouldRepaint(_GripPainter old) => old.left != left || old.top != top;
}
