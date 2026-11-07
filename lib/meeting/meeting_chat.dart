import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:v_meeting/meeting/meeting_api.dart';

class MeetingChatController extends ChangeNotifier {
  MeetingChatController({required this.roomId, MeetingApi? api})
    : _api = api ?? MeetingApi();

  final String roomId;
  final MeetingApi _api;
  final List<MeetingChatMessage> messages = [];
  final Set<int> _knownMessageIds = {};
  final Map<int, MeetingChatMessage> _pendingSentMessages = {};
  final Set<int> _unreadMessageIds = {};
  Timer? _refreshTimer;
  bool isLoading = true;
  bool isSending = false;
  bool _isRefreshing = false;
  bool _hasLoaded = false;
  bool _isChatOpen = false;
  bool _isDisposed = false;
  Object? error;

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
      final serverIds = latestMessages.map((message) => message.id).toSet();
      _pendingSentMessages.removeWhere((id, _) => serverIds.contains(id));
      final visibleMessages = [
        ...latestMessages,
        ..._pendingSentMessages.values,
      ]..sort((left, right) => left.id.compareTo(right.id));
      final hadUnreadMessages = hasUnreadMessages;
      final wasLoading = isLoading;
      final previousError = error;
      final messagesChanged =
          visibleMessages.length != messages.length ||
          List.generate(
            visibleMessages.length < messages.length
                ? visibleMessages.length
                : messages.length,
            (index) => visibleMessages[index].id == messages[index].id,
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
        ..addAll(visibleMessages);
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
      error = exception;
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
      _pendingSentMessages[message.id] = message;
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
      error = exception;
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
