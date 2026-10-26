String authErrorMessage(Object? responseData, String fallback) {
  if (responseData is Map) {
    final message = responseData['error'];
    if (message is String && message.trim().isNotEmpty) return message;
  }
  return fallback;
}
