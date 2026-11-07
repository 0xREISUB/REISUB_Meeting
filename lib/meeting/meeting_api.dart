import 'package:v_meeting/l10n/localized_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/app/http.dart';
import 'package:v_meeting/auth/server_config.dart';
import 'package:v_meeting/meeting/meeting_member.dart';

class RoomCredentials {
  final String roomId;
  final String liveKitUrl;
  final String token;
  final String participant;
  final bool isHost;

  /// Role at join time; the live role arrives as a LiveKit attribute. Older
  /// servers only send is_host.
  final MeetingRole? role;

  /// Shareable invite link from the server, if it provides one.
  final String? inviteUrl;

  MeetingRole get initialRole =>
      role ?? (isHost ? MeetingRole.owner : MeetingRole.participant);

  const RoomCredentials({
    required this.roomId,
    required this.liveKitUrl,
    required this.token,
    required this.participant,
    required this.isHost,
    this.role,
    this.inviteUrl,
  });

  factory RoomCredentials.fromJson(Map<String, dynamic> json) {
    return RoomCredentials(
      roomId: json['room_id'] as String,
      liveKitUrl: json['livekit_url'] as String,
      token: json['token'] as String,
      participant: json['participant'] as String,
      isHost: json['is_host'] as bool? ?? false,
      role: json['role'] is String
          ? MeetingRole.parse(json['role'] as String)
          : null,
      inviteUrl: json['invite_url'] as String?,
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

final meetingApiProvider = Provider<MeetingApi>(
  (ref) => MeetingApi(dio: ref.watch(dioProvider)),
);

class MeetingApi {
  MeetingApi({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ),
          );

  final Dio _dio;

  Future<RoomCredentials> createRoom(String name) async => _decode(
    await _send('POST', '/rooms', data: {'name': name}),
    RoomCredentials.fromJson,
    invalid: AppError.invalidRoomData,
  );

  Future<RoomCredentials> joinRoom({
    required String roomId,
    required String name,
  }) async => _decode(
    await _send('POST', '/rooms/join', data: {'room_id': roomId, 'name': name}),
    RoomCredentials.fromJson,
    invalid: AppError.invalidRoomData,
  );

  Future<MeetingState> getMeetingState(String roomId) async => _decode(
    await _send('GET', '${_room(roomId)}/state'),
    MeetingState.fromJson,
  );

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
  ) async => _decode(
    await _send('POST', '${_room(roomId)}/$action', data: data),
    MeetingState.fromJson,
  );

  Future<void> closeRoom(String roomId) async {
    await _send('POST', '${_room(roomId)}/close', data: const {});
  }

  Future<void> setParticipantMicrophone({
    required String roomId,
    required String identity,
    required bool locked,
    bool requestUnmute = false,
  }) async {
    await _send(
      'POST',
      '${_room(roomId)}/participants/${Uri.encodeComponent(identity)}/microphone',
      data: {'locked': locked, 'request_unmute': requestUnmute},
    );
  }

  /// Owners only. [role] is applied even if the user is not connected.
  Future<void> setParticipantRole({
    required String roomId,
    required String identity,
    required MeetingRole role,
  }) async {
    await _send(
      'POST',
      '${_room(roomId)}/participants/${Uri.encodeComponent(identity)}/role',
      data: {'role': role.name},
    );
  }

  /// Owners only: [identity] becomes owner and the caller becomes moderator.
  Future<void> transferOwnership(String roomId, String identity) async {
    await _send(
      'POST',
      '${_room(roomId)}/transfer-ownership',
      data: {'identity': identity},
    );
  }

  /// Tells the server this user left on purpose, so ownership passes on at
  /// once instead of after LiveKit notices the disconnect.
  Future<void> leaveRoom(String roomId) async {
    await _send('POST', '${_room(roomId)}/leave');
  }

  Future<List<MeetingChatMessage>> getRoomMessages(String roomId) async {
    final data = await _send('GET', '${_room(roomId)}/messages');
    if (data == null) return const [];
    if (data is! List) {
      throw const MeetingApiException.localized(AppError.invalidMessageData);
    }
    return [
      for (final item in data)
        _decode(
          item,
          MeetingChatMessage.fromJson,
          invalid: AppError.invalidMessageData,
        ),
    ];
  }

  Future<MeetingChatMessage> sendRoomMessage(
    String roomId,
    String content,
  ) async => _decode(
    await _send(
      'POST',
      '${_room(roomId)}/messages',
      data: {'content': content},
    ),
    MeetingChatMessage.fromJson,
    invalid: AppError.invalidMessageData,
  );

  static String _room(String roomId) => '/rooms/${Uri.encodeComponent(roomId)}';

  /// Sends an authenticated request and returns the decoded response body.
  Future<Object?> _send(String method, String path, {Object? data}) async {
    final (serverUrl, token) = await _session();
    try {
      final response = await _dio.request<Object?>(
        '$serverUrl$path',
        data: data,
        options: Options(
          method: method,
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data;
    } on DioException catch (error) {
      throw await _errorFor(error);
    }
  }

  Future<(String, String)> _session() async {
    String? serverUrl;
    String? token;
    try {
      serverUrl = await ServerConfig.readUrl();
      token = await ServerConfig.readToken();
    } catch (_) {
      // An unreadable key store is treated like a missing session.
    }
    if (serverUrl == null || token == null) {
      throw const MeetingApiException.localized(
        AppError.missingServerSession,
        sessionExpired: true,
      );
    }
    return (serverUrl, token);
  }

  /// Converts a JSON object, rejecting missing or malformed server data
  /// instead of crashing on it.
  static T _decode<T>(
    Object? data,
    T Function(Map<String, dynamic> json) fromJson, {
    AppError invalid = AppError.invalidServerResponse,
  }) {
    if (data is! Map) {
      throw MeetingApiException.localized(
        data == null ? AppError.invalidServerResponse : invalid,
      );
    }
    try {
      return fromJson(Map<String, dynamic>.from(data));
    } on TypeError {
      throw MeetingApiException.localized(invalid);
    } on FormatException {
      throw MeetingApiException.localized(invalid);
    }
  }

  Future<MeetingApiException> _errorFor(DioException error) async {
    if (error.response?.statusCode == 401) {
      await ServerConfig.clearToken();
      return const MeetingApiException.localized(
        AppError.missingServerSession,
        sessionExpired: true,
      );
    }
    final responseData = error.response?.data;
    final code = responseData is Map ? responseData['code'] : null;
    final known = switch (code) {
      'last_owner' => AppError.lastOwner,
      'target_protected' => AppError.targetProtected,
      'owner_required' => AppError.ownerRequired,
      'not_room_owner' => AppError.moderatorRequired,
      _ => null,
    };
    if (known != null) return MeetingApiException.localized(known);
    final message = responseData is Map ? responseData['error'] : null;
    return message is String && message.isNotEmpty
        ? MeetingApiException(message)
        : const MeetingApiException.localized(
            AppError.meetingServerUnavailable,
          );
  }
}

class MeetingApiException extends AppException {
  const MeetingApiException(super.message, {this.sessionExpired = false});
  const MeetingApiException.localized(super.code, {this.sessionExpired = false})
    : super.localized();

  final bool sessionExpired;
}
