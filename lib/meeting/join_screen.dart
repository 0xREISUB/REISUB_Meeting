import 'package:v_meeting/l10n/localized_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/app/invite.dart';
import 'package:v_meeting/app/theme.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/home/home_screen.dart';
import 'package:v_meeting/auth/account.dart';
import 'package:v_meeting/auth/server_config.dart';
import 'package:v_meeting/auth/login_screen.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/meeting/meeting_screen.dart';

class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, this.initialRoomId, this.inviteServerUrl});

  /// Prefilled room code, e.g. from an invite link.
  final String? initialRoomId;

  /// Server named by the invite; the user confirms switching to it.
  final String? inviteServerUrl;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final TextEditingController _nameController = TextEditingController();
  late final TextEditingController _roomController = TextEditingController(
    text: widget.initialRoomId,
  );

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _roomFocusNode = FocusNode();

  bool _isNameError = false;
  bool _isRoomError = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialRoomId != null) {
      // The invite has been used; providers can't change during a build.
      Future.microtask(() {
        if (mounted) ref.read(pendingInviteProvider.notifier).clear();
      });
    }
    final inviteServer = widget.inviteServerUrl;
    if (inviteServer != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _offerInviteServer(inviteServer),
      );
    }
  }

  /// A link must never move the user to another server silently: a forged
  /// invite could otherwise collect their password on a fake server.
  Future<void> _offerInviteServer(String inviteServer) async {
    final current = await ServerConfig.readUrl();
    if (!mounted || ServerConfig.sameServer(current, inviteServer)) return;
    if (current == null) {
      // No server yet, so there is nothing to replace.
      await ServerConfig.saveUrl(inviteServer);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final host = Uri.parse(inviteServer).host;
    final switchServer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.inviteServerTitle),
        content: Text(l10n.inviteServerBody(host)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('switch-invite-server'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.switchServer),
          ),
        ],
      ),
    );
    if (switchServer != true || !mounted) return;
    await ServerConfig.saveUrl(inviteServer);
    await ServerConfig.clearSessions();
    ref.read(signedInProvider.notifier).refresh();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    _nameFocusNode.dispose();
    _roomFocusNode.dispose();
    super.dispose();
  }

  void _returnToMainMenu() {
    if (Navigator.canPop(context)) {
      // Eğer Ana Menü üzerinden geldiysek, geldiğimiz yoldan geri dön
      // (Bu sayede şık bir 'geri çekilme' animasyonu çalışır)
      Navigator.pop(context);
    } else {
      // Eğer bir şekilde (link vs.) direkt bu ekran açıldıysa ve geri dönülecek
      // bir geçmiş yoksa, tüm ekranı kapatıp zorla Ana Menüyü aç!
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  Future<void> _joinMeeting() async {
    final name = _nameController.text.trim();
    final room = _roomController.text.trim();

    setState(() {
      _isNameError = name.isEmpty;
      _isRoomError = !roomCodePattern.hasMatch(room);
    });

    if (_isNameError || _isRoomError) {
      ScaffoldMessenger.of(context).clearSnackBars();

      // Dil dosyasından hata mesajını alıyoruz
      final l10n = AppLocalizations.of(context)!;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // Text artık dinamik olduğu için Row'un başındaki const kalktı
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.emptyErrorMsg, // Dil paketinden gelen metin
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 120,
            left: 20,
            right: 20,
          ),
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final credentials = await ref
          .read(meetingApiProvider)
          .joinRoom(roomId: room, name: name);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MeetingScreen(credentials: credentials),
        ),
      );
    } on MeetingApiException catch (error) {
      if (mounted) {
        if (error.sessionExpired) {
          ref.read(signedInProvider.notifier).refresh();
        }
        if (error.loginRequired) {
          // Servers without guest sessions still need an account.
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizeError(error, AppLocalizations.of(context)!)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Her build metodunda dil objesini alıp 'l10n' değişkenine atamak
    // kodu sürekli AppLocalizations.of(context) yazmaktan kurtarır.
    final l10n = AppLocalizations.of(context)!;

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (intent) {
              _returnToMainMenu();
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: l10n.returnMainMenu, // Dil paketinden
              onPressed: _returnToMainMenu,
            ),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 44).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.video_camera_front,
                            size: 80,
                            color: brandColor,
                          ),
                          const SizedBox(height: 32),
                          Text(
                            l10n.joinMeeting, // Dil paketinden
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),

                          TextField(
                            controller: _nameController,
                            focusNode: _nameFocusNode,
                            // With an invite only the name is missing.
                            autofocus: widget.initialRoomId != null,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) {
                              FocusScope.of(
                                context,
                              ).requestFocus(_roomFocusNode);
                            },
                            onChanged: (val) {
                              if (_isNameError && val.trim().isNotEmpty) {
                                setState(() => _isNameError = false);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: l10n.yourName, // Dil paketinden
                              errorText: _isNameError ? l10n.nameError : null,
                              prefixIcon: const Icon(Icons.person),
                            ),
                          ),
                          const SizedBox(height: 20),

                          TextField(
                            controller: _roomController,
                            focusNode: _roomFocusNode,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _joinMeeting(),
                            onChanged: (val) {
                              if (_isRoomError &&
                                  roomCodePattern.hasMatch(val)) {
                                setState(() => _isRoomError = false);
                              }
                            },
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4.0,
                              color: _isRoomError ? Colors.red : brandColor,
                            ),
                            maxLength: 11,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9\-]'),
                              ),
                              _RoomNumberFormatter(),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.roomId, // Dil paketinden
                              counterText: "",
                              errorText: _isRoomError ? l10n.roomError : null,
                              prefixIcon: const Icon(Icons.meeting_room),
                            ),
                          ),
                          const SizedBox(height: 32),

                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _joinMeeting,
                            child: Text(
                              _isSubmitting
                                  ? l10n.connecting
                                  : l10n.joinMeeting,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (text.length > 9) {
      text = text.substring(0, 9);
    }

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 3 == 0 && nonZeroIndex != text.length) {
        buffer.write('-');
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
