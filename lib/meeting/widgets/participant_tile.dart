import 'package:v_meeting/l10n/app_localizations.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:v_meeting/meeting/meeting_member.dart';
import 'package:v_meeting/widgets/glass.dart';

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
      // Glass without blur: there is one on every tile, over video.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [glassShade, glassShade.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: glassStroke),
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
                color: glassAccent,
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
