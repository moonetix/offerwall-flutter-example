import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moonetix_offerwall/moonetix_offerwall.dart';
import 'package:moonetix_offerwall/moonetix_offerwall_platform_interface.dart';
import 'package:offerwall_flutter_example/src/app.dart';
import 'package:offerwall_flutter_example/src/earn_api.dart';

// Fake values only.
const String testAppId = '000000000000000000000001';
const String testToken = 'sst_testtesttesttesttesttesttesttesttesttesttes';

/// Stands in for the native SDK: records open() calls and lets tests send events.
class FakeMoonetixPlatform extends MoonetixPlatform {
  final StreamController<MoonetixEvent> controller = StreamController<MoonetixEvent>.broadcast();
  final List<String> opened = <String>[];

  @override
  Stream<MoonetixEvent> get events => controller.stream;

  @override
  Future<void> init(String appId) async {}

  @override
  Future<void> open(String token, MoonetixOptions options) async => opened.add(token);
}

/// Stands in for the server in server/: same routes, same JSON.
class FakeServer {
  String balance = '0';
  int sessionStatus = 200;
  final List<http.Request> requests = <http.Request>[];

  late final MockClient client = MockClient((http.Request request) async {
    requests.add(request);
    final bool authed = request.headers['Authorization'] == 'Bearer auth_token_for_tests_only_0000000000';
    switch ('${request.method} ${request.url.path}') {
      case 'POST /api/login':
        final Map<String, dynamic> body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['password'] != 'correct horse battery') {
          return _json(401, <String, Object>{'error': 'wrong_email_or_password'});
        }
        return _json(200, <String, Object>{'token': 'auth_token_for_tests_only_0000000000'});
      case 'GET /api/me':
        if (!authed) return _json(401, <String, Object>{'error': 'signed_out'});
        return _json(200, <String, Object>{
          'userId': '1',
          'email': 'ana@example.com',
          'balance': balance,
          'currency': 'Coins',
          'history': <Object>[],
        });
      case 'POST /api/moonetix/session':
        if (!authed) return _json(401, <String, Object>{'error': 'signed_out'});
        if (sessionStatus != 200) return _json(sessionStatus, <String, Object>{'error': 'offerwall_unavailable'});
        return _json(200, <String, Object>{'token': testToken});
    }
    return _json(404, <String, Object>{'error': 'not_found'});
  });

  static http.Response _json(int status, Map<String, Object> body) =>
      http.Response(jsonEncode(body), status, headers: <String, String>{'content-type': 'application/json'});
}

void main() {
  late FakeMoonetixPlatform platform;
  late FakeServer server;

  setUp(() async {
    Moonetix.resetForTesting();
    platform = FakeMoonetixPlatform();
    MoonetixPlatform.instance = platform;
    await Moonetix.init(testAppId);
    server = FakeServer();
  });

  Future<void> signIn(WidgetTester tester, {String password = 'correct horse battery'}) async {
    await tester.pumpWidget(EarnApp(api: EarnApi(baseUrl: 'https://api.example.test', client: server.client)));
    await tester.enterText(find.byKey(const Key('email')), 'ana@example.com');
    await tester.enterText(find.byKey(const Key('password')), password);
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
  }

  // Native events arrive outside the test's fake clock, like on a device.
  Future<void> sendEvent(WidgetTester tester, MoonetixEvent event) async {
    await tester.runAsync(() async {
      platform.controller.add(event);
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
  }

  testWidgets('wrong password stays on the sign-in screen', (WidgetTester tester) async {
    await signIn(tester, password: 'wrong password');
    expect(find.text('Wrong email or password.'), findsOneWidget);
    expect(find.byKey(const Key('earn')), findsNothing);
  });

  testWidgets('Earn opens the offerwall with a fresh token from the server', (WidgetTester tester) async {
    await signIn(tester);
    expect(find.text('0 Coins'), findsOneWidget);

    await tester.tap(find.byKey(const Key('earn')));
    await tester.pumpAndSettle();
    expect(platform.opened, <String>[testToken]);
    final http.Request session = server.requests.lastWhere((http.Request r) => r.url.path == '/api/moonetix/session');
    expect(session.method, 'POST');
    expect(session.url.toString(), 'https://api.example.test/api/moonetix/session');

    // A second tap asks the server again: tokens are never reused.
    await tester.tap(find.byKey(const Key('earn')));
    await tester.pumpAndSettle();
    expect(server.requests.where((http.Request r) => r.url.path == '/api/moonetix/session').length, 2);
  });

  testWidgets('closing the offerwall reloads the balance from the server', (WidgetTester tester) async {
    await signIn(tester);
    await tester.tap(find.byKey(const Key('earn')));
    await tester.pumpAndSettle();

    // The server got a postback meanwhile. The app only reloads, it never adds coins itself.
    server.balance = '150.75';
    await sendEvent(tester, const MoonetixClosed());
    expect(find.text('150.75 Coins'), findsOneWidget);
  });

  testWidgets('a server error shows a message and does not open the wall', (WidgetTester tester) async {
    await signIn(tester);
    server.sessionStatus = 503;
    await tester.tap(find.byKey(const Key('earn')));
    await tester.pumpAndSettle();
    expect(platform.opened, isEmpty);
    expect(find.text('The offerwall is not available right now.'), findsOneWidget);
  });

  testWidgets('offerwall errors from the plugin are shown', (WidgetTester tester) async {
    await signIn(tester);
    await sendEvent(tester, const MoonetixErrorEvent(MoonetixError(MoonetixErrorCode.network, 'offline')));
    expect(find.text('No connection. Try again when you are back online.'), findsOneWidget);
  });

  test('a 401 from the server signs the user out', () async {
    final EarnApi api = EarnApi(baseUrl: 'https://api.example.test', client: server.client);
    await api.signIn('ana@example.com', 'correct horse battery');
    expect(api.signedIn, isTrue);
    expect((await api.me()).balance, '0');
    final EarnApi stranger = EarnApi(baseUrl: 'https://api.example.test', client: server.client);
    await expectLater(stranger.fetchMoonetixToken(), throwsA(isA<ApiException>().having((ApiException e) => e.signedOut, 'signedOut', isTrue)));
    expect(stranger.signedIn, isFalse);
  });
}
