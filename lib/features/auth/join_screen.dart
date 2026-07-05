import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'home_screen.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _roomFocusNode = FocusNode();

  bool _isNameError = false;
  bool _isRoomError = false;

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

  void _joinMeeting() {
    final name = _nameController.text.trim();
    final room = _roomController.text.trim();

    setState(() {
      _isNameError = name.isEmpty;
      _isRoomError = room.length < 11;
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

    print('Katılınıyor... Ad: $name, Oda: $room');
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
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.video_camera_front,
                      size: 80,
                      color: Colors.deepPurpleAccent,
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
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) {
                        FocusScope.of(context).requestFocus(_roomFocusNode);
                      },
                      onChanged: (val) {
                        if (_isNameError && val.trim().isNotEmpty) {
                          setState(() => _isNameError = false);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: l10n.yourName, // Dil paketinden
                        errorText: _isNameError ? l10n.nameError : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                        if (_isRoomError && val.length == 11) {
                          setState(() => _isRoomError = false);
                        }
                      },
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4.0,
                        color: _isRoomError
                            ? Colors.red
                            : Colors.deepPurpleAccent,
                      ),
                      maxLength: 11,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                        _RoomNumberFormatter(),
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.roomId, // Dil paketinden
                        counterText: "",
                        errorText: _isRoomError ? l10n.roomError : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.meeting_room),
                      ),
                    ),
                    const SizedBox(height: 32),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.deepPurpleAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _joinMeeting,
                      child: Text(
                        l10n.joinMeeting, // Dil paketinden
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
