import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:v_meeting/meeting/meeting_member.dart';
import 'package:v_meeting/meeting/widgets/participant_tile.dart';

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
