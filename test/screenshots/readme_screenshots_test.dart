// Renders the README's screenshots and its GIF into images/, with the real
// fonts and English content. Skipped in the normal test run; to update the
// images:
//
//   SCREENSHOTS=1 flutter test test/screenshots
//   python3 tool/make_readme_gif.py

import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/app/app.dart';
import 'package:v_meeting/app/app_startup.dart';
import 'package:v_meeting/app/http.dart';
import 'package:v_meeting/app/theme.dart';
import 'package:v_meeting/calls/call_controller.dart';
import 'package:v_meeting/calls/ringing_call.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/l10n/delegates.dart';
import 'package:v_meeting/meeting/meeting_member.dart';
import 'package:v_meeting/meeting/widgets/meeting_controls_bar.dart';
import 'package:v_meeting/meeting/widgets/meeting_video_layout.dart';

final _enabled = Platform.environment['SCREENSHOTS'] == '1';
final _out = Directory('images');

/// The app's fonts as they look outside tests: Roboto and Material Icons
/// from the Flutter SDK.
Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final fonts = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String name) async =>
      ByteData.sublistView(await File('$fonts/$name').readAsBytes());
  final roboto = FontLoader('Roboto');
  for (final face in ['Regular', 'Medium', 'Bold', 'Light']) {
    roboto.addFont(read('Roboto-$face.ttf'));
  }
  await roboto.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(read('MaterialIcons-Regular.otf'))).load();
}

const _shot = ValueKey('screenshot');

/// Lets pictures such as the logo finish loading, which happens outside
/// the test's clock.
Future<void> _loadPictures(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump();
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_shot),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(
      pixelRatio: tester.view.devicePixelRatio,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('${_out.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _size(WidgetTester tester, Size size, double ratio) {
  tester.view.physicalSize = size * ratio;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// A server with English people, teams and chats.
class _ShowcaseServer {
  Map<String, Object?> _person(
    int id,
    String name,
    String presence, {
    String status = '',
  }) => {
    'id': id,
    'nick': name.toLowerCase(),
    'display_name': name,
    'status_message': status,
    'presence': presence,
    if (presence == 'offline') 'last_seen_seconds': 5400,
  };

  Map<String, Object?> get _overview => {
    'profile': {
      'id': 1,
      'nick': 'alex',
      'display_name': 'Alex Morgan',
      'status_message': 'Shipping v3 today',
      'presence': 'online',
    },
    'friends': [
      {
        ..._person(2, 'Emma', 'online', status: 'Design review at 4'),
        'unread': 2,
      },
      _person(3, 'Liam', 'in_meeting'),
      _person(4, 'Olivia', 'busy', status: 'Heads down'),
      _person(5, 'Noah', 'online'),
      _person(6, 'Mia', 'offline'),
    ],
    'requests': [
      {'id': 7, 'user': _person(8, 'Sophia', 'online')},
    ],
    'outgoing': <Object?>[],
    'teams': [
      {
        'id': 11,
        'name': 'Product',
        'color': '#7C4DFF',
        'role': 'owner',
        'member_count': 6,
        'online_count': 4,
        'meeting_live': true,
        'room_id': '111-222-333',
        'unread': 3,
      },
      {
        'id': 12,
        'name': 'Mobile',
        'color': '#009688',
        'role': 'member',
        'member_count': 4,
        'online_count': 2,
      },
      {
        'id': 13,
        'name': 'Study group',
        'color': '#FF7043',
        'role': 'admin',
        'member_count': 8,
        'online_count': 1,
      },
    ],
  };

  List<Map<String, Object?>> get _chat {
    final now = DateTime.now().toUtc();
    String at(int minutesAgo) =>
        now.subtract(Duration(minutes: minutesAgo)).toIso8601String();
    Map<String, Object?> line(int id, bool mine, String text, int ago) => {
      'id': id,
      'sender_id': mine ? 1 : 2,
      'sender': mine ? 'Alex Morgan' : 'Emma',
      'content': text,
      'created_at': at(ago),
      'is_mine': mine,
    };
    return [
      line(1, false, 'Did you see the new glass look?', 42),
      line(2, true, 'Yes! The social tab finally feels alive', 40),
      line(3, false, 'Calls ring my phone now, even when it is locked', 38),
      line(4, true, 'Want to try it? Calling you now', 6),
      {
        'id': 5,
        'sender_id': 1,
        'sender': 'Alex Morgan',
        'content': '',
        'room_id': '444-555-666',
        'created_at': at(5),
        'is_mine': true,
      },
      line(6, false, 'Joining in a minute!', 4),
    ];
  }

  Object? _answer(String method, String path) {
    final route = Uri.parse(path).path;
    return switch ((method, route)) {
      ('GET', '/social') => _overview,
      ('GET', '/notifications') => {'latest_id': 100, 'messages': <Object?>[]},
      ('GET', '/chats/friend/2/messages') => _chat,
      ('GET', '/policy') => {'guests_allowed': true},
      ('GET', _) when route.startsWith('/chats/') => <Object?>[],
      _ => <String, Object?>{},
    };
  }

  Dio dio() {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: _answer(
                options.method,
                options.uri.path +
                    (options.uri.query.isEmpty ? '' : '?${options.uri.query}'),
              ),
            ),
          ),
        ),
      );
    addTearDown(dio.close);
    return dio;
  }
}

/// The whole app, signed in to the showcase server, on the home tab.
Future<ProviderContainer> _showApp(WidgetTester tester) async {
  FlutterSecureStorage.setMockInitialValues({'auth_token': 'account-1'});
  SharedPreferences.setMockInitialValues({
    'server_url': 'https://meeting.example.com',
  });
  await tester.pumpWidget(
    RepaintBoundary(
      key: _shot,
      child: ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(_ShowcaseServer().dio()),
          appStartupProvider.overrideWith((ref) async => StartDestination.home),
        ],
        child: const VMeetingApp(),
      ),
    ),
  );
  await _settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(VMeetingApp)));
}

Future<void> _openSocial(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.people_alt_outlined));
  await _settle(tester);
}

const _people = [
  ('Emma', true, true),
  ('Liam', true, false),
  ('Olivia', false, false),
  ('Noah', true, false),
  ('Mia', false, false),
  ('Ethan', true, false),
  ('Ava', false, false),
];

Widget _meeting() {
  final members = [
    const MemberEntry(
      id: 'local',
      name: 'Alex Morgan',
      isLocal: true,
      isMicEnabled: true,
    ),
    for (final (i, (name, mic, speaking)) in _people.indexed)
      MemberEntry(
        id: 'remote-$i',
        name: name,
        identity: 'user-${i + 2}',
        isLocal: false,
        isMicEnabled: mic,
        isSpeaking: speaking,
      ),
  ];
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: MeetingVideoLayout(
                members: members,
                mainMember: members[1],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Center(
              child: MeetingControlsBar(
                microphoneLocked: false,
                microphoneEnabled: true,
                cameraEnabled: false,
                hasUnreadMessages: true,
                sharingScreen: false,
                screenSharingAllowed: true,
                waitingCount: 2,
                onOpenWaiting: () {},
                onToggleMicrophone: () {},
                onToggleCamera: () {},
                onOpenMembers: () {},
                onOpenChat: () {},
                onToggleScreenShare: () {},
                onOpenAudioVideo: () {},
                onOpenSettings: () {},
                onOpenPermissions: () {},
                onShowRoomCode: () {},
                onLeave: () {},
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    if (!_enabled) return;
    await _loadFonts();
    await _out.create(recursive: true);
  });

  group('README screenshots', skip: !_enabled, () {
    testWidgets('home on a computer', (tester) async {
      _size(tester, const Size(1280, 800), 1);
      await _showApp(tester);
      await _loadPictures(tester);
      await _capture(tester, 'desktop-home');
    });

    testWidgets('social with a chat on a computer', (tester) async {
      _size(tester, const Size(1280, 800), 1);
      await _showApp(tester);
      await _openSocial(tester);
      await tester.tap(find.byKey(const ValueKey('friend-2')));
      await _settle(tester);
      await _loadPictures(tester);
      await _capture(tester, 'desktop-social');
    });

    testWidgets('a call ringing on a computer', (tester) async {
      _size(tester, const Size(1280, 800), 1);
      final container = await _showApp(tester);
      await container
          .read(callControllerProvider.notifier)
          .incoming(
            RingingCall(
              id: '1',
              roomId: '111-222-333',
              caller: 'Emma',
              title: 'Product',
              kind: 'team',
              targetId: '11',
              secret: '',
              endsAt: DateTime.now().add(const Duration(minutes: 5)),
            ),
          );
      await _settle(tester);
      await _loadPictures(tester);
      await _capture(tester, 'desktop-call');
    });

    testWidgets('a meeting on a computer', (tester) async {
      _size(tester, const Size(1280, 800), 1);
      await tester.pumpWidget(RepaintBoundary(key: _shot, child: _meeting()));
      await _settle(tester);
      // The gallery: everyone at once.
      await tester.tap(find.byKey(const ValueKey('meeting-next-page')));
      await _settle(tester);
      await _loadPictures(tester);
      await _capture(tester, 'desktop-meeting');
    });

    testWidgets('social on a phone', (tester) async {
      _size(tester, const Size(390, 844), 2);
      await _showApp(tester);
      await _openSocial(tester);
      await _loadPictures(tester);
      await _capture(tester, 'phone-social');
    });

    testWidgets('home on a phone', (tester) async {
      _size(tester, const Size(390, 844), 2);
      await _showApp(tester);
      await _loadPictures(tester);
      await _capture(tester, 'phone-home');
    });

    // Frames of sliding between the phone's tabs, for the GIF.
    testWidgets('tabs on a phone, frame by frame', (tester) async {
      _size(tester, const Size(390, 844), 1.5);
      await _showApp(tester);
      final frames = Directory('${_out.path}/gif-frames');
      if (frames.existsSync()) frames.deleteSync(recursive: true);
      frames.createSync(recursive: true);
      var frame = 0;
      Future<void> hold(int count) async {
        for (var i = 0; i < count; i++) {
          await tester.pump(const Duration(milliseconds: 40));
          await _capture(tester, 'gif-frames/${'$frame'.padLeft(4, '0')}');
          frame++;
        }
      }

      await _loadPictures(tester);
      await hold(15);
      for (final icon in [
        Icons.people_alt_outlined,
        null,
        Icons.settings_outlined,
        Icons.home_outlined,
      ]) {
        // null: teams, with the switcher at the bottom.
        await tester.tap(
          icon == null
              ? find.descendant(
                  of: find.byKey(const ValueKey('social-switcher')),
                  matching: find.text('Teams'),
                )
              : find.byIcon(icon),
        );
        await hold(30);
      }
    });
  });
}
