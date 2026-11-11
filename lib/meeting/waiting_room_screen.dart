import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/l10n/localized_error.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/meeting/meeting_screen.dart';

/// Shown while someone waits to be let into a meeting with a waiting room.
/// It asks the server every [pollInterval]; once let in it opens the
/// meeting, and once turned away it returns with a message.
class WaitingRoomScreen extends ConsumerStatefulWidget {
  const WaitingRoomScreen({
    super.key,
    required this.roomId,
    required this.requestId,
    this.pollInterval = const Duration(seconds: 2),
  });

  final String roomId;
  final String requestId;
  final Duration pollInterval;

  @override
  ConsumerState<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends ConsumerState<WaitingRoomScreen> {
  Timer? _timer;
  bool _checking = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.pollInterval, (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking || _done) return;
    _checking = true;
    try {
      final update = await ref
          .read(meetingApiProvider)
          .waitingStatus(widget.roomId, widget.requestId);
      if (!mounted || _done) return;
      switch (update.status) {
        case WaitingStatus.waiting:
          break;
        case WaitingStatus.admitted:
          _finish();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MeetingScreen(credentials: update.credentials),
            ),
          );
        case WaitingStatus.rejected:
          _leave(AppLocalizations.of(context)!.admissionRejected);
      }
    } on MeetingApiException catch (error) {
      // An unreachable server is tried again; any other answer means the
      // request is gone, because the room ended or it expired.
      if (mounted &&
          !_done &&
          error.code != AppError.meetingServerUnavailable) {
        _leave(AppLocalizations.of(context)!.waitingRequestEnded);
      }
    } catch (_) {
      // A dropped connection: try again on the next tick.
    } finally {
      _checking = false;
    }
  }

  void _finish() {
    _done = true;
    _timer?.cancel();
  }

  void _leave(String message) {
    _finish();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _cancel() async {
    if (_done) return;
    _finish();
    // Leave at once; the server forgets the request in the background.
    unawaited(
      ref
          .read(meetingApiProvider)
          .cancelWaiting(widget.roomId, widget.requestId)
          .catchError((Object _) {}),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_cancel());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121214),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox.square(
                      dimension: 72,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Color(0xFFB69BFF),
                            ),
                          ),
                          Icon(
                            Icons.hourglass_top_rounded,
                            size: 30,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      l10n.waitingForAdmission,
                      key: const ValueKey('waiting-room-title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.waitingForAdmissionHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.roomId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    OutlinedButton(
                      key: const ValueKey('waiting-room-cancel'),
                      onPressed: _cancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                      ),
                      child: Text(l10n.cancel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
