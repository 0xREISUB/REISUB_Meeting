import 'package:v_meeting/l10n/app_localizations.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:v_meeting/meeting/meeting_member.dart';
import 'package:v_meeting/meeting/widgets/participant_tile.dart';
import 'package:v_meeting/meeting/widgets/floating_members.dart';
import 'package:v_meeting/widgets/glass.dart';
import 'package:v_meeting/social/user_avatar.dart';

/// The floating panel's content: a title with the head count and a button
/// to collapse it, then up to five previews, the last one standing in for
/// everyone who does not fit. Collapsed, it shows [solo].
class MembersPanel extends StatelessWidget {
  const MembersPanel({
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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 24,
            spreadRadius: -4,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: glassFilter(),
          child: Container(
            key: const ValueKey('meeting-sidebar'),
            // The border is inside the width, as Container adds it to padding.
            width: tileWidth + (_padding + _border) * 2,
            padding: const EdgeInsets.all(_padding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  glassSmoke.withValues(alpha: 0.62),
                  glassSmoke.withValues(alpha: 0.40),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: glassStroke, width: _border),
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
                        label: l10n.moreParticipants(
                          others.length - previews.length,
                        ),
                        onTap: onShowAll,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
      color: glassFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: glassStroke),
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
                          color: glassBadgeRim,
                          shape: BoxShape.circle,
                        ),
                        child: UserAvatar(
                          name: faces[i].name,
                          seed: faces[i].identity.isEmpty
                              ? faces[i].name
                              : faces[i].identity,
                          avatarUrl: faces[i].avatarUrl,
                          size: 32,
                          fitTile: true,
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
