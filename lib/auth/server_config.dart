import 'package:shared_preferences/shared_preferences.dart';

class ServerConfig {
  static const _serverUrlKey = 'server_url';

  static String normalizeUrl(String value) {
    var url = value.trim();
    if (url.isEmpty) {
      return url;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    return url.replaceFirst(RegExp(r'/+$'), '');
  }

  static Future<void> saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, normalizeUrl(url));
  }

  static Future<String?> readUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_serverUrlKey);
    if (url == null || url.trim().isEmpty) {
      return null;
    }
    return normalizeUrl(url);
  }
}