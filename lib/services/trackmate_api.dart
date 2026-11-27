import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class TrackMateApi {
  TrackMateApi._();
  static final TrackMateApi instance = TrackMateApi._();
  static const String baseUrl = String.fromEnvironment(
    'TRACKMATE_API_URL',
    defaultValue: 'https://trackmate-api.YOUR_SUBDOMAIN.workers.dev',
  );
  static const _storage = FlutterSecureStorage();
  String? _token;
  Map<String, dynamic>? currentUser;

  Future<void> restoreSession() async {
    _token = await _storage.read(key: 'trackmate_token');
    if (_token == null) return;
    try {
      final response = await _send('GET', '/api/auth/me');
      currentUser = Map<String, dynamic>.from(response['user'] as Map);
    } catch (_) {
      await logout();
    }
  }

  Future<Map<String, dynamic>> register({
    required String fullName, required String email, required String password,
    required String role, String? phone,
  }) async {
    final data = await _send('POST', '/api/auth/register', body: {
      'fullName': fullName, 'email': email, 'password': password,
      'role': role, if (phone != null && phone.isNotEmpty) 'phone': phone,
    }, authenticated: false);
    await _saveSession(data);
    return data;
  }

  Future<Map<String, dynamic>> login({
    required String email, required String password, required String role,
  }) async {
    final data = await _send('POST', '/api/auth/login', body: {
      'email': email, 'password': password, 'role': role,
    }, authenticated: false);
    await _saveSession(data);
    return data;
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    _token = data['token'] as String;
    currentUser = Map<String, dynamic>.from(data['user'] as Map);
    await _storage.write(key: 'trackmate_token', value: _token);
  }

  Future<void> logout() async {
    try { if (_token != null) await _send('POST', '/api/auth/logout'); } catch (_) {}
    _token = null;
    currentUser = null;
    await _storage.delete(key: 'trackmate_token');
  }

  Future<List<Map<String, dynamic>>> orders() async {
    final data = await _send('GET', '/api/orders');
    return (data['orders'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createOrder({
    required String itemDescription, required String pickupAddress,
    required double pickupLatitude, required double pickupLongitude,
    required String deliveryAddress, required double deliveryLatitude,
    required double deliveryLongitude,
  }) => _send('POST', '/api/orders', body: {
    'itemDescription': itemDescription, 'pickupAddress': pickupAddress,
    'pickupLatitude': pickupLatitude, 'pickupLongitude': pickupLongitude,
    'deliveryAddress': deliveryAddress, 'deliveryLatitude': deliveryLatitude,
    'deliveryLongitude': deliveryLongitude,
  });

  Future<void> acceptOrder(String id) async =>
      _send('POST', '/api/orders/${Uri.encodeComponent(id)}/accept');

  Future<void> updateStatus(String id, String status) async =>
      _send('PATCH', '/api/orders/${Uri.encodeComponent(id)}/status', body: {'status': status});

  Future<void> sendLocation(String id, double lat, double lng, {double? heading, double? speed}) async =>
      _send('POST', '/api/orders/${Uri.encodeComponent(id)}/location',
          body: {'latitude': lat, 'longitude': lng, 'heading': heading, 'speed': speed});

  Future<Map<String, dynamic>> tracking(String id) async =>
      _send('GET', '/api/orders/${Uri.encodeComponent(id)}/location');

  Future<Map<String, dynamic>> _send(String method, String path,
      {Map<String, dynamic>? body, bool authenticated = true}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated && _token != null) headers['Authorization'] = 'Bearer $_token';
    late http.Response response;
    switch (method) {
      case 'GET': response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20)); break;
      case 'POST': response = await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 20)); break;
      case 'PATCH': response = await http.patch(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 20)); break;
      default: throw Exception('HTTP method not supported');
    }
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(decoded['error'] ?? 'Erreur serveur (${response.statusCode})');
    }
    return decoded;
  }
}
