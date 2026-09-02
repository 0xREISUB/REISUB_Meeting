import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

class MeetingScreen extends StatefulWidget {
  /// Toplam katılımcı (üye) sayısı. Bu değer kadar kutu oluşturulur ve
  /// sağ kaydırma (sayfa) sayısı da bu değere göre hesaplanır.
  final int totalMembers;

  const MeetingScreen({super.key, this.totalMembers = 19});

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  bool _isMicEnabled = true;
  bool _isCameraEnabled = true;
  bool _showControls =
      true; // Ekrana tıklayınca kontrolleri gizleyip göstermek için

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _openChatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors
          .transparent, // Arka planı şeffaf yapıp kendi container'ımızı kullanıyoruz
      builder: (context) {
        // Klavyenin yüksekliğini dinleyip ekranı ona göre itmek için Padding
        final l10n = AppLocalizations.of(context)!;
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
                Text(
                  l10n.chatTitle,
                  style: const TextStyle(
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
                    children: [
                      _ChatBubble(
                        message: l10n.chatMessage1,
                        isMe: true,
                      ),
                      const SizedBox(height: 12),
                      _ChatBubble(
                        message: l10n.chatMessage2,
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
                              hintText: l10n.messageHint,
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
                            icon: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
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

  void _openMembersScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _MembersScreen(totalMembers: widget.totalMembers),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const bg = Color(0xFF000000); // Gerçek siyah arka plan
    const surface = Color(0xFF1C1C1E); // Koyu gri yüzeyler
    final isDesktop =
        MediaQuery.of(context).size.width > 800; // Basit responsive kontrolü

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
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Color(0xFF2C2C2E),
                                    child: Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Colors.white54,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    l10n.mainVideoLabel,
                                    style: const TextStyle(
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.mic_off,
                                      size: 14,
                                      color: Colors.redAccent,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      l10n.speakerLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
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
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
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
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ControlButton(
                            icon: _isMicEnabled
                                ? Icons.mic_rounded
                                : Icons.mic_off_rounded,
                            isActive: _isMicEnabled,
                            onTap: () =>
                                setState(() => _isMicEnabled = !_isMicEnabled),
                          ),
                          const SizedBox(width: 16),
                          _ControlButton(
                            icon: _isCameraEnabled
                                ? Icons.videocam_rounded
                                : Icons.videocam_off_rounded,
                            isActive: _isCameraEnabled,
                            onTap: () => setState(
                              () => _isCameraEnabled = !_isCameraEnabled,
                            ),
                          ),
                          const SizedBox(width: 16),
                          _ControlButton(
                            icon: Icons.people_rounded,
                            isActive: true,
                            onTap: _openMembersScreen,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: const Icon(
                                Icons.call_end_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
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
    final l10n = AppLocalizations.of(context)!;
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
                color: Colors.white.withValues(alpha: 0.2),
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
                  l10n.userName(index + 1),
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

// ============ ÜYELER EKRANI ============
// Üyelerin kameralarını 4 sütunlu, sayfa sayfa (her sayfada 12 kişi) bir gridde gösterir.
// Videolar yatay format olduğundan kutular 16:10 yatay oranındadır.
// Sağ tarafta önceki/sonraki sayfa geçiş butonları bulunur.
class _MembersScreen extends StatefulWidget {
  final int totalMembers;

  const _MembersScreen({required this.totalMembers});

  @override
  State<_MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<_MembersScreen> {
  static const int _perPage = 12; // Her sayfada 12 üye
  static const int _columns = 4; // 4 sütun

  // Çalışma anında değiştirilebilen toplam üye sayısı.
  late int _totalMembers = widget.totalMembers;

  late int _currentPage = 0;

  // Toplam sayfa sayısı üye sayısına göre her zaman yeniden hesaplanır.
  int get _totalPages => (_totalMembers / _perPage).ceil();

  void _goToPage(int page) {
    if (page < 0 || page >= _totalPages) return;
    setState(() => _currentPage = page);
  }

  // Üye sayısını değiştirir; kutu sayısı ve sayfa sayısı anında güncellenir.
  void _setTotalMembers(int value) {
    setState(() {
      _totalMembers = value.clamp(1, 100);
      // Mevcut sayfa, yeni sayfa sayısını aşarsa son sayfaya al.
      if (_currentPage >= _totalPages) {
        _currentPage = (_totalPages - 1).clamp(0, _totalPages - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bg = const Color(0xFF000000);

    final start = _currentPage * _perPage;
    final end = (start + _perPage).clamp(0, _totalMembers);

    final members = List.generate(
      _totalMembers,
      (i) => i,
    ).sublist(start, end);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BAŞLIK ÇUBUĞU
              Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.membersTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          l10n.membersHeader(
                            _totalMembers,
                            _currentPage + 1,
                            _totalPages,
                          ),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ÜYE SAYISI AYARLAYICI (Slayt ile anında değiştir)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people_alt_rounded,
                      color: Colors.white38,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.memberCountLabel(_totalMembers),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: _totalMembers.toDouble(),
                        min: 1,
                        max: 100,
                        divisions: 99,
                        activeColor: const Color(0xFF8A5CFF),
                        inactiveColor: const Color(0xFF2C2C2E),
                        onChanged: (value) =>
                            _setTotalMembers(value.round()),
                      ),
                    ),
                    Text(
                      l10n.screenCountLabel(_totalPages),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // GRİD + SAĞ KAYDIRMA BUTONLARI
              Expanded(
                child: Row(
                  children: [
                    // 4 SÜTUN x 3 SATIR GRID (yatay video formatı)
                    // Videolar yatay (16:9 gibi) olduğundan kutular geniş ve yassı tutulur.
                    // Gerekirse grid kendi içinde kaydırılır, böylece taşma olmaz.
                    Expanded(
                      flex: 1,
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _columns,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 10,
                              childAspectRatio: 16 / 10, // yatay video kutusu
                            ),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          return _MemberTile(
                            memberNumber: members[index] + 1,
                          );
                        },
                      ),
                    ),

                    const SizedBox(width: 8),

                    // SAĞ KAYDIRMA DÜŞEY BUTONLAR
                    // Aşağı/ yukarı sayfa geçiş okları; arada kaç ekran (sayfa) olduğunu
                    // gösteren noktalar bulunur. Sayfa sayısı üye sayısına göre artar.
                    SizedBox(
                      width: 76,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _RoundIconButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: _currentPage > 0
                                ? () => _goToPage(_currentPage - 1)
                                : null,
                          ),
                          const SizedBox(height: 16),
                          // Sayfa noktaları (çok fazlaysa kaydırılabilir)
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0; i < _totalPages; i++)
                                    _PageDot(active: i == _currentPage),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _RoundIconButton(
                            icon: Icons.arrow_forward_ios_rounded,
                            onTap: _currentPage < _totalPages - 1
                                ? () => _goToPage(_currentPage + 1)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ÜYE KAMERA KUTUSU (Placeholder)
class _MemberTile extends StatelessWidget {
  final int memberNumber;

  const _MemberTile({required this.memberNumber});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isFirst = memberNumber == 1; // İlk üye "öne çıkan" gibi davranır
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFirst ? const Color(0xFF8A5CFF) : Colors.white12,
          width: isFirst ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isFirst
                ? const Color(0xFF8A5CFF).withValues(alpha: 0.15)
                : Colors.transparent,
            blurRadius: 12,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Kamera kapalı placeholder görünümü
          const Center(
            child: Icon(Icons.person, size: 44, color: Colors.white24),
          ),
          // Sol üstte kullanıcı sıra numarası balonu
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isFirst
                    ? const Color(0xFF8A5CFF)
                    : const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                memberNumber.toString().padLeft(2, '0'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          // Sağ üstte kamera durum ikonu (placeholder olarak live)
          const Positioned(top: 8, right: 8, child: _LiveBadge()),
          // Alt isim etiketi
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                l10n.userName(memberNumber),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// CANLI (LIVE) ROZETİ
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 6, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            l10n.liveBadge,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// SAYFA NOKTA GÖSTERGESİ (Sağ kaydırmada kaç ekran olduğunu gösterir)
class _PageDot extends StatelessWidget {
  final bool active;

  const _PageDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? const Color(0xFF8A5CFF) : const Color(0xFF3A3A3C),
      ),
    );
  }
}

// YUVarlak İKON BUTONU (Başlık ve kaydırma okları için)
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _RoundIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF2C2C2E) : const Color(0xFF1C1C1E),
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? Colors.white12 : Colors.white10,
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : Colors.white24,
          size: 22,
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
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}

// SOHBET BALONCUĞU
class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;

  const _ChatBubble({required this.message, required this.isMe});

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
