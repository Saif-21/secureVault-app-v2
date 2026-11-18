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

  // ==========================================
  // SECURE VAULT / PASSWORD MANAGER APIS (/api/pm)
  // ==========================================

  /// Fetch all groups: GET /api/pm/groups
  Future<List<Map<String, dynamic>>> getVaultGroups(String token) async {
    final url = Uri.parse('$baseUrl/pm/groups');
    try {
      final response = await http
          .get(url, headers: _headers(token))
          .timeout(_timeout);
      final json = _parseResponse(response);
      final rawList = json['data'] as List<dynamic>? ?? [];
      return rawList.whereType<Map<String, dynamic>>().toList();
    } on SocketException catch (_) {
      throw ApiException('Network unreachable', isOffline: true);
    } on TimeoutException catch (_) {
      throw ApiException('Network timeout', isOffline: true);
    }
  }

  /// Create a new group: POST /api/pm/groups
  Future<Map<String, dynamic>> createVaultGroup({
    required String token,
    required String name,
    String? icon,
    String? color,
    String? description,
  }) async {
    final url = Uri.parse('$baseUrl/pm/groups');
    final payload = {
      'name': name.trim(),
      if (icon != null && icon.isNotEmpty) 'icon': icon,
      if (color != null && color.isNotEmpty) 'color': color,
      if (description != null && description.isNotEmpty) 'description': description,
    };
    try {
      final response = await http
          .post(url, headers: _headers(token), body: jsonEncode(payload))
          .timeout(_timeout);
      final json = _parseResponse(response);
      return (json['data'] as Map<String, dynamic>?) ?? {};
    } on SocketException catch (_) {
      throw ApiException('Network unreachable', isOffline: true);
    } on TimeoutException catch (_) {
      throw ApiException('Network timeout', isOffline: true);
    }
  }

  /// Delete a group: DELETE /api/pm/groups/:groupId
  Future<void> deleteVaultGroup({
    required String token,
    required String groupId,
  }) async {
    final url = Uri.parse('$baseUrl/pm/groups/$groupId');
    try {
      final response = await http
          .delete(url, headers: _headers(token))
          .timeout(_timeout);
      _parseResponse(response);
    } on SocketException catch (_) {
      throw ApiException('Network unreachable', isOffline: true);
    } on TimeoutException catch (_) {
      throw ApiException('Network timeout', isOffline: true);
    }
  }

  /// Fetch all passwords: GET /api/pm/passwords
  Future<List<Map<String, dynamic>>> getVaultPasswords({
    required String token,
    String? groupId,
  }) async {
    final uri = Uri.parse('$baseUrl/pm/passwords').replace(
      queryParameters: groupId != null ? {'groupId': groupId} : null,
    );
    try {
      final response = await http
          .get(uri, headers: _headers(token))
          .timeout(_timeout);
      final json = _parseResponse(response);
      final rawList = json['data'] as List<dynamic>? ?? [];
      return rawList.whereType<Map<String, dynamic>>().toList();
    } on SocketException catch (_) {
      throw ApiException('Network unreachable', isOffline: true);
    } on TimeoutException catch (_) {
      throw ApiException('Network timeout', isOffline: true);
    }
  }

  /// Add a password: POST /api/pm/passwords
  Future<Map<String, dynamic>> addVaultPassword({
    required String token,
    required String title,
    required String username,
    required String password,
    String? website,
    String? notes,
    String? groupId,
  }) async {
    final url = Uri.parse('$baseUrl/pm/passwords');
    final payload = {
      'title': title.trim(),
      'username': username.trim(),
      'password': password.trim(),
      if (website != null && website.trim().isNotEmpty) 'website': website.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (groupId != null && groupId.isNotEmpty) 'groupId': groupId,
    };
    try {
      final response = await http
          .post(url, headers: _headers(token), body: jsonEncode(payload))
          .timeout(_timeout);
      final json = _parseResponse(response);
      return (json['data'] as Map<String, dynamic>?) ?? {};
    } on SocketException catch (_) {
      throw ApiException('Network unreachable', isOffline: true);
    } on TimeoutException catch (_) {
      throw ApiException('Network timeout', isOffline: true);
    }
  }

  /// Update a password: PATCH /api/pm/passwords/:passwordId
  Future<Map<String, dynamic>> updateVaultPassword({
    required String token,
    required String passwordId,
    required Map<String, dynamic> data,
  }) async {
    final url = Uri.parse('$baseUrl/pm/passwords/$passwordId');
    try {
      final response = await http
          .patch(url, headers: _headers(token), body: jsonEncode(data))
          .timeout(_timeout);
      final json = _parseResponse(response);
      return (json['data'] as Map<String, dynamic>?) ?? {};
    } on SocketException catch (_) {
      throw ApiException('Network unreachable', isOffline: true);
    } on TimeoutException catch (_) {
      throw ApiException('Network timeout', isOffline: true);
    }
  }

  /// Delete a password: DELETE /api/pm/passwords/:passwordId
  Future<void> deleteVaultPassword({
    required String token,
    required String passwordId,
  }) async {
    final url = Uri.parse('$baseUrl/pm/passwords/$passwordId');
    try {
      final response = await http
          .delete(url, headers: _headers(token))
          .timeout(_timeout);
      _parseResponse(response);
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

