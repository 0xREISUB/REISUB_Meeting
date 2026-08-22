import 'package:flutter/material.dart';

class MeetingScreen extends StatefulWidget {
  const MeetingScreen({super.key});

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  bool _isMicEnabled = true;
  bool _isCameraEnabled = true;
  bool _showControls = true; // Ekrana tıklayınca kontrolleri gizleyip göstermek için

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _openChatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Arka planı şeffaf yapıp kendi container'ımızı kullanıyoruz
      builder: (context) {
        // Klavyenin yüksekliğini dinleyip ekranı ona göre itmek için Padding
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.65,
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Çekme (Drag) çubuğu
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sohbet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Colors.white12),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      _ChatBubble(
                        message: 'Selam, sesim geliyor mu?',
                        isMe: true,
                      ),
                      SizedBox(height: 12),
                      _ChatBubble(
                        message: 'Evet, net geliyor. Görüntü de gayet iyi.',
                        isMe: false,
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Mesaj yaz...',
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: const Color(0xFF2C2C2E),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF8A5CFF),
                          child: IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleLeaveOrEndMeeting() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF000000); // Gerçek siyah arka plan
    const surface = Color(0xFF1C1C1E); // Koyu gri yüzeyler
    final isDesktop = MediaQuery.of(context).size.width > 800; // Basit responsive kontrolü

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: GestureDetector(
          onTap: _toggleControls, // Boşluğa tıklayınca UI kaybolur/gelir
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // ANA İÇERİK (Video Alanları)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // SOL: ANA VIDEO
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white12, width: 1),
                        ),
                        child: Stack(
                          children: [
                            const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Color(0xFF2C2C2E),
                                    child: Icon(Icons.person, size: 40, color: Colors.white54),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Ana Video Akışı',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Sol alt isim etiketi
                            Positioned(
                              left: 16,
                              bottom: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.mic_off, size: 14, color: Colors.redAccent),
                                    SizedBox(width: 6),
                                    Text('Konuşmacı', style: TextStyle(color: Colors.white, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (isDesktop) const SizedBox(width: 16),

                    // SAĞ: YAN VİDEOLAR (Sadece ekrana sığıyorsa göster)
                    if (isDesktop)
                      SizedBox(
                        width: 260,
                        child: ListView.separated(
                          itemCount: 5,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _ParticipantTile(index: index);
                          },
                        ),
                      ),
                  ],
                ),
              ),





              // ALT KONTROL PANELİ (Yüzen Kapsül)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                bottom: _showControls ? 32 : -100, // Gizlendiğinde aşağı kayar
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ControlButton(
                          icon: _isMicEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                          isActive: _isMicEnabled,
                          onTap: () => setState(() => _isMicEnabled = !_isMicEnabled),
                        ),
                        const SizedBox(width: 16),
                        _ControlButton(
                          icon: _isCameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                          isActive: _isCameraEnabled,
                          onTap: () => setState(() => _isCameraEnabled = !_isCameraEnabled),
                        ),
                        const SizedBox(width: 16),
                        _ControlButton(
                          icon: Icons.people_rounded,
                          isActive: true,
                          onTap: () {
                            // Katılımcılar listesi açılacak
                          },
                        ),


                        const SizedBox(width: 16),
                        _ControlButton(
                          icon: Icons.chat_bubble_rounded,
                          isActive: true, // Sohbet butonu hep aktif renkte
                          onTap: _openChatSheet,
                        ),
                        const SizedBox(width: 16),
                        // ÇIKIŞ BUTONU (Kırmızı ve daha geniş)
                        InkWell(
                          onTap: _handleLeaveOrEndMeeting,
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                      ],
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

// YAN VİDEO KUTULARI
class _ParticipantTile extends StatelessWidget {
  final int index;

  const _ParticipantTile({required this.index});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                Icons.person,
                size: 32,
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Kullanıcı ${index + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// KONTROL BUTONLARI (Yuvarlak)
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Kapalıysa Kırmızı, Açıksa Koyu Gri
    final bgColor = isActive ? const Color(0xFF3A3A3C) : Colors.redAccent;
    final iconColor = Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}

// SOHBET BALONCUĞU
class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;

  const _ChatBubble({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF8A5CFF) : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
    );
  }
}