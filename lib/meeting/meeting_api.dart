import 'package:dio/dio.dart';
import 'package:v_meeting/auth/server_config.dart';

class RoomCredentials {
  final String roomId;
  final String liveKitUrl;
  final String token;
  final String participant;
  final bool isHost;

  const RoomCredentials({
    required this.roomId,
    required this.liveKitUrl,
    required this.token,
    required this.participant,
    required this.isHost,
  });

  factory RoomCredentials.fromJson(Map<String, dynamic> json) {
    return RoomCredentials(
      roomId: json['room_id'] as String,
      liveKitUrl: json['livekit_url'] as String,
      token: json['token'] as String,
      participant: json['participant'] as String,
      isHost: json['is_host'] as bool? ?? false,
    );
  }
}

class MeetingApi {
  MeetingApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<RoomCredentials> createRoom(String name) async {
    return _requestRoom('/rooms', {'name': name});
  }

  Future<RoomCredentials> joinRoom({
    required String roomId,
    required String name,
  }) async {
    return _requestRoom('/rooms/join', {'room_id': roomId, 'name': name});
  }

  Future<RoomCredentials> _requestRoom(
    String path,
    Map<String, String> data,
  ) async {
    final serverUrl = await ServerConfig.readUrl();
    final authToken = await ServerConfig.readToken();
    if (serverUrl == null || authToken == null) {
      throw const MeetingApiException('Oturum veya sunucu ayarı bulunamadı');
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$serverUrl$path',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
      );
      final responseData = response.data;
      if (responseData == null) {
        throw const MeetingApiException('Sunucudan geçersiz yanıt alındı');
      }
      return RoomCredentials.fromJson(responseData);
    } on DioException catch (error) {
      final responseData = error.response?.data;
      final message = responseData is Map<String, dynamic>
          ? responseData['error'] as String?
          : null;
      throw MeetingApiException(message ?? 'Toplantı sunucusuna bağlanılamadı');
    } on TypeError {
      throw const MeetingApiException('Sunucudan geçersiz oda bilgisi alındı');
    }
  }
}

class MeetingApiException implements Exception {
  final String message;

  const MeetingApiException(this.message);

  @override
  String toString() => message;
}