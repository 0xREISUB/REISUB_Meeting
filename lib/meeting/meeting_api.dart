import 'package:v_meeting/l10n/localized_error.dart';
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

class MeetingState {
  final bool allowParticipantScreenShare;
  final String screenShareIdentity;

  const MeetingState({
    this.allowParticipantScreenShare = false,
    this.screenShareIdentity = '',
  });

  factory MeetingState.fromJson(Map<String, dynamic> json) => MeetingState(
    allowParticipantScreenShare:
        json['allow_participant_screen_share'] as bool? ?? false,
    screenShareIdentity: json['screen_share_identity'] as String? ?? '',
  );
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

  Future<MeetingState> getMeetingState(String roomId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${await _authorizedUrl()}/rooms/${Uri.encodeComponent(roomId)}/state',
        options: await _authorizedOptions(),
      );
      return MeetingState.fromJson(response.data!);
    } on DioException catch (error) {
      throw _errorMessage(error);
    }
  }

  Future<MeetingState> updateMeetingSettings(
    String roomId, {
    required bool allowScreenShare,
  }) => _sharingRequest(roomId, 'settings', {
    'allow_participant_screen_share': allowScreenShare,
  });

  Future<MeetingState> startScreenShare(String roomId, String identity) =>
      _sharingRequest(roomId, 'screen-share/start', {'identity': identity});

  Future<MeetingState> stopScreenShare(String roomId, String identity) =>
      _sharingRequest(roomId, 'screen-share/stop', {'identity': identity});

  Future<MeetingState> _sharingRequest(
    String roomId,
    String action,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${await _authorizedUrl()}/rooms/${Uri.encodeComponent(roomId)}/$action',
        data: data,
        options: await _authorizedOptions(),
      );
      return MeetingState.fromJson(response.data!);
    } on DioException catch (error) {
      throw _errorMessage(error);
    }
  }

  Future<void> closeRoom(String roomId) async {
    await _moderationRequest('/rooms/${Uri.encodeComponent(roomId)}/close', {});
  }

  Future<void> setParticipantMicrophone({
    required String roomId,
    required String identity,
    required bool locked,
    bool requestUnmute = false,
  }) async {
    await _moderationRequest(
      '/rooms/${Uri.encodeComponent(roomId)}/participants/'
      '${Uri.encodeComponent(identity)}/microphone',
      {'locked': locked, 'request_unmute': requestUnmute},
    );
  }

  Future<void> _moderationRequest(
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      await _dio.post<dynamic>(
        '${await _authorizedUrl()}$path',
        data: data,
        options: await _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _errorMessage(error);
    }
  }

  Future<List<MeetingChatMessage>> getRoomMessages(String roomId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '${await _authorizedUrl()}/rooms/$roomId/messages',
        options: await _authorizedOptions(),
      );
      return (response.data ?? const [])
          .map(
            (item) => MeetingChatMessage.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (error) {
      throw _errorMessage(error);
    } on TypeError {
      throw const MeetingApiException.localized(AppError.invalidMessageData);
    } on FormatException {
      throw const MeetingApiException.localized(AppError.invalidMessageData);
    }
  }

  Future<MeetingChatMessage> sendRoomMessage(
    String roomId,
    String content,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${await _authorizedUrl()}/rooms/$roomId/messages',
        data: {'content': content},
        options: await _authorizedOptions(),
      );
      final responseData = response.data;
      if (responseData == null) {
        throw const MeetingApiException.localized(
          AppError.invalidServerResponse,
        );
      }
      return MeetingChatMessage.fromJson(responseData);
    } on DioException catch (error) {
      throw _errorMessage(error);
    } on TypeError {
      throw const MeetingApiException.localized(AppError.invalidMessageData);
    } on FormatException {
      throw const MeetingApiException.localized(AppError.invalidMessageData);
    }
  }

  Future<String> _authorizedUrl() async {
    final serverUrl = await ServerConfig.readUrl();
    final authToken = await ServerConfig.readToken();
    if (serverUrl == null || authToken == null) {
      throw const MeetingApiException.localized(AppError.missingServerSession);
    }
    return serverUrl;
  }

  Future<Options> _authorizedOptions() async {
    final authToken = await ServerConfig.readToken();
    if (authToken == null) {
      throw const MeetingApiException.localized(AppError.missingServerSession);
    }
    return Options(headers: {'Authorization': 'Bearer $authToken'});
  }

  MeetingApiException _errorMessage(DioException error) {
    final responseData = error.response?.data;
    final message = responseData is Map<String, dynamic>
        ? responseData['error'] as String?
        : null;
    return message == null
        ? const MeetingApiException.localized(AppError.meetingServerUnavailable)
        : MeetingApiException(message);
  }

  Future<RoomCredentials> _requestRoom(
    String path,
    Map<String, String> data,
  ) async {
    final serverUrl = await ServerConfig.readUrl();
    final authToken = await ServerConfig.readToken();
    if (serverUrl == null || authToken == null) {
      throw const MeetingApiException.localized(AppError.missingServerSession);
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$serverUrl$path',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
      );
      final responseData = response.data;
      if (responseData == null) {
        throw const MeetingApiException.localized(
          AppError.invalidServerResponse,
        );
      }
      return RoomCredentials.fromJson(responseData);
    } on DioException catch (error) {
      final responseData = error.response?.data;
      final message = responseData is Map<String, dynamic>
          ? responseData['error'] as String?
          : null;
      throw message == null
          ? const MeetingApiException.localized(
              AppError.meetingServerUnavailable,
            )
          : MeetingApiException(message);
    } on TypeError {
      throw const MeetingApiException.localized(AppError.invalidRoomData);
    }
  }
}

class MeetingApiException extends AppException {
  const MeetingApiException(super.message);
  const MeetingApiException.localized(super.code) : super.localized();
}
