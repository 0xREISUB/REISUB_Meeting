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

class MeetingChatMessage {
  final int id;
  final String roomId;
  final String sender;
  final String content;
  final DateTime createdAt;
  final bool isMine;

  const MeetingChatMessage({
    required this.id,
    required this.roomId,
    required this.sender,
    required this.content,
    required this.createdAt,
    required this.isMine,
  });

  factory MeetingChatMessage.fromJson(Map<String, dynamic> json) {
    return MeetingChatMessage(
      id: json['id'] as int,
      roomId: json['room_id'] as String,
      sender: json['sender'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isMine: json['is_mine'] as bool? ?? false,
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

  Future<List<MeetingChatMessage>> getRoomMessages(String roomId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '${await _authorizedUrl()}/rooms/$roomId/messages',
        options: await _authorizedOptions(),
      );
      return (response.data ?? const [])
          .map((item) => MeetingChatMessage.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw MeetingApiException(_errorMessage(error));
    } on TypeError {
      throw const MeetingApiException('Sunucudan geçersiz mesaj verisi alındı');
    } on FormatException {
      throw const MeetingApiException('Sunucudan geçersiz mesaj verisi alındı');
    }
  }

  Future<MeetingChatMessage> sendRoomMessage(String roomId, String content) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${await _authorizedUrl()}/rooms/$roomId/messages',
        data: {'content': content},
        options: await _authorizedOptions(),
      );
      final responseData = response.data;
      if (responseData == null) {
        throw const MeetingApiException('Sunucudan geçersiz yanıt alındı');
      }
      return MeetingChatMessage.fromJson(responseData);
    } on DioException catch (error) {
      throw MeetingApiException(_errorMessage(error));
    } on TypeError {
      throw const MeetingApiException('Sunucudan geçersiz mesaj verisi alındı');
    } on FormatException {
      throw const MeetingApiException('Sunucudan geçersiz mesaj verisi alındı');
    }
  }

  Future<String> _authorizedUrl() async {
    final serverUrl = await ServerConfig.readUrl();
    final authToken = await ServerConfig.readToken();
    if (serverUrl == null || authToken == null) {
      throw const MeetingApiException('Oturum veya sunucu ayarı bulunamadı');
    }
    return serverUrl;
  }

  Future<Options> _authorizedOptions() async {
    final authToken = await ServerConfig.readToken();
    if (authToken == null) {
      throw const MeetingApiException('Oturum veya sunucu ayarı bulunamadı');
    }
    return Options(headers: {'Authorization': 'Bearer $authToken'});
  }

  String _errorMessage(DioException error) {
    final responseData = error.response?.data;
    final message = responseData is Map<String, dynamic>
        ? responseData['error'] as String?
        : null;
    return message ?? 'Toplantı sunucusuna bağlanılamadı';
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