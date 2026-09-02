import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

// --- KONTROL BUTONLARI ---
class ControlButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const ControlButton({
    super.key, 
    required this.icon, 
    required this.isActive, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    // Kapalıysa Kırmızı, Açıksa Koyu Gri
    final bgColor = isActive ? const Color(0xFF3A3A3C) : Colors.redAccent;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        // HATA BURADAYDI: Şeffaf renk ve sabit ikon yerine, gönderilen ikonu beyaz yapıyoruz
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

// Yuvarlak İkon Butonu (Başlık ve oklar için)
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const RoundIconButton({super.key, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF2C2C2E) : const Color(0xFF1C1C1E),
          shape: BoxShape.circle,
          border: Border.all(color: enabled ? Colors.white12 : Colors.white10),
        ),
        child: Icon(icon, color: enabled ? Colors.white : Colors.white24, size: 22),
      ),
    );
  }
}

// --- SOHBET BİLEŞENLERİ ---
class ChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;

  const ChatBubble({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
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
        child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 15)),
      ),
    );
  }
}

// --- VİDEO VE ÜYE KUTULARI ---
class ParticipantTile extends StatelessWidget {
  final int index;
  const ParticipantTile({super.key, required this.index});

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
          border: Border.all(color: Colors.white12),
        ),
        child: Stack(
          children: [
            Center(child: Icon(Icons.person, size: 32, color: Colors.white.withValues(alpha: 0.2))),
            Positioned(
              left: 8, bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                child: Text(l10n.userName(index + 1), style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MemberTile extends StatelessWidget {
  final int memberNumber;
  const MemberTile({super.key, required this.memberNumber});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isFirst = memberNumber == 1;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isFirst ? const Color(0xFF8A5CFF) : Colors.white12, width: isFirst ? 2 : 1),
        boxShadow: [
          if (isFirst) BoxShadow(color: const Color(0xFF8A5CFF).withValues(alpha: 0.15), blurRadius: 12)
        ],
      ),
      child: Stack(
        children: [
          const Center(child: Icon(Icons.person, size: 44, color: Colors.white24)),
          Positioned(
            top: 8, left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isFirst ? const Color(0xFF8A5CFF) : const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(memberNumber.toString().padLeft(2, '0'), style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
          const Positioned(top: 8, right: 8, child: LiveBadge()),
          Positioned(
            left: 8, right: 8, bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
              child: Text(l10n.userName(memberNumber), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 6, color: Colors.white),
          const SizedBox(width: 3),
          Text(l10n.liveBadge, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class PageDot extends StatelessWidget {
  final bool active;
  const PageDot({super.key, required this.active});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8, height: 8, margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(shape: BoxShape.circle, color: active ? const Color(0xFF8A5CFF) : const Color(0xFF3A3A3C)),
    );
  }
}