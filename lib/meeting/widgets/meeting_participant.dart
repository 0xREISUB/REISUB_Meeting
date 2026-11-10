import 'package:v_meeting/l10n/app_localizations.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
          // Removing the scroll physics also cancels a page drag that the
          // first finger of a pinch may already have started.
          physics: isWide || _zoomed || _pinching
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
            final mainVideo = Stack(
              fit: StackFit.expand,
              children: [
                MeetingMainVideo(
                  key: ValueKey('main-${widget.mainMember.id}'),
                  member: widget.mainMember,
                  connecting: widget.connecting,
                  onZoomChanged: (value) {
                    if (value != _zoomed) setState(() => _zoomed = value);
                  },
                  zoomRelay: _zoomRelay,
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.mainMember.isScreenShare &&
                          widget.mainMember.isLocal &&
                          widget.onStopScreenShare != null)
                        FilledButton.icon(
                          onPressed: widget.onStopScreenShare,
                          icon: const Icon(Icons.stop_rounded),
                          label: Text(
                            AppLocalizations.of(context)!.stopScreenSharing,
                          ),
                        ),
                      if (isWide)
                        IconButton.filledTonal(
                          key: const ValueKey('main-fullscreen'),
                          tooltip: _fullscreen
                              ? AppLocalizations.of(context)!.exitFullscreen
                              : AppLocalizations.of(
                                  context,
                                )!.fullscreenMainVideo,
                          onPressed: () => setState(() {
                            _fullscreen = !_fullscreen;
                            _zoomed = false;
                          }),
                          icon: Icon(
                            _fullscreen
                                ? Icons.fullscreen_exit_rounded
                                : Icons.fullscreen_rounded,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
            if (!isWide ||
                _fullscreen ||
                (widget.members.length == 1 &&
                    !widget.mainMember.isScreenShare)) {
              return MeetingTapListener(
                onTap: widget.onMainPageTap,
                child: mainVideo,
              );
            }
            final previews = widget.members
                .where(
                  (member) =>
                      widget.mainMember.isScreenShare ||
                      member.id != widget.mainMember.id,
                )
                .take(5)
                .toList();
            return MeetingTapListener(
              onTap: widget.onMainPageTap,
              child: Row(
                children: [
                  Expanded(child: mainVideo),
                  const SizedBox(width: 16),
                  SizedBox(
                    key: const ValueKey('meeting-sidebar'),
                    // Reserve room for five 16:9 previews regardless of how
                    // many people have joined, so existing tiles keep their size.
                    width: math.min(
                      280,
                      (constraints.maxHeight - 40) * 16 / 45,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (
                          var index = 0;
                          index < previews.length;
                          index++
                        ) ...[
                          if (index > 0) const SizedBox(height: 10),
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: MeetingParticipantTile(
                              key: ValueKey('preview-${previews[index].id}'),
                              member: previews[index],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
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
        return Row(
          children: [
            SizedBox(
              width: 48,
              child: _page > 0
                  ? IconButton(
                      key: const ValueKey('meeting-previous-page'),
                      tooltip: AppLocalizations.of(context)!.previousPage,
                      color: Colors.white,
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => _goToPage(_page - 1),
                    )
                  : null,
            ),
            Expanded(child: pages),
            SizedBox(
              width: 48,
              child: _page < pageCount - 1
                  ? IconButton(
                      key: const ValueKey('meeting-next-page'),
                      tooltip: AppLocalizations.of(context)!.nextPage,
                      color: Colors.white,
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () => _goToPage(_page + 1),
                    )
                  : null,
            ),
          ],
        );
      },
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

  @override
  State<MeetingTapListener> createState() => _MeetingTapListenerState();
}

class _MeetingTapListenerState extends State<MeetingTapListener> {
  final _down = <int, (Offset, Duration)>{};
  bool _multiTouch = false;

  void _onDown(PointerDownEvent event) {
    _down[event.pointer] = (event.position, event.timeStamp);
    if (_down.length > 1) _multiTouch = true;
  }

  void _onUp(PointerUpEvent event) {
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
  });
  final MemberEntry member;
  final bool connecting;
  final ValueChanged<bool>? onZoomChanged;

  /// Delivers pinches that the surrounding layout detected.
  final ScreenZoomRelay? zoomRelay;

  @override
  State<MeetingMainVideo> createState() => _MeetingMainVideoState();
}

class _MeetingMainVideoState extends State<MeetingMainVideo> {
  static const _maxScale = 6.0;

  final _transform = TransformationController();
  bool _zoomed = false;

  bool _viewerPinching = false;

  /// Applies a pinch reported by [ScreenZoomRelay], unless InteractiveViewer
  /// already won the gesture and is zooming itself.
  void _applyPinch(double factor, Offset globalFocal) {
    if (!widget.member.isScreenShare || _viewerPinching) return;
    final box = context.findRenderObject();
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
    // A 16:9 frame like the gallery's, instead of filling the whole area.
    final tile = Center(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: MeetingParticipantTile(
          member: widget.member,
          isMain: true,
          placeholder: widget.connecting
              ? AppLocalizations.of(context)!.connecting
              : null,
        ),
      ),
    );
    if (!widget.member.isScreenShare) return tile;
    return Stack(
      fit: StackFit.expand,
      children: [
        InteractiveViewer(
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
          child: tile,
        ),
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
      ],
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
