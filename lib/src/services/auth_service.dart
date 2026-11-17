import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/src/models/user_model.dart';
import 'package:app/src/services/api_service.dart';

/// Offline-first authentication service managing online sync and local credentials.
class AuthService extends ChangeNotifier {
  AuthService._internal();

  static final AuthService instance = AuthService._internal();

  final ApiService _apiService = ApiService();

  UserModel? _currentUser;
  String? _token;
  bool _isLoading = false;
  bool _isInitialized = false;

  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _currentUser != null;

  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'auth_user';
  static const String _keyPinHash = 'auth_pin_hash';
  static const String _keyPendingSignup = 'auth_pending_signup';

  // Resilient in-memory fallback cache if native SharedPreferences is pending rebuild
  static final Map<String, String> _memoryCache = {};
  static bool _fallbackToMemory = false;

  /// Safe write that protects against MissingPluginException during hot reloads
  Future<void> _safeSetString(String key, String value) async {
    _memoryCache[key] = value;
    if (_fallbackToMemory) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('[AuthService] SharedPreferences unavailable, using in-memory store: $e');
      _fallbackToMemory = true;
    }
  }

  /// Safe read that protects against MissingPluginException during hot reloads
  Future<String?> _safeGetString(String key) async {
    if (_fallbackToMemory) {
      return _memoryCache[key];
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key) ?? _memoryCache[key];
    } catch (e) {
      debugPrint('[AuthService] SharedPreferences unavailable, using in-memory store: $e');
      _fallbackToMemory = true;
      return _memoryCache[key];
    }
  }

  /// Safe remove that protects against MissingPluginException during hot reloads
  Future<void> _safeRemoveString(String key) async {
    _memoryCache.remove(key);
    if (_fallbackToMemory) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {
      _fallbackToMemory = true;
    }
  }

  /// Hash a 6-digit PIN locally for secure offline verification
  String _hashPin(String pin) {
    final bytes = utf8.encode('salt_vault_offline_$pin');
    return sha256.convert(bytes).toString();
  }

  /// Initialize local session from storage on app startup
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _token = await _safeGetString(_keyToken);
      final userJsonStr = await _safeGetString(_keyUser);

      if (userJsonStr != null && userJsonStr.isNotEmpty) {
        final Map<String, dynamic> userMap = jsonDecode(userJsonStr);
        _currentUser = UserModel.fromJson(userMap);
      }

      // If token exists, try silent background sync without blocking offline startup
      if (_token != null && _token!.isNotEmpty) {
        _syncProfileInBackground();
      }
    } catch (e) {
      debugPrint('[AuthService] Error reading local session: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _syncProfileInBackground() async {
    if (_token == null) return;
    try {
      final remoteUser = await _apiService.getMe(_token!);
      _currentUser = remoteUser;
      await _safeSetString(_keyUser, jsonEncode(remoteUser.toJson()));
      notifyListeners();
    } catch (_) {
      // Gracefully continue using local cached user profile
    }
  }

  /// Register new user account with offline fallback
  Future<void> signup({
    required String name,
    required String mobile,
    required String email,
    required String pin,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      Map<String, dynamic>? response;
      String? authToken;

      try {
        response = await _apiService.signup(
          name: name,
          mobile: mobile,
          email: email,
          password: pin,
        );
        final data = response['data'] as Map<String, dynamic>?;
        authToken = data?['token']?.toString();
      } on ApiException catch (e) {
        if (!e.isOffline) {
          rethrow;
        }
        // If server is offline, proceed with local-first account creation
        debugPrint('[AuthService] Server offline during signup. Creating local account.');
      }

      final user = UserModel(
        id: authToken != null
            ? 'user_${DateTime.now().millisecondsSinceEpoch}'
            : 'local_user_${DateTime.now().millisecondsSinceEpoch}',
        name: name.trim(),
        email: email.trim().toLowerCase(),
        mobile: mobile.trim(),
        isOfflineOnly: authToken == null,
      );

      _currentUser = user;
      _token = authToken;

      // Save local credentials safely
      await _safeSetString(_keyUser, jsonEncode(user.toJson()));
      await _safeSetString(_keyPinHash, _hashPin(pin));
      if (authToken != null) {
        await _safeSetString(_keyToken, authToken);
      } else {
        // Queue pending signup payload for background sync
        await _safeSetString(
          _keyPendingSignup,
          jsonEncode({
            'name': name,
            'mobile': mobile,
            'email': email,
            'password': pin,
          }),
        );
      }

      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Log in with email or mobile + 6-digit security PIN
  Future<void> login({
    String? email,
    String? mobile,
    required String pin,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      Map<String, dynamic>? response;
      String? authToken;

      try {
        response = await _apiService.login(
          email: email,
          mobile: mobile,
          password: pin,
        );
        final data = response['data'] as Map<String, dynamic>?;
        authToken = data?['token']?.toString();
      } on ApiException catch (e) {
        if (!e.isOffline) {
          rethrow;
        }
        // Fallback to offline PIN authentication
        debugPrint('[AuthService] Server offline. Checking local credentials.');
      }

      final savedPinHash = await _safeGetString(_keyPinHash);

      if (authToken != null) {
        _token = authToken;
        await _safeSetString(_keyToken, authToken);
        await _safeSetString(_keyPinHash, _hashPin(pin));

        // Fetch user profile from API
        try {
          final remoteUser = await _apiService.getMe(authToken);
          _currentUser = remoteUser;
          await _safeSetString(_keyUser, jsonEncode(remoteUser.toJson()));
        } catch (_) {
          _currentUser ??= UserModel(
            id: 'user_online',
            name: email?.split('@').first ?? 'Alex Morgan',
            email: email,
            mobile: mobile,
          );
        }
      } else {
        // Offline verification: verify entered PIN against saved hash
        if (savedPinHash != null && savedPinHash == _hashPin(pin)) {
          final userJsonStr = await _safeGetString(_keyUser);
          if (userJsonStr != null) {
            _currentUser = UserModel.fromJson(jsonDecode(userJsonStr));
          } else {
            _currentUser = UserModel(
              id: 'cached_user',
              name: 'Alex Morgan',
              email: email ?? 'alex.morgan@example.com',
              mobile: mobile ?? '9876543210',
            );
          }
        } else if (savedPinHash == null) {
          throw ApiException(
            'Cannot connect to server. No offline account found on this device. Please connect to internet to login for the first time.',
            isOffline: true,
          );
        } else {
          throw ApiException('Invalid 6-digit security PIN');
        }
      }

      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fast local unlock with 6-digit PIN
  Future<bool> verifyLocalPin(String pin) async {
    final savedHash = await _safeGetString(_keyPinHash);
    return savedHash != null && savedHash == _hashPin(pin);
  }

  /// Update user's 6-digit security PIN
  Future<void> updatePin({
    required String oldPin,
    required String newPin,
  }) async {
    if (newPin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(newPin)) {
      throw ApiException('New PIN must be exactly 6 digits');
    }

    final savedPinHash = await _safeGetString(_keyPinHash);
    if (savedPinHash != null && savedPinHash != _hashPin(oldPin)) {
      throw ApiException('Current PIN is incorrect');
    }

    await _safeSetString(_keyPinHash, _hashPin(newPin));
    notifyListeners();
  }

  /// Update user profile details (Name, Email, Mobile, Gender)
  Future<void> updateProfile({
    required String name,
    required String email,
    required String mobile,
    String? gender,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      UserModel updatedUser = (_currentUser ??
              const UserModel(id: 'local_user', name: 'User'))
          .copyWith(
        name: name.trim(),
        email: email.trim().toLowerCase(),
        mobile: mobile.trim(),
        gender: gender?.trim(),
      );

      if (_token != null && _token!.isNotEmpty) {
        try {
          final remoteUser = await _apiService.updateMe(
            token: _token!,
            data: {
              'name': name.trim(),
              'email': email.trim().toLowerCase(),
              'mobile': mobile.trim(),
              if (gender != null && gender.trim().isNotEmpty) 'gender': gender.trim(),
            },
          );
          updatedUser = remoteUser;
        } catch (e) {
          debugPrint('[AuthService] Remote update failed, preserved locally: $e');
        }
      }

      _currentUser = updatedUser;
      await _safeSetString(_keyUser, jsonEncode(updatedUser.toJson()));
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign out and clear session tokens
  Future<void> logout() async {
    _currentUser = null;
    _token = null;
    await _safeRemoveString(_keyToken);
    notifyListeners();
  }

  /// For testing or setting the authenticated user directly
  @visibleForTesting
  void setMockUser(UserModel? user) {
    _currentUser = user;
    _isInitialized = true;
    notifyListeners();
  }
}
