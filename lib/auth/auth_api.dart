import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/app/http.dart';
import 'package:v_meeting/auth/auth_error.dart';
import 'package:v_meeting/auth/server_config.dart';
import 'package:v_meeting/auth/server_policy.dart';

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(dioProvider)),
);

/// Thrown when signing in or registering fails. [serverMessage] is the
/// server's own explanation, shown verbatim; otherwise the UI shows a generic
/// connection error.
class AuthException implements Exception {
  const AuthException([this.serverMessage]);
  final String? serverMessage;
}

/// Thrown when an address does not answer like a REISUB Meeting server.
class ServerCheckException implements Exception {
  const ServerCheckException();
}

class AuthApi {
  const AuthApi(this._dio);

  final Dio _dio;

  /// Confirms that [serverUrl] is a running REISUB Meeting server.
  ///
  /// Throws [ServerCheckException] for network errors and unexpected answers.
  Future<void> checkServer(String serverUrl) async {
    try {
      final response = await _dio.get<Object?>('$serverUrl/ping');
      final data = response.data;
      if (response.statusCode != 200 ||
          data is! Map ||
          data['message'] != 'pong' ||
          data['status'] != 'active') {
        throw const ServerCheckException();
      }
    } on DioException {
      throw const ServerCheckException();
    }
  }

  /// Reads [serverUrl]'s rules. Servers without the endpoint let guests in.
  Future<ServerPolicy> fetchPolicy(String serverUrl) async {
    try {
      final response = await _dio.get<Object?>('$serverUrl/policy');
      final data = response.data;
      if (data is! Map) throw const ServerCheckException();
      return ServerPolicy.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return ServerPolicy.legacy;
      throw const ServerCheckException();
    } on TypeError {
      throw const ServerCheckException();
    }
  }

  /// Signs in and stores the session token.
  Future<void> login({required String nick, required String password}) async {
    final response = await _post('/login', nick: nick, password: password);
    final data = response.data;
    final token = data is Map ? data['token'] : null;
    if (token is! String || token.isEmpty) throw const AuthException();
    await ServerConfig.saveToken(token);
  }

  Future<void> register({required String nick, required String password}) =>
      _post('/register', nick: nick, password: password);

  Future<Response<Object?>> _post(
    String path, {
    required String nick,
    required String password,
  }) async {
    final serverUrl = await ServerConfig.readUrl();
    if (serverUrl == null) throw const AuthException();
    try {
      return await _dio.post<Object?>(
        '$serverUrl$path',
        data: {'nick': nick, 'password': password},
      );
    } on DioException catch (error) {
      final message = authErrorMessage(error.response?.data, '');
      throw AuthException(message.isEmpty ? null : message);
    }
  }
}
