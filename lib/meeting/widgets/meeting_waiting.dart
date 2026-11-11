import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/l10n/localized_error.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/meeting/widgets/meeting_participant.dart';

/// Lets a waiting person in or turns them away; throws the server's error.
typedef WaitingAnswer =
    Future<void> Function(WaitingPerson person, {required bool admit});

/// The dock button for the waiting room: people with a small clock, and
/// how many are waiting.
class WaitingRoomButton extends StatelessWidget {
  const WaitingRoomButton({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Tooltip(
      message: count == 0 ? l10n.waitingPeople : l10n.waitingPeopleCount(count),
      child: InkWell(
        key: const ValueKey('waiting-room-button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFF3A3A3C),
            shape: BoxShape.circle,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.people_rounded, color: Colors.white, size: 24),
              // A clock in the top-right corner of the people.
              Positioned(
                top: -5,
                right: -6,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF3A3A3C),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(1),
                  child: const Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: Color(0xFFFFC857),
                  ),
                ),
              ),
              if (count > 0)
                Positioned(
                  bottom: -6,
                  right: -8,
                  child: Container(
                    key: const ValueKey('waiting-room-count'),
                    constraints: const BoxConstraints(minWidth: 17),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: const Color(0xFF3A3A3C)),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The waiting room's people, each with buttons to let them in or turn
/// them away, and one to let everyone in.
class WaitingListSheet extends StatefulWidget {
  const WaitingListSheet({
    super.key,
    required this.waiting,
    required this.onAnswer,
  });

  final List<WaitingPerson> waiting;
  final WaitingAnswer onAnswer;

  @override
  State<WaitingListSheet> createState() => _WaitingListSheetState();
}

class _WaitingListSheetState extends State<WaitingListSheet> {
  final _busy = <String>{};
  Object? _error;

  Future<void> _answer(WaitingPerson person, {required bool admit}) async {
    if (!_busy.add(person.requestId)) return;
    setState(() => _error = null);
    try {
      await widget.onAnswer(person, admit: admit);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy.remove(person.requestId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final waiting = widget.waiting;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  color: Color(0xFFFFC857),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.waitingPeopleCount(waiting.length),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (waiting.length > 1)
                  TextButton(
                    key: const ValueKey('waiting-admit-all'),
                    onPressed: () {
                      for (final person in waiting) {
                        _answer(person, admit: true);
                      }
                    },
                    child: Text(l10n.admitAll),
                  ),
                const CloseButton(color: Colors.white70),
              ],
            ),
          ),
          const Divider(height: 24, color: Colors.white12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                localizeError(_error!, l10n),
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          Expanded(
            child: waiting.isEmpty
                ? Center(
                    child: Text(
                      l10n.noOneWaiting,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: waiting.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Colors.white12),
                    itemBuilder: (context, index) {
                      final person = waiting[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            MemberAvatar(
                              name: person.name,
                              seed: person.requestId,
                              size: 36,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                person.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (_busy.contains(person.requestId))
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            else
                              _AnswerButtons(
                                keyPrefix: person.requestId,
                                onAdmit: () => _answer(person, admit: true),
                                onReject: () => _answer(person, admit: false),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// A notice that drops in from the top when someone starts waiting, to
/// let them in or turn them away at once.
class ArrivalNotice extends StatelessWidget {
  const ArrivalNotice({
    super.key,
    required this.person,
    required this.onAdmit,
    required this.onReject,
    required this.onDismiss,
  });

  final WaitingPerson person;
  final VoidCallback onAdmit;
  final VoidCallback onReject;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dismissible(
      key: ValueKey('arrival-${person.requestId}'),
      direction: DismissDirection.up,
      onDismissed: (_) => onDismiss(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xF22C2C2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MemberAvatar(name: person.name, seed: person.requestId, size: 34),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  l10n.arrivalTitle(person.name),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _AnswerButtons(
                keyPrefix: 'arrival-${person.requestId}',
                onAdmit: onAdmit,
                onReject: onReject,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round ✓ to let someone in and a round ✗ to turn them away.
class _AnswerButtons extends StatelessWidget {
  const _AnswerButtons({
    required this.keyPrefix,
    required this.onAdmit,
    required this.onReject,
  });

  final String keyPrefix;
  final VoidCallback onAdmit;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        IconButton.filled(
          key: ValueKey('$keyPrefix-reject'),
          tooltip: l10n.reject,
          onPressed: onReject,
          style: IconButton.styleFrom(
            backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
            foregroundColor: Colors.redAccent,
          ),
          icon: const Icon(Icons.close_rounded),
        ),
        IconButton.filled(
          key: ValueKey('$keyPrefix-admit'),
          tooltip: l10n.admit,
          onPressed: onAdmit,
          style: IconButton.styleFrom(
            backgroundColor: Colors.greenAccent.withValues(alpha: 0.2),
            foregroundColor: Colors.greenAccent,
          ),
          icon: const Icon(Icons.check_rounded),
        ),
      ],
    );
  }
}
