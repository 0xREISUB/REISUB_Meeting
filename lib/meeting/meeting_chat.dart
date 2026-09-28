import 'dart:async';

import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'widgets/meeting_components.dart';

class MeetingChatController extends ChangeNotifier {
  MeetingChatController({required this.roomId, MeetingApi? api})
    : _api = api ?? MeetingApi();

  final String roomId;
  final MeetingApi _api;
  final List<MeetingChatMessage> messages = [];
  final Set<int> _knownMessageIds = {};
  final Set<int> _unreadMessageIds = {};
  Timer? _refreshTimer;
  bool isLoading = true;
  bool isSending = false;
  bool _isRefreshing = false;
  bool _hasLoaded = false;
  bool _isChatOpen = false;
  bool _isDisposed = false;
  String? error;

  bool get hasUnreadMessages => _unreadMessageIds.isNotEmpty;

  void start() {
    if (_refreshTimer != null) return;
    unawaited(refreshMessages());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => refreshMessages(),
    );
  }

  void setChatOpen(bool isOpen) {
    if (_isDisposed) return;
    _isChatOpen = isOpen;
    if (isOpen && _unreadMessageIds.isNotEmpty) {
      _unreadMessageIds.clear();
      notifyListeners();
    }
    if (isOpen) unawaited(refreshMessages());
  }

  Future<void> refreshMessages() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final latestMessages = await _api.getRoomMessages(roomId);
      if (_isDisposed) return;
      final hadUnreadMessages = hasUnreadMessages;
      final wasLoading = isLoading;
      final previousError = error;
      final messagesChanged =
          latestMessages.length != messages.length ||
          List.generate(
            latestMessages.length < messages.length
                ? latestMessages.length
                : messages.length,
            (index) => latestMessages[index].id == messages[index].id,
          ).any((isSameMessage) => !isSameMessage);
      if (_hasLoaded && !_isChatOpen) {
        for (final message in latestMessages) {
          if (!message.isMine && !_knownMessageIds.contains(message.id)) {
            _unreadMessageIds.add(message.id);
          }
        }
      }
      _knownMessageIds.addAll(latestMessages.map((message) => message.id));
      messages
        ..clear()
        ..addAll(latestMessages);
      isLoading = false;
      error = null;
      _hasLoaded = true;
      if (messagesChanged ||
          hadUnreadMessages != hasUnreadMessages ||
          wasLoading != isLoading ||
          previousError != error) {
        notifyListeners();
      }
    } catch (exception) {
      if (_isDisposed) return;
      error = exception.toString();
      isLoading = false;
      notifyListeners();
    } finally {
      _isRefreshing = false;
    }
  }

  Future<bool> sendMessage(String content) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty || isSending) return false;

    isSending = true;
    error = null;
    notifyListeners();
    try {
      final message = await _api.sendRoomMessage(roomId, trimmedContent);
      if (_isDisposed) return false;
      _knownMessageIds.add(message.id);
      messages
        ..removeWhere((existing) => existing.id == message.id)
        ..add(message)
        ..sort((left, right) => left.id.compareTo(right.id));
      isSending = false;
      notifyListeners();
      return true;
    } catch (exception) {
      if (_isDisposed) return false;
      error = exception.toString();
      isSending = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _refreshTimer?.cancel();
    super.dispose();
  }
}

class MeetingChatSheet extends StatefulWidget {
  const MeetingChatSheet({super.key, required this.controller});

  final MeetingChatController controller;

  @override
  State<MeetingChatSheet> createState() => _MeetingChatSheetState();
}

class _MeetingChatSheetState extends State<MeetingChatSheet> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _onControllerChanged() {
    final messageCount = widget.controller.messages.length;
    final hasNewMessages = messageCount > _lastMessageCount;
    _lastMessageCount = messageCount;
    if (mounted) setState(() {});
    if (hasNewMessages) _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final sent = await widget.controller.sendMessage(_messageController.text);
    if (sent && mounted) {
      _messageController.clear();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = widget.controller;
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
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24, color: Colors.white12),
            Expanded(child: _buildMessageList(controller)),
            if (controller.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  controller.error!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
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
                        controller: _messageController,
                        enabled: !controller.isSending,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: l10n.messageHint,
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF2C2C2E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Gönder',
                      onPressed: controller.isSending ? null : _sendMessage,
                      icon: controller.isSending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(MeetingChatController controller) {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.messages.isEmpty) {
      return const Center(
        child: Text('Henüz mesaj yok', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: controller.messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final message = controller.messages[index];
        return Column(
          crossAxisAlignment: message.isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!message.isMine)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  message.sender,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ChatBubble(message: message.content, isMe: message.isMine),
          ],
        );
      },
    );
  }
}
