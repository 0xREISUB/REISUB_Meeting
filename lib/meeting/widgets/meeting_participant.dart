import 'package:v_meeting/l10n/app_localizations.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:v_meeting/meeting/meeting_member.dart';

class MeetingParticipantTile extends StatelessWidget {
  final MemberEntry member;
  final bool isMain;
  final String? placeholder;

  const MeetingParticipantTile({
    super.key,
    required this.member,
    this.isMain = false,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(isMain ? 24 : 16);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isMain ? Colors.black : const Color(0xFF1C1C1E),
        borderRadius: radius,
      ),
      // Drawn over the video: underneath, the clipped video covered the
      // border's rounded corners and the line broke up there.
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: member.isSpeaking
              ? Colors.greenAccent
              : member.isLocal
              ? const Color(0xFF8A5CFF)
              : Colors.white12,
          width: member.isSpeaking || member.isLocal ? 2 : 1,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (member.videoTrack != null)
            MeetingVideoView(
              track: member.videoTrack!,
              key: ObjectKey(member.videoTrack),
              compact: !isMain,
              // Tiles are 16:9 and cameras fill them. A shared screen is
              // never cropped, so nothing on it is lost.
              fit: member.isScreenShare
                  ? VideoViewFit.contain
                  : VideoViewFit.cover,
              mirrorMode:
                  member.isLocal && !member.isScreenShare && member.mirrorCamera
                  ? VideoViewMirrorMode.mirror
                  : VideoViewMirrorMode.off,
            )
          else
            Center(
              child: placeholder != null
                  ? Text(
                      placeholder!,
                      style: const TextStyle(color: Colors.white70),
                    )
                  : member.isScreenShare
                  ? Icon(
                      Icons.screen_share_rounded,
                      size: isMain ? 64 : 36,
                      color: Colors.white24,
                    )
                  : MemberAvatar(
                      name: member.name,
                      seed: member.identity.isEmpty
                          ? member.name
                          : member.identity,
                      size: isMain ? 112 : 52,
                    ),
            ),
          Positioned(
            left: 8,
            bottom: 8,
            right: 8,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: _NameLabel(member: member, large: isMain),
            ),
          ),
        ],
      ),
    );
  }
}

/// Name and microphone state in the corner of a tile, as wide as the name.
class _NameLabel extends StatelessWidget {
  const _NameLabel({required this.member, required this.large});

  final MemberEntry member;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final speaking = member.isSpeaking && member.isMicEnabled;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 10 : 8,
        vertical: large ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            member.isMicEnabled ? Icons.mic : Icons.mic_off,
            size: large ? 16 : 14,
            color: !member.isMicEnabled
                ? Colors.redAccent
                : speaking
                ? Colors.greenAccent
                : Colors.white,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              member.isScreenShare
                  ? '${member.name} • ${AppLocalizations.of(context)!.screenShareLabel}'
                  : member.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: large ? 14 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A participant without video: initials on a colour picked from [seed], so
/// each person keeps the same colour.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.name,
    required this.seed,
    required this.size,
  });

  final String name;
  final String seed;
  final double size;

  static const _colors = [
    Color(0xFF5C6BC0),
    Color(0xFF00897B),
    Color(0xFF8D6E63),
    Color(0xFFAB47BC),
    Color(0xFF43A047),
    Color(0xFFEF6C00),
    Color(0xFF1E88E5),
    Color(0xFFD81B60),
  ];

  /// Up to two letters: the first of the first and last words.
  static String initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '?';
    final letters = [
      words.first.characters.first,
      if (words.length > 1) words.last.characters.first,
    ];
    return letters.join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Never larger than a small tile allows.
        final diameter = math.min(size, constraints.biggest.shortestSide * 0.5);
        return Container(
          width: diameter,
          height: diameter,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _colors[hash % _colors.length],
          ),
          child: Text(
            initials(name),
            style: TextStyle(
              color: Colors.white,
              fontSize: diameter * 0.36,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}

/// A video track that shows a loading message instead of a black frame until
/// its first frame arrives. Remote video can take a while: the server waits
/// for the sender's next key frame, longer on a lossy connection.
class MeetingVideoView extends StatefulWidget {
  const MeetingVideoView({
    super.key,
    required this.track,
    required this.fit,
    required this.mirrorMode,
    this.compact = false,
    this.slowAfter = const Duration(seconds: 6),
  });

  final VideoTrack track;
  final VideoViewFit fit;
  final VideoViewMirrorMode mirrorMode;
  final bool compact;
  final Duration slowAfter;

  @override
  State<MeetingVideoView> createState() => _MeetingVideoViewState();
}

class _MeetingVideoViewState extends State<MeetingVideoView> {
  // Our own renderer, so its size can be watched: it reports a size once a
  // frame has been decoded. VideoTrackRenderer takes over onResize.
  final _renderer = rtc.RTCVideoRenderer();
  late final Future<void> _initialized = _renderer.initialize();
  bool _hasFrame = false;
  bool _slow = false;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    _renderer.addListener(_onRendererChanged);
    _slowTimer = Timer(widget.slowAfter, () {
      if (mounted && !_hasFrame) setState(() => _slow = true);
    });
  }

  void _onRendererChanged() {
    final value = _renderer.value;
    if (_hasFrame || value.width <= 0 || value.height <= 0) return;
    _slowTimer?.cancel();
    if (mounted) setState(() => _hasFrame = true);
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _renderer.removeListener(_onRendererChanged);
    // The VideoTrackRenderer child is unmounted first and leaves the renderer
    // to us.
    unawaited(
      _initialized
          .then((_) async {
            _renderer.srcObject = null;
            await _renderer.dispose();
          })
          .catchError((_) {}),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FutureBuilder<void>(
          future: _initialized,
          builder: (context, snapshot) =>
              snapshot.connectionState == ConnectionState.done &&
                  !snapshot.hasError
              ? VideoTrackRenderer(
                  widget.track,
                  cachedRenderer: _renderer,
                  autoDisposeRenderer: false,
                  fit: widget.fit,
                  mirrorMode: widget.mirrorMode,
                )
              : const SizedBox.shrink(),
        ),
        if (!_hasFrame)
          ColoredBox(
            key: const ValueKey('video-loading'),
            color: const Color(0xFF1C1C1E),
            child: _VideoLoading(slow: _slow, compact: widget.compact),
          ),
      ],
    );
  }
}

class _VideoLoading extends StatelessWidget {
  const _VideoLoading({required this.slow, required this.compact});

  final bool slow;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: compact ? 20 : 28,
              child: const CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFFB69BFF),
              ),
            ),
            if (!compact || slow) ...[
              const SizedBox(height: 10),
              Text(
                slow ? l10n.videoLoadingSlow : l10n.videoLoading,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: compact ? 11 : 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

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
                child: _ParticipantPage(
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
                  ? _FloatingMembers(
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
                  _FloatingMembers(
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
                      child: _RestoreTab(
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

/// The participants panel floating over the main video on wide screens. It
/// starts in the bottom-right corner, can be dragged to any corner, and
/// shows up to five people or, collapsed, only one.
class _FloatingMembers extends StatefulWidget {
  const _FloatingMembers({
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
  State<_FloatingMembers> createState() => _FloatingMembersState();
}

class _FloatingMembersState extends State<_FloatingMembers> {
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
            : _MembersPanel.previewCount(
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
                        _MembersPanel.chromeFor(count)) *
                    16 /
                    (9 * count),
              );
        // On wide screens the default is sized for five people, so the
        // panel keeps its width as people come and go or it is collapsed.
        final defaultWidth = compact
            ? math.min(170.0, area.shortestSide * 0.42)
            : math.min(
                math.min(200.0, area.width * 0.24),
                widthFitting(_MembersPanel.slots),
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
                            : _MembersPanel(
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
                          : Colors.black.withValues(alpha: 0.5),
                      border: Border.all(color: Colors.white38),
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
class _RestoreTab extends StatelessWidget {
  const _RestoreTab({required this.onRestore});

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
              decoration: const BoxDecoration(
                color: Color(0xCC2C2C2E),
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
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
@visibleForTesting
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

/// The floating panel's content: a title with the head count and a button
/// to collapse it, then up to five previews, the last one standing in for
/// everyone who does not fit. Collapsed, it shows [solo].
class _MembersPanel extends StatelessWidget {
  const _MembersPanel({
    super.key,
    required this.members,
    required this.mainMember,
    required this.solo,
    required this.tileWidth,
    required this.collapsed,
    required this.onCollapsedChanged,
    required this.onShowAll,
  });

  final List<MemberEntry> members;
  final MemberEntry mainMember;

  /// Who the panel shows when collapsed; see [soloMember].
  final MemberEntry? solo;
  final double tileWidth;
  final bool collapsed;
  final ValueChanged<bool> onCollapsedChanged;
  final VoidCallback onShowAll;

  static const slots = 5;
  static const _gap = 8.0;
  static const _padding = 8.0;
  static const _border = 1.0;
  static const _headerHeight = 24.0;

  /// Height taken by everything but [count] previews.
  static double chromeFor(int count) =>
      (_padding + _border) * 2 + _headerHeight + _gap * count;

  /// How many tiles the panel shows, including the one for everyone else.
  static int previewCount(
    List<MemberEntry> members,
    MemberEntry mainMember, {
    required bool collapsed,
  }) {
    if (collapsed) return 1;
    final others = members
        .where(
          (member) => mainMember.isScreenShare || member.id != mainMember.id,
        )
        .length;
    return math.max(1, math.min(others, slots));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final others = [
      for (final member in members)
        if (mainMember.isScreenShare || member.id != mainMember.id) member,
    ];
    final overflow = !collapsed && others.length > slots;
    final List<MemberEntry> previews;
    if (collapsed) {
      previews = [solo ?? others.first];
    } else {
      previews = others.take(overflow ? slots - 1 : slots).toList();
    }
    return Container(
      key: const ValueKey('meeting-sidebar'),
      // The border is inside the width, as Container adds it to padding.
      width: tileWidth + (_padding + _border) * 2,
      padding: const EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: const Color(0xE6151517),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12, width: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _headerHeight,
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.group_rounded,
                    size: 14,
                    color: Colors.white60,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${members.length}',
                    key: const ValueKey('meeting-sidebar-count'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    key: const ValueKey('meeting-island-collapse'),
                    tooltip: collapsed
                        ? l10n.expandParticipants
                        : l10n.collapseParticipants,
                    onPressed: () => onCollapsedChanged(!collapsed),
                    iconSize: 15,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 22,
                      height: 22,
                    ),
                    color: Colors.white70,
                    icon: Icon(
                      collapsed
                          ? Icons.open_in_full_rounded
                          : Icons.close_fullscreen_rounded,
                    ),
                  ),
                ],
              ),
            ),
            for (final member in previews) ...[
              const SizedBox(height: _gap),
              SizedBox(
                width: tileWidth,
                height: tileWidth * 9 / 16,
                child: MeetingParticipantTile(
                  key: ValueKey('preview-${member.id}'),
                  member: member,
                ),
              ),
            ],
            if (overflow) ...[
              const SizedBox(height: _gap),
              SizedBox(
                width: tileWidth,
                height: tileWidth * 9 / 16,
                child: _MoreParticipants(
                  key: const ValueKey('meeting-sidebar-more'),
                  people: others.skip(previews.length).toList(),
                  label: l10n.moreParticipants(others.length - previews.length),
                  onTap: onShowAll,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
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

/// The last sidebar slot when more people are in the meeting than fit:
/// a few of their initials and how many more there are.
class _MoreParticipants extends StatelessWidget {
  const _MoreParticipants({
    super.key,
    required this.people,
    required this.label,
    required this.onTap,
  });

  final List<MemberEntry> people;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final faces = people.take(3).toList();
    return Material(
      color: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 36,
              width: 36 + (faces.length - 1) * 24.0,
              child: Stack(
                children: [
                  for (var i = 0; i < faces.length; i++)
                    Positioned(
                      left: i * 24.0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1C1C1E),
                          shape: BoxShape.circle,
                        ),
                        child: MemberAvatar(
                          name: faces[i].name,
                          seed: faces[i].identity.isEmpty
                              ? faces[i].name
                              : faces[i].identity,
                          size: 32,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
    return Row(
      key: const ValueKey('meeting-page-dots'),
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
                  color: page == current
                      ? const Color(0xFFB69BFF)
                      : Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Carries two-finger pinches detected above the page view to the main
/// video, which owns the zoom.
/// Reports a single-finger tap anywhere on [child], even where a widget
/// inside handles the tap itself. On phones the video renderer of the local
/// camera claims taps for focus, which kept a GestureDetector here from ever
/// seeing taps on the video. Drags and pinches are not taps.
class MeetingTapListener extends StatefulWidget {
  const MeetingTapListener({
    super.key,
    required this.onTap,
    required this.child,
  });

  final VoidCallback? onTap;
  final Widget child;

  /// Keeps a pointer that went down on [context]'s widget, for example a
  /// panel laid over the video, from counting as a tap on the video. Call
  /// it from that widget's own onPointerDown, which runs first.
  static void ignorePointer(BuildContext context, int pointer) => context
      .findAncestorStateOfType<_MeetingTapListenerState>()
      ?._ignored
      .add(pointer);

  @override
  State<MeetingTapListener> createState() => _MeetingTapListenerState();
}

class _MeetingTapListenerState extends State<MeetingTapListener> {
  final _down = <int, (Offset, Duration)>{};
  final _ignored = <int>{};
  bool _multiTouch = false;

  void _onDown(PointerDownEvent event) {
    if (_ignored.contains(event.pointer)) return;
    _down[event.pointer] = (event.position, event.timeStamp);
    if (_down.length > 1) _multiTouch = true;
  }

  void _onUp(PointerUpEvent event) {
    _ignored.remove(event.pointer);
    final start = _down.remove(event.pointer);
    final multiTouch = _multiTouch;
    if (_down.isEmpty) _multiTouch = false;
    if (start == null || multiTouch) return;
    final (position, time) = start;
    final moved = (event.position - position).distance;
    final held = event.timeStamp - time;
    if (moved <= kTouchSlop && held <= const Duration(milliseconds: 500)) {
      widget.onTap?.call();
    }
  }

  void _onCancel(PointerCancelEvent event) {
    _ignored.remove(event.pointer);
    _down.remove(event.pointer);
    if (_down.isEmpty) _multiTouch = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onDown,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: widget.child,
    );
  }
}

class ScreenZoomRelay {
  _MeetingMainVideoState? _target;

  void pinch(double factor, Offset globalFocal) =>
      _target?._applyPinch(factor, globalFocal);
}

class MeetingMainVideo extends StatefulWidget {
  const MeetingMainVideo({
    super.key,
    required this.member,
    this.connecting = false,
    this.onZoomChanged,
    this.zoomRelay,
    this.overlay,
    this.floating,
    this.fillArea = false,
  });
  final MemberEntry member;
  final bool connecting;
  final ValueChanged<bool>? onZoomChanged;

  /// Buttons shown in the frame's top-right corner.
  final Widget? overlay;

  /// A layer over the video that fills the frame, such as the floating
  /// participants panel. It sits under [overlay].
  final Widget? floating;

  /// Lets a camera's frame take the area's shape (within 4:3 to 21:9),
  /// cropping the video a little at the sides, instead of a 16:9 frame. A
  /// shared screen always keeps 16:9 and is never cropped.
  final bool fillArea;

  /// Delivers pinches that the surrounding layout detected.
  final ScreenZoomRelay? zoomRelay;

  @override
  State<MeetingMainVideo> createState() => _MeetingMainVideoState();
}

class _MeetingMainVideoState extends State<MeetingMainVideo> {
  static const _maxScale = 6.0;

  final _transform = TransformationController();
  bool _zoomed = false;
  final _frameKey = GlobalKey();

  bool _viewerPinching = false;

  /// Applies a pinch reported by [ScreenZoomRelay], unless InteractiveViewer
  /// already won the gesture and is zooming itself.
  void _applyPinch(double factor, Offset globalFocal) {
    if (!widget.member.isScreenShare || _viewerPinching) return;
    final box = _frameKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    _transform.value = _scaledAround(
      factor,
      box.globalToLocal(globalFocal),
      box.size,
    );
  }

  /// Scales by [factor] around [focal], keeping the scale within 1–6× and
  /// the shared screen inside the viewport.
  Matrix4 _scaledAround(double factor, Offset focal, Size size) {
    final current = _transform.value;
    final scale = current.getMaxScaleOnAxis();
    final target = (scale * factor).clamp(1.0, _maxScale).toDouble();
    if (target <= 1.0) return Matrix4.identity();
    final step = target / scale;
    final next =
        (Matrix4.identity()
          ..translateByDouble(focal.dx, focal.dy, 0.0, 1.0)
          ..scaleByDouble(step, step, 1.0, 1.0)
          ..translateByDouble(-focal.dx, -focal.dy, 0.0, 1.0)) *
        current;
    final translation = next.getTranslation();
    next.setTranslationRaw(
      translation.x.clamp(size.width * (1 - target), 0.0).toDouble(),
      translation.y.clamp(size.height * (1 - target), 0.0).toDouble(),
      0.0,
    );
    return next;
  }

  @override
  void didUpdateWidget(covariant MeetingMainVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.zoomRelay, widget.zoomRelay)) {
      if (identical(oldWidget.zoomRelay?._target, this)) {
        oldWidget.zoomRelay?._target = null;
      }
      widget.zoomRelay?._target = this;
    }
    if (oldWidget.member.videoTrack != widget.member.videoTrack ||
        oldWidget.member.isScreenShare != widget.member.isScreenShare) {
      _transform.removeListener(_changed);
      _transform.value = Matrix4.identity();
      _zoomed = false;
      _transform.addListener(_changed);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onZoomChanged?.call(false);
      });
    }
  }

  void _changed() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (_zoomed != zoomed) {
      setState(() => _zoomed = zoomed);
      widget.onZoomChanged?.call(zoomed);
    }
  }

  @override
  void initState() {
    super.initState();
    _transform.addListener(_changed);
    widget.zoomRelay?._target = this;
  }

  @override
  void dispose() {
    if (identical(widget.zoomRelay?._target, this)) {
      widget.zoomRelay?._target = null;
    }
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = constraints.biggest;
        var aspectRatio = 16 / 9;
        if (widget.fillArea &&
            !widget.member.isScreenShare &&
            area.height > 0 &&
            area.width.isFinite) {
          aspectRatio = (area.width / area.height).clamp(4 / 3, 21 / 9);
        }
        Widget content = MeetingParticipantTile(
          member: widget.member,
          isMain: true,
          placeholder: widget.connecting
              ? AppLocalizations.of(context)!.connecting
              : null,
        );
        if (widget.member.isScreenShare) {
          content = InteractiveViewer(
            key: const ValueKey('main-video-zoom'),
            transformationController: _transform,
            minScale: 1,
            maxScale: _maxScale,
            panEnabled: _zoomed,
            trackpadScrollCausesScale: true,
            onInteractionStart: (details) =>
                _viewerPinching = details.pointerCount >= 2,
            onInteractionUpdate: (details) {
              if (details.pointerCount >= 2) _viewerPinching = true;
            },
            onInteractionEnd: (_) => _viewerPinching = false,
            child: content,
          );
        }
        return Center(
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              key: _frameKey,
              fit: StackFit.expand,
              children: [
                content,
                if (_zoomed)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: TextButton.icon(
                      key: const ValueKey('reset-video-zoom'),
                      onPressed: () => _transform.value = Matrix4.identity(),
                      icon: const Icon(Icons.zoom_out_map_rounded),
                      label: Text(AppLocalizations.of(context)!.resetZoom),
                    ),
                  ),
                if (widget.floating != null)
                  Positioned.fill(child: widget.floating!),
                if (widget.overlay != null)
                  Positioned(right: 12, top: 12, child: widget.overlay!),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One gallery page. All tiles have the same 16:9 size, like a computer
/// screen, instead of an even split of the screen, and are laid out in the
/// column count that makes them largest. Videos fill their tile.
class _ParticipantPage extends StatelessWidget {
  final List<MemberEntry> members;
  final int columns;

  const _ParticipantPage({required this.members, required this.columns});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final layout = galleryLayout(
          count: members.length,
          maxColumns: columns,
          area: constraints.biggest,
          aspectRatio: 16 / 9,
          gap: gap,
        );
        final rows = <Widget>[];
        for (var start = 0; start < members.length; start += layout.columns) {
          final row = members.skip(start).take(layout.columns).toList();
          rows.add(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  SizedBox.fromSize(
                    size: layout.tileSize,
                    child: MeetingParticipantTile(
                      key: ValueKey(row[i].id),
                      member: row[i],
                    ),
                  ),
                ],
              ],
            ),
          );
        }
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: gap),
                rows[i],
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Equal tiles of [aspectRatio] for [count] members, in the column count
/// (up to [maxColumns]) that makes them largest within [area].
@visibleForTesting
({int columns, Size tileSize}) galleryLayout({
  required int count,
  required int maxColumns,
  required Size area,
  required double aspectRatio,
  double gap = 10,
}) {
  var best = (columns: 1, tileSize: Size.zero);
  if (count == 0 || area.isEmpty) return best;
  for (var columns = 1; columns <= math.min(count, maxColumns); columns++) {
    final rows = (count / columns).ceil();
    final width = math.min(
      (area.width - gap * (columns - 1)) / columns,
      (area.height - gap * (rows - 1)) / rows * aspectRatio,
    );
    if (width > best.tileSize.width) {
      best = (columns: columns, tileSize: Size(width, width / aspectRatio));
    }
  }
  return best;
}
