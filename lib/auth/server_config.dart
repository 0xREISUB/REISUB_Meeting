import 'package:shared_preferences/shared_preferences.dart';

class ServerConfig {
  static const defaultPort = 8080;
  static const _serverUrlKey = 'server_url';
  static const _authTokenKey = 'auth_token';

  static String normalizeUrl(String value) {
    var url = value.trim();
    if (url.isEmpty) {
      return url;
    }
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) {
      url = 'http://$url';
    }
    return url.replaceFirst(RegExp(r'/+$'), '');
  }

  static Uri? parseUrl(String value) {
    final uri = Uri.tryParse(normalizeUrl(value));
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }

  static String? buildUrl({required String address, required String port}) {
    final portNumber = int.tryParse(port.trim());
    if (portNumber == null || portNumber < 1 || portNumber > 65535) return null;
    final uri = parseUrl(address);
    if (uri == null) return null;
    return Uri(scheme: uri.scheme, host: uri.host, port: portNumber).toString();
  }

  static String editableHost(Uri uri) =>
      uri.scheme == 'https' ? 'https://${uri.host}' : uri.host;

  static Future<void> saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_serverUrlKey, normalizeUrl(url))) {
      throw StateError('Sunucu adresi kaydedilemedi.');
    }
  }

  static Future<String?> readUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_serverUrlKey);
    if (url == null || url.trim().isEmpty) {
      return null;
    }
    return normalizeUrl(url);
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, token);
  }

  static Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_authTokenKey);
    if (token == null || token.trim().isEmpty) {
      return null;
    }
    return token;
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
  }
}
