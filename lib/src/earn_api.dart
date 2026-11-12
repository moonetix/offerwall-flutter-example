import 'dart:convert';

import 'package:http/http.dart' as http;

/// What your server knows about the signed-in user.
class Account {
  const Account({
    required this.userId,
    required this.email,
    required this.balance,
    required this.currency,
    required this.history,
  });

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        userId: json['userId'] as String,
        email: json['email'] as String,
        balance: json['balance'] as String,
        currency: json['currency'] as String,
        history: (json['history'] as List<dynamic>)
            .map((dynamic row) => Reward.fromJson(row as Map<String, dynamic>))
            .toList(),
      );

  final String userId;
  final String email;

  /// Kept as text so decimal rewards like 0.375 show exactly.
  final String balance;
  final String currency;
  final List<Reward> history;
}

/// One credited or reversed offer, filled from postbacks on your server.
class Reward {
  const Reward({required this.offer, required this.reward, required this.status, required this.at});

  factory Reward.fromJson(Map<String, dynamic> json) => Reward(
        offer: json['offer'] as String,
        reward: json['reward'] as String,
        status: json['status'] as String,
        at: json['at'] as String,
      );

  final String offer;
  final String reward;

  /// credited or reversed.
  final String status;
  final String at;
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.error);

  final int statusCode;
  final String error;

  bool get signedOut => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode, $error)';
}

/// Talks to YOUR server only. The app never calls api.moonetix.com itself,
/// because creating a session needs the API key.
class EarnApi {
  EarnApi({required String baseUrl, http.Client? client})
      : _base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
        _client = client ?? http.Client();

  final Uri _base;
  final http.Client _client;

  /// Your own sign-in credential. Kept in memory in this example; use secure
  /// storage (Keychain, Keystore) if you keep users signed in across restarts.
  String? _authToken;

  bool get signedIn => _authToken != null;

  Future<void> register(String email, String password, {required bool over16}) async {
    final Map<String, dynamic> data = await _send('POST', 'api/register', <String, Object>{
      'email': email,
      'password': password,
      'over16': over16,
    });
    _authToken = data['token'] as String;
  }

  Future<void> signIn(String email, String password) async {
    final Map<String, dynamic> data =
        await _send('POST', 'api/login', <String, Object>{'email': email, 'password': password});
    _authToken = data['token'] as String;
  }

  Future<void> signOut() async {
    try {
      await _send('POST', 'api/logout', null);
    } finally {
      _authToken = null;
    }
  }

  Future<Account> me() async => Account.fromJson(await _send('GET', 'api/me', null));

  /// Asks YOUR server for a fresh token. Your server calls POST /v1/session
  /// with the API key, for the signed-in user only. Never cache the token:
  /// it works once and for 10 minutes.
  Future<String> fetchMoonetixToken() async {
    final Map<String, dynamic> data = await _send('POST', 'api/moonetix/session', null);
    return data['token'] as String;
  }

  Future<Map<String, dynamic>> _send(String method, String path, Map<String, Object>? body) async {
    final http.Request request = http.Request(method, _base.resolve(path));
    if (_authToken != null) request.headers['Authorization'] = 'Bearer $_authToken';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response response =
        await http.Response.fromStream(await _client.send(request).timeout(const Duration(seconds: 10)));
    Map<String, dynamic> data = <String, dynamic>{};
    try {
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } on FormatException {
      // Not JSON, for example a proxy error page. Handled below.
    }
    if (response.statusCode < 200 || response.statusCode > 299) {
      if (response.statusCode == 401) _authToken = null;
      throw ApiException(response.statusCode, (data['error'] as String?) ?? 'http_${response.statusCode}');
    }
    return data;
  }
}
