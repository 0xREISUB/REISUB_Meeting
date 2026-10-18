import 'package:v_meeting/l10n/app_localizations.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class MemberEntry {
  final String id;
  final String name;
  final String identity;
  final bool isMicrophoneLocked;
  final bool isLocal;
  final bool isMicEnabled;
  final bool isSpeaking;
  final VideoTrack? videoTrack;
  final VideoTrack? screenShareTrack;
  final bool isScreenSharing;
  final bool isScreenShare;

  const MemberEntry({
    required this.id,
    required this.name,
    this.identity = '',
    this.isMicrophoneLocked = false,
    required this.isLocal,
    required this.isMicEnabled,
    this.isSpeaking = false,
    this.videoTrack,
    this.screenShareTrack,
    this.isScreenSharing = false,
    this.isScreenShare = false,
  });
}

MemberEntry selectMainMember(
  List<MemberEntry> members, {
  required List<String> activeSpeakerIds,
  String? previousSpeakerId,
}) {
  assert(members.isNotEmpty);
  for (final member in members) {
    if (member.isScreenSharing) {
      return MemberEntry(
        id: member.id,
        name: member.name,
        identity: member.identity,
        isLocal: member.isLocal,
        isMicEnabled: member.isMicEnabled,
        videoTrack: member.screenShareTrack,
        isScreenShare: true,
      );
    }
  }

  if (members.length == 1) return members.first;
  if (members.length == 2) {
    return members.firstWhere((member) => !member.isLocal);
  }
  for (final id in activeSpeakerIds) {
    for (final member in members) {
      if (member.id == id) return member;
    }
  }
  return members.firstWhere(
    (member) => member.id == previousSpeakerId,
    orElse: () => members.firstWhere((member) => !member.isLocal),
  );
}

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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isMain ? Colors.black : const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(isMain ? 24 : 16),
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
            VideoTrackRenderer(
              member.videoTrack!,
              key: ObjectKey(member.videoTrack),
              fit: isMain ? VideoViewFit.contain : VideoViewFit.cover,
              mirrorMode: member.isLocal && !member.isScreenShare
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
                  : Icon(
                      member.isScreenShare
                          ? Icons.screen_share_rounded
                          : Icons.person,
                      size: isMain ? 64 : 36,
                      color: Colors.white24,
                    ),
            ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    member.isMicEnabled ? Icons.mic : Icons.mic_off,
                    size: 14,
                    color: member.isMicEnabled
                        ? Colors.white
                        : Colors.redAccent,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      member.isScreenShare
                          ? '${member.name} • ${AppLocalizations.of(context)!.screenShareLabel}'
                          : member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMain ? 14 : 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
          physics: isWide || _zoomed
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
              return _ParticipantPage(
                key: ValueKey('gallery-page-$page'),
                members: entries,
                columns: isWide ? 4 : 2,
                rows: isWide ? 4 : 2,
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
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
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
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
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
        if (!isWide || pageCount == 1 || _fullscreen) return pages;
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

class MeetingMainVideo extends StatefulWidget {
  const MeetingMainVideo({
    super.key,
    required this.member,
    this.connecting = false,
    this.onZoomChanged,
  });
  final MemberEntry member;
  final bool connecting;
  final ValueChanged<bool>? onZoomChanged;

  @override
  State<MeetingMainVideo> createState() => _MeetingMainVideoState();
}

class _MeetingMainVideoState extends State<MeetingMainVideo> {
  final _transform = TransformationController();
  bool _zoomed = false;

  @override
  void didUpdateWidget(covariant MeetingMainVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
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
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tile = MeetingParticipantTile(
      member: widget.member,
      isMain: true,
      placeholder: widget.connecting
          ? AppLocalizations.of(context)!.connecting
          : null,
    );
    if (!widget.member.isScreenShare) return tile;
    return Stack(
      fit: StackFit.expand,
      children: [
        InteractiveViewer(
          key: const ValueKey('main-video-zoom'),
          transformationController: _transform,
          minScale: 1,
          maxScale: 6,
          panEnabled: _zoomed,
          trackpadScrollCausesScale: true,
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

class _ParticipantPage extends StatelessWidget {
  final List<MemberEntry> members;
  final int columns;
  final int rows;

  const _ParticipantPage({
    super.key,
    required this.members,
    required this.columns,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        final tileHeight = (constraints.maxHeight - gap * (rows - 1)) / rows;
        return GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: tileWidth / tileHeight,
          ),
          itemCount: members.length,
          itemBuilder: (context, index) => MeetingParticipantTile(
            key: ValueKey(members[index].id),
            member: members[index],
          ),
        );
      },
    );
  }
}
