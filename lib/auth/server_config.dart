import 'package:v_meeting/l10n/localized_error.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ServerConfig {
  static const defaultPort = 8080;
  static const _serverUrlKey = 'server_url';
  static const _authTokenKey = 'auth_token';
  static const _secureStorage = FlutterSecureStorage();

  static String normalizeUrl(String value) {
    var url = value.trim();
    if (url.isEmpty) {
      return url;
    }
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) {
      final host = Uri.tryParse('http://$url')?.host ?? '';
      url = '${_isLocalHost(host) ? 'http' : 'https'}://$url';
    }
    return url.replaceFirst(RegExp(r'/+$'), '');
  }

  static Uri? parseUrl(String value) {
    final uri = Uri.tryParse(normalizeUrl(value));
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        (uri.scheme == 'http' && !_isLocalHost(uri.host)) ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }

  static bool _isLocalHost(String host) {
    final value = host.toLowerCase();
    if (value == 'localhost' ||
        value.endsWith('.localhost') ||
        value.endsWith('.local') ||
        value == '::1' ||
        value == '[::1]' ||
        (value.contains(':') &&
            (value.startsWith('fc') ||
                value.startsWith('fd') ||
                RegExp(r'^fe[89ab]').hasMatch(value)))) {
      return true;
    }
    final octets = value.split('.').map(int.tryParse).toList();
    if (octets.length != 4 ||
        octets.any((part) => part == null || part < 0 || part > 255)) {
      return false;
    }
    final first = octets[0]!;
    final second = octets[1]!;
    return first == 10 ||
        first == 127 ||
        (first == 169 && second == 254) ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168);
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
      throw const AppException.localized(AppError.serverSettingsSaveFailed);
    }
  }

  static Future<String?> readUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_serverUrlKey);
    if (url == null || url.trim().isEmpty) {
      return null;
    }
    final normalized = normalizeUrl(url);
    return parseUrl(normalized) == null ? null : normalized;
  }

  static Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _authTokenKey, value: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
  }

  static Future<String?> readToken() async {
    final secureToken = await _secureStorage.read(key: _authTokenKey);
    final prefs = await SharedPreferences.getInstance();
    if (secureToken != null && secureToken.trim().isNotEmpty) {
      await prefs.remove(_authTokenKey);
      return secureToken;
    }
    final legacyToken = prefs.getString(_authTokenKey);
    if (legacyToken == null || legacyToken.trim().isEmpty) return null;
    await _secureStorage.write(key: _authTokenKey, value: legacyToken);
    await prefs.remove(_authTokenKey);
    return legacyToken;
  }

  static Future<void> clearToken() async {
    try {
      await _secureStorage.delete(key: _authTokenKey);
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authTokenKey);
    }
  }
}
