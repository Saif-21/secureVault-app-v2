import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:app/src/models/user_model.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.isOffline = false});

  final String message;
  final int? statusCode;
  final bool isOffline;

  @override
  String toString() => message;
}

/// HTTP REST client communicating with the Express backend API.
class ApiService {
  ApiService({String? baseUrl})
      : baseUrl = baseUrl ?? _defaultBaseUrl;

  final String baseUrl;

  static String get _defaultBaseUrl {
    if (!kIsWeb && Platform.isAndroid) {
      // 10.0.2.2 points to host machine from the Android emulator
      return 'http://10.0.2.2:4000/api';
    }
    return 'http://localhost:4000/api';
  }

  static const Duration _timeout = Duration(seconds: 8);

  Map<String, String> _headers([String? token]) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Register a new user account: POST /api/auth/signup
  Future<Map<String, dynamic>> signup({
    required String name,
    required String mobile,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/signup');
    final body = jsonEncode({
      'name': name.trim(),
      'mobile': mobile.trim(),
      'email': email.trim().toLowerCase(),
      'password': password.trim(),
    });

    try {
      final response = await http
          .post(url, headers: _headers(), body: body)
          .timeout(_timeout);

      final data = _parseResponse(response);
      return data;
    } on SocketException catch (_) {
      throw ApiException(
        'Unable to reach server. Operating in offline mode.',
        isOffline: true,
      );
    } on TimeoutException catch (_) {
      throw ApiException(
        'Server connection timed out.',
        isOffline: true,
      );
    }
  }

  /// Log in an existing user: POST /api/auth/login
  Future<Map<String, dynamic>> login({
    String? email,
    String? mobile,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final payload = <String, dynamic>{
      'password': password.trim(),
    };
    if (email != null && email.trim().isNotEmpty) {
      payload['email'] = email.trim().toLowerCase();
    }
    if (mobile != null && mobile.trim().isNotEmpty) {
      payload['mobile'] = mobile.trim();
    }

    try {
      final response = await http
          .post(url, headers: _headers(), body: jsonEncode(payload))
          .timeout(_timeout);

      final data = _parseResponse(response);
      return data;
    } on SocketException catch (_) {
      throw ApiException(
        'Unable to reach server. Operating in offline mode.',
        isOffline: true,
      );
    } on TimeoutException catch (_) {
      throw ApiException(
        'Server connection timed out.',
        isOffline: true,
      );
    }
  }

  /// Get current user profile: GET /api/auth/user/me
  Future<UserModel> getMe(String token) async {
    final url = Uri.parse('$baseUrl/auth/user/me');

    try {
      final response = await http
          .get(url, headers: _headers(token))
          .timeout(_timeout);

      final json = _parseResponse(response);
      final userData = json['data'] as Map<String, dynamic>;
      return UserModel.fromJson(userData);
    } on SocketException catch (_) {
      throw ApiException('Network unreachable', isOffline: true);
    } on TimeoutException catch (_) {
      throw ApiException('Network timeout', isOffline: true);
    }
  }

  /// Update user profile: PATCH /api/auth/user/me/update
  Future<UserModel> updateMe({
    required String token,
    required Map<String, dynamic> data,
  }) async {
    final url = Uri.parse('$baseUrl/auth/user/me/update');

    try {
      final response = await http
          .patch(url, headers: _headers(token), body: jsonEncode(data))
          .timeout(_timeout);

      final json = _parseResponse(response);
      final userData = json['data'] as Map<String, dynamic>;
      return UserModel.fromJson(userData);
    } on SocketException catch (_) {
      throw ApiException('Network unreachable', isOffline: true);
    } on TimeoutException catch (_) {
      throw ApiException('Network timeout', isOffline: true);
    }
  }

  /// Parse response and handle backend ApiResponse / ApiError structure
  Map<String, dynamic> _parseResponse(http.Response response) {
    Map<String, dynamic> jsonBody;
    try {
      jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Invalid server response format (${response.statusCode})');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (jsonBody['success'] == true || jsonBody['data'] != null) {
        return jsonBody;
      }
    }

    final message = jsonBody['message'] ??
        jsonBody['error'] ??
        'Request failed with status ${response.statusCode}';
    throw ApiException(message.toString(), statusCode: response.statusCode);
  }
}

