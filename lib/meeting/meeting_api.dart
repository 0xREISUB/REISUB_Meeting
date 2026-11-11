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

  /// Permissions at join time; live changes arrive as a LiveKit attribute.
  final Set<MeetingPermission> permissions;

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
    this.permissions = const {},
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
      permissions: MeetingPermission.fromJson(json['permissions']),
      inviteUrl: json['invite_url'] as String?,
    );
  }
}

/// The room's shared state: who holds its single screen share, whether
/// newcomers wait to be let in, and who is waiting. Only people who may
/// let others in get the waiting list.
class MeetingState {
  final String screenShareIdentity;
  final bool waitingRoom;
  final List<WaitingPerson> waiting;

  const MeetingState({
    this.screenShareIdentity = '',
    this.waitingRoom = false,
    this.waiting = const [],
  });

  factory MeetingState.fromJson(Map<String, dynamic> json) => MeetingState(
    screenShareIdentity: json['screen_share_identity'] as String? ?? '',
    waitingRoom: json['waiting_room'] as bool? ?? false,
    waiting: [
      for (final entry in json['waiting'] as List? ?? const [])
        WaitingPerson.fromJson(Map<String, dynamic>.from(entry as Map)),
    ],
  );
}

/// Someone in the waiting room.
class WaitingPerson {
  const WaitingPerson({required this.requestId, required this.name});

  final String requestId;
  final String name;

  factory WaitingPerson.fromJson(Map<String, dynamic> json) => WaitingPerson(
    requestId: json['request_id'] as String,
    name: json['name'] as String,
  );
}

/// The outcome of asking to join a room: a seat, or a place in its waiting
/// room.
sealed class JoinResult {
  const JoinResult();
}

class JoinAdmitted extends JoinResult {
  const JoinAdmitted(this.credentials);
  final RoomCredentials credentials;
}

class JoinWaiting extends JoinResult {
  const JoinWaiting(this.requestId);
  final String requestId;
}

enum WaitingStatus { waiting, admitted, rejected }

/// Where a waiting request stands; [credentials] once admitted.
class WaitingUpdate {
  const WaitingUpdate(this.status, [this.credentials]);
  final WaitingStatus status;
  final RoomCredentials? credentials;

  factory WaitingUpdate.fromJson(Map<String, dynamic> json) =>
      switch (json['status']) {
        'admitted' => WaitingUpdate(
          WaitingStatus.admitted,
          RoomCredentials.fromJson(json),
        ),
        'rejected' => const WaitingUpdate(WaitingStatus.rejected),
        'waiting' => const WaitingUpdate(WaitingStatus.waiting),
        _ => throw const FormatException('unknown waiting status'),
      };
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

  /// Joins a room, or, when its waiting room is on, asks to be let in.
  Future<JoinResult> joinRoom({
    required String roomId,
    required String name,
  }) async => _decode(
    await _send('POST', '/rooms/join', data: {'room_id': roomId, 'name': name}),
    (json) => json['status'] == 'waiting'
        ? JoinWaiting(json['request_id'] as String)
        : JoinAdmitted(RoomCredentials.fromJson(json)),
    invalid: AppError.invalidRoomData,
  );

  /// Where this user's request to join stands.
  Future<WaitingUpdate> waitingStatus(String roomId, String requestId) async =>
      _decode(
        await _send('GET', _waiting(roomId, requestId)),
        WaitingUpdate.fromJson,
        invalid: AppError.invalidRoomData,
      );

  /// Gives up waiting.
  Future<void> cancelWaiting(String roomId, String requestId) async {
    await _send('DELETE', _waiting(roomId, requestId));
  }

  /// Turns the waiting room on or off. Needs the permission to let people
  /// in.
  Future<MeetingState> setWaitingRoom(String roomId, bool on) async => _decode(
    await _send('PUT', '${_room(roomId)}/settings', data: {'waiting_room': on}),
    MeetingState.fromJson,
  );

  /// Lets a waiting person in, or turns them away.
  Future<MeetingState> answerWaiting(
    String roomId,
    String requestId, {
    required bool admit,
  }) async => _decode(
    await _send(
      'POST',
      '${_waiting(roomId, requestId)}/${admit ? 'admit' : 'reject'}',
      data: const {},
    ),
    MeetingState.fromJson,
  );

  Future<MeetingState> getMeetingState(String roomId) async => _decode(
    await _send('GET', '${_room(roomId)}/state'),
    MeetingState.fromJson,
  );

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

  /// Replaces [identity]'s permissions. Needs the full admin or the
  /// permission to give permissions; the full admin and yourself can't be
  /// changed. Applies even if the user is not connected.
  Future<void> setParticipantPermissions({
    required String roomId,
    required String identity,
    required Set<MeetingPermission> permissions,
  }) async {
    await _send(
      'PUT',
      '${_room(roomId)}/participants/${Uri.encodeComponent(identity)}/permissions',
      data: {
        'permissions': [
          for (final permission in MeetingPermission.values)
            if (permissions.contains(permission)) permission.wireName,
        ],
      },
    );
  }

  /// Removes [identity] from the meeting for good: the server disconnects
  /// them and refuses their later joins. Needs the permission to remove
  /// members; the full admin and yourself can't be removed.
  Future<void> removeParticipant(String roomId, String identity) async {
    await _send(
      'POST',
      '${_room(roomId)}/participants/${Uri.encodeComponent(identity)}/remove',
      data: const {},
    );
  }

  /// Full admin only: [identity] becomes the full admin and the caller keeps
  /// every permission as a participant.
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
  static String _waiting(String roomId, String requestId) =>
      '${_room(roomId)}/waiting/${Uri.encodeComponent(requestId)}';

  /// Sends an authenticated request and returns the decoded response body.
  ///
  /// Uses the account session when logged in, otherwise a guest session that
  /// is created on first use and renewed once if the server rejects it.
  Future<Object?> _send(String method, String path, {Object? data}) async {
    final serverUrl = await _serverUrl();
    var session = await _session(serverUrl);
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await _dio.request<Object?>(
          '$serverUrl$path',
          data: data,
          options: Options(
            method: method,
            headers: {'Authorization': 'Bearer ${session.token}'},
          ),
        );
        return response.data;
      } on DioException catch (error) {
        if (error.response?.statusCode == 401) {
          if (session.guest && attempt == 0) {
            await _forget(ServerConfig.clearGuestToken);
            session = await _session(serverUrl);
            continue;
          }
          if (!session.guest) {
            // The next request continues as a guest; the user may log in again.
            await _forget(ServerConfig.clearToken);
            throw const MeetingApiException.localized(
              AppError.accountSessionExpired,
              sessionExpired: true,
            );
          }
        }
        throw await _errorFor(error);
      }
    }
  }

  Future<String> _serverUrl() async {
    String? serverUrl;
    try {
      serverUrl = await ServerConfig.readUrl();
    } catch (_) {}
    if (serverUrl == null) {
      throw const MeetingApiException.localized(AppError.missingServerSession);
    }
    return serverUrl;
  }

  Future<({String token, bool guest})> _session(String serverUrl) async {
    try {
      final account = await ServerConfig.readToken();
      if (account != null) return (token: account, guest: false);
      final guest = await ServerConfig.readGuestToken();
      if (guest != null) return (token: guest, guest: true);
    } catch (_) {
      // An unreadable key store is treated like having no session.
    }
    return (token: await _createGuestSession(serverUrl), guest: true);
  }

  /// Requests started together share one guest session instead of each
  /// creating a different guest user.
  static Future<String>? _guestCreation;

  Future<String> _createGuestSession(String serverUrl) {
    return _guestCreation ??= _requestGuestSession(
      serverUrl,
    ).whenComplete(() => _guestCreation = null);
  }

  /// POST /guest creates an anonymous user. Servers without it require an
  /// account.
  Future<String> _requestGuestSession(String serverUrl) async {
    try {
      final response = await _dio.post<Object?>('$serverUrl/guest');
      final data = response.data;
      final token = data is Map ? data['token'] : null;
      if (token is! String || token.isEmpty) {
        throw const MeetingApiException.localized(
          AppError.invalidServerResponse,
        );
      }
      try {
        await ServerConfig.saveGuestToken(token);
      } catch (_) {
        // Without storage the guest session lasts for this request only.
      }
      return token;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 404 || status == 405) {
        throw const MeetingApiException.localized(
          AppError.loginRequired,
          loginRequired: true,
        );
      }
      throw await _errorFor(error);
    }
  }

  static Future<void> _forget(Future<void> Function() clear) async {
    try {
      await clear();
    } catch (_) {}
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
    final responseData = error.response?.data;
    final code = responseData is Map ? responseData['code'] : null;
    final known = switch (code) {
      'last_owner' => AppError.lastOwner,
      'target_protected' => AppError.targetProtected,
      'owner_required' => AppError.ownerRequired,
      'permission_required' || 'not_room_owner' => AppError.permissionRequired,
      'removed_from_room' => AppError.removedFromRoom,
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
  const MeetingApiException(
    super.message, {
    this.sessionExpired = false,
    this.loginRequired = false,
  });
  const MeetingApiException.localized(
    super.code, {
    this.sessionExpired = false,
    this.loginRequired = false,
  }) : super.localized();

  /// The account session ended; requests now continue as a guest.
  final bool sessionExpired;

  /// The server does not offer guest sessions; the user has to log in.
  final bool loginRequired;
}
