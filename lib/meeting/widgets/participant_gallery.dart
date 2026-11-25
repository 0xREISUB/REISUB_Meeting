import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:v_meeting/meeting/meeting_member.dart';
import 'package:v_meeting/meeting/widgets/participant_tile.dart';

/// One gallery page. All tiles have the same 16:9 size, like a computer
/// screen, instead of an even split of the screen, and are laid out in the
/// column count that makes them largest. Videos fill their tile.
class ParticipantGalleryPage extends StatelessWidget {
  final List<MemberEntry> members;
  final int columns;

  const ParticipantGalleryPage({
    super.key,
    required this.members,
    required this.columns,
  });

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
