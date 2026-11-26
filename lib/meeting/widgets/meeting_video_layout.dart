import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:v_meeting/meeting/meeting_member.dart';
import 'package:v_meeting/meeting/widgets/floating_members.dart';
import 'package:v_meeting/meeting/widgets/meeting_tap_listener.dart';
import 'package:v_meeting/meeting/widgets/meeting_main_video.dart';
import 'package:v_meeting/meeting/widgets/participant_gallery.dart';
import 'package:v_meeting/widgets/glass.dart';

class MeetingVideoLayout extends StatefulWidget {
  final List<MemberEntry> members;
  final MemberEntry mainMember;
  final bool connecting;
  final VoidCallback? onMainPageTap;
  final VoidCallback? onStopScreenShare;

  const MeetingVideoLayout({
    super.key,
    required this.members,
    required this.mainMember,
    this.connecting = false,
    this.onMainPageTap,
    this.onStopScreenShare,
  });

  @override
  State<MeetingVideoLayout> createState() => _MeetingVideoLayoutState();
}

class _MeetingVideoLayoutState extends State<MeetingVideoLayout> {
  final _controller = PageController();
  int _page = 0;
  bool _fullscreen = false;
  bool _zoomed = false;
  bool _pinching = false;
  final _zoomRelay = ScreenZoomRelay();

  /// Where the floating participants panel sits, and whether it shows one
  /// person instead of five. Kept here so they survive the main video
  /// switching to another speaker.
  Alignment _islandCorner = Alignment.bottomRight;
  bool _islandCollapsed = false;

  /// Preview width the user picked by resizing the panel; null for the
  /// default size.
  double? _islandTileWidth;

  /// The phone's small floating video: its corner, its size and whether it
  /// was dragged away.
  Alignment _pipCorner = Alignment.topRight;
  double? _pipTileWidth;
  bool _pipDismissed = false;

  /// Who was on the main video before the current person; the single
  /// floating tile shows them.
  String? _previousMainId;

  /// Touch points tracked above the page view. Once a page drag starts, the
  /// page view stops passing touches to its children, so a second finger
  /// would never reach the shared screen's own zoom handling.
  final _touches = <int, Offset>{};
  double? _pinchDistance;

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    _touches[event.pointer] = event.position;
    if (_touches.length == 2 && _page == 0 && widget.mainMember.isScreenShare) {
      _pinchDistance = _touchDistance();
      setState(() => _pinching = true);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_touches.containsKey(event.pointer)) return;
    _touches[event.pointer] = event.position;
    final previous = _pinchDistance;
    if (!_pinching ||
        _touches.length < 2 ||
        previous == null ||
        previous == 0) {
      return;
    }
    final distance = _touchDistance();
    _pinchDistance = distance;
    final points = _touches.values.take(2).toList();
    _zoomRelay.pinch(distance / previous, (points[0] + points[1]) / 2);
  }

  void _onPointerEnd(PointerEvent event) {
    if (_touches.remove(event.pointer) == null) return;
    if (_touches.length < 2 && _pinching) {
      _pinchDistance = null;
      setState(() => _pinching = false);
    }
  }

  double _touchDistance() {
    final points = _touches.values.take(2).toList();
    return (points[0] - points[1]).distance;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(covariant MeetingVideoLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mainMember.id != widget.mainMember.id &&
        !oldWidget.mainMember.isScreenShare) {
      _previousMainId = oldWidget.mainMember.id;
    }
    if (oldWidget.mainMember.id != widget.mainMember.id ||
        !widget.mainMember.isScreenShare) {
      _zoomed = false;
    }
    if (widget.mainMember.isScreenShare &&
        (!oldWidget.mainMember.isScreenShare ||
            oldWidget.mainMember.id != widget.mainMember.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide =
            MediaQuery.sizeOf(context).shortestSide >= 600 &&
            constraints.maxWidth > 800;
        final perPage = isWide ? 16 : 4;
        final galleryPages = !_fullscreen && widget.members.length > 1
            ? (widget.members.length / perPage).ceil()
            : 0;
        final pageCount = 1 + galleryPages;
        // Membership changes can remove the page currently being viewed.
        if (_page >= pageCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _controller.hasClients) {
              _controller.jumpToPage(pageCount - 1);
            }
          });
        }
        final pages = PageView.builder(
          key: const ValueKey('meeting-pages'),
          controller: _controller,
          // Pages swipe with a finger and with a two-finger touchpad swipe,
          // at any window size. Removing the scroll physics also cancels a
          // page drag that the first finger of a pinch may have started.
          physics: _zoomed || _pinching
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          onPageChanged: (page) => setState(() => _page = page),
          itemCount: pageCount,
          itemBuilder: (context, page) {
            if (page > 0) {
              final entries = widget.members
                  .skip((page - 1) * perPage)
                  .take(perPage)
                  .toList();
              return MeetingTapListener(
                key: ValueKey('gallery-page-$page'),
                onTap: widget.onMainPageTap,
                child: ParticipantGalleryPage(
                  members: entries,
                  columns: isWide ? 4 : 2,
                ),
              );
            }
            final l10n = AppLocalizations.of(context)!;
            final showStopShare =
                widget.mainMember.isScreenShare &&
                widget.mainMember.isLocal &&
                widget.onStopScreenShare != null;
            final showIsland =
                isWide &&
                !_fullscreen &&
                (widget.members.length > 1 || widget.mainMember.isScreenShare);
            final solo = soloMember(
              widget.members,
              widget.mainMember,
              previousMainId: _previousMainId,
            );
            final mainVideo = MeetingMainVideo(
              key: ValueKey('main-${widget.mainMember.id}'),
              member: widget.mainMember,
              connecting: widget.connecting,
              fillArea: isWide,
              floating: showIsland
                  ? FloatingMembers(
                      members: widget.members,
                      mainMember: widget.mainMember,
                      corner: _islandCorner,
                      collapsed: _islandCollapsed,
                      solo: solo,
                      tileWidth: _islandTileWidth,
                      onTileWidthChanged: (width) =>
                          setState(() => _islandTileWidth = width),
                      onCornerChanged: (corner) =>
                          setState(() => _islandCorner = corner),
                      onCollapsedChanged: (collapsed) =>
                          setState(() => _islandCollapsed = collapsed),
                      onShowAll: () => _goToPage(1),
                    )
                  : null,
              onZoomChanged: (value) {
                if (value != _zoomed) setState(() => _zoomed = value);
              },
              zoomRelay: _zoomRelay,
              overlay: showStopShare || isWide
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8,
                      children: [
                        if (showStopShare)
                          FilledButton.icon(
                            onPressed: widget.onStopScreenShare,
                            icon: const Icon(Icons.stop_rounded),
                            label: Text(l10n.stopScreenSharing),
                          ),
                        if (isWide)
                          _FrameButton(
                            key: const ValueKey('main-fullscreen'),
                            tooltip: _fullscreen
                                ? l10n.exitFullscreen
                                : l10n.fullscreenMainVideo,
                            icon: _fullscreen
                                ? Icons.fullscreen_exit_rounded
                                : Icons.fullscreen_rounded,
                            onPressed: () => setState(() {
                              _fullscreen = !_fullscreen;
                              _zoomed = false;
                            }),
                          ),
                      ],
                    )
                  : null,
            );
            final mainPage = MeetingTapListener(
              onTap: widget.onMainPageTap,
              child: mainVideo,
            );
            if (isWide || solo == null) return mainPage;
            // Phones: one person floats over the whole page.
            return Stack(
              fit: StackFit.expand,
              children: [
                mainPage,
                if (!_pipDismissed)
                  FloatingMembers(
                    compact: true,
                    members: widget.members,
                    mainMember: widget.mainMember,
                    corner: _pipCorner,
                    collapsed: true,
                    solo: solo,
                    tileWidth: _pipTileWidth,
                    onTileWidthChanged: (width) =>
                        setState(() => _pipTileWidth = width),
                    onCornerChanged: (corner) =>
                        setState(() => _pipCorner = corner),
                    onCollapsedChanged: (_) {},
                    onShowAll: () => _goToPage(1),
                    onDismiss: () => setState(() => _pipDismissed = true),
                  )
                else
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    // In the upper part of the edge: a camera cutout in the
                    // middle of a landscape phone's edge would cover it.
                    child: Align(
                      alignment: const Alignment(0, -0.6),
                      child: PipRestoreTab(
                        onRestore: () => setState(() => _pipDismissed = false),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
        if (!isWide) {
          return Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerEnd,
            onPointerCancel: _onPointerEnd,
            child: pages,
          );
        }
        if (pageCount == 1 || _fullscreen) return pages;
        final l10n = AppLocalizations.of(context)!;
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: _page > 0
                        ? Center(
                            child: _FrameButton(
                              key: const ValueKey('meeting-previous-page'),
                              tooltip: l10n.previousPage,
                              icon: Icons.chevron_left_rounded,
                              onPressed: () => _goToPage(_page - 1),
                            ),
                          )
                        : null,
                  ),
                  Expanded(child: pages),
                  SizedBox(
                    width: 56,
                    child: _page < pageCount - 1
                        ? Center(
                            child: _FrameButton(
                              key: const ValueKey('meeting-next-page'),
                              tooltip: l10n.nextPage,
                              icon: Icons.chevron_right_rounded,
                              onPressed: () => _goToPage(_page + 1),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _PageDots(count: pageCount, current: _page, onSelected: _goToPage),
          ],
        );
      },
    );
  }
}

/// A round, translucent button laid over video.
class _FrameButton extends StatelessWidget {
  const _FrameButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      color: Colors.white,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.45),
        hoverColor: Colors.white.withValues(alpha: 0.12),
        side: const BorderSide(color: Colors.white24),
      ),
    );
  }
}

/// Which page of the meeting is shown; a dot can be clicked to go there.
class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.current,
    required this.onSelected,
  });

  final int count;
  final int current;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      key: const ValueKey('meeting-page-dots'),
      tint: glassSmoke,
      shadow: false,
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var page = 0; page < count; page++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(page),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: page == current ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: page == current ? glassAccent : Colors.white38,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
