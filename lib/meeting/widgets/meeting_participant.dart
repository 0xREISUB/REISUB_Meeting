import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class MemberEntry {
  final String id;
  final String name;
  final bool isLocal;
  final bool isMicEnabled;
  final bool isSpeaking;
  final VideoTrack? videoTrack;

  const MemberEntry({
    required this.id,
    required this.name,
    required this.isLocal,
    required this.isMicEnabled,
    this.isSpeaking = false,
    this.videoTrack,
  });
}

MemberEntry selectMainMember(
  List<MemberEntry> members, {
  required List<String> activeSpeakerIds,
  String? previousSpeakerId,
}) {
  assert(members.isNotEmpty);
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
        color: const Color(0xFF1C1C1E),
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
              fit: VideoViewFit.cover,
              mirrorMode: member.isLocal
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
                      Icons.person,
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
                      member.name,
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

  const MeetingVideoLayout({
    super.key,
    required this.members,
    required this.mainMember,
    this.connecting = false,
  });

  @override
  State<MeetingVideoLayout> createState() => _MeetingVideoLayoutState();
}

class _MeetingVideoLayoutState extends State<MeetingVideoLayout> {
  final _controller = PageController();
  int _page = 0;

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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        final perPage = isWide ? 16 : 4;
        final galleryPages = widget.members.length > 1
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
          physics: isWide
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
            final mainVideo = MeetingParticipantTile(
              key: ValueKey('main-${widget.mainMember.id}'),
              member: widget.mainMember,
              isMain: true,
              placeholder: widget.connecting ? 'Bağlanıyor...' : null,
            );
            if (!isWide || widget.members.length == 1) return mainVideo;
            final previews = widget.members
                .where((member) => member.id != widget.mainMember.id)
                .take(5)
                .toList();
            return Row(
              children: [
                Expanded(child: mainVideo),
                const SizedBox(width: 16),
                SizedBox(
                  key: const ValueKey('meeting-sidebar'),
                  width: 220,
                  child: Column(
                    children: [
                      for (var index = 0; index < previews.length; index++) ...[
                        if (index > 0) const SizedBox(height: 10),
                        Expanded(
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
            );
          },
        );
        if (!isWide || pageCount == 1) return pages;
        return Row(
          children: [
            SizedBox(
              width: 48,
              child: _page > 0
                  ? IconButton(
                      key: const ValueKey('meeting-previous-page'),
                      tooltip: 'Önceki sayfa',
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
                      tooltip: 'Sonraki sayfa',
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
