/// Authentication Provider
/// Manages authentication state and user session
library;

import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/api/api_service.dart';
import '../paitent/api_client.dart';
import '../config/app_config.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  late final TeleMedicineApiClient _apiClient;
  
  User? _currentUser;
  String? _authToken;
  bool _isLoading = false;
  String? _error;

  AuthProvider({required ApiService apiService})
      : _apiService = apiService {
    _apiClient = TeleMedicineApiClient(AppConfig.apiBaseUrl);
  }

  // Getters
  User? get currentUser => _currentUser;
  String? get authToken => _authToken;
  bool get isAuthenticated => _authToken != null && _currentUser != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Register
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String role = 'patient',
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiClient.register(
        name: name,
        email: email,
        password: password,
        role: role,
      );

      if (response.success && response.data != null) {
        final token = response.data!['token'] as String?;
        if (token != null) {
          _authToken = token;
          _apiService.setAuthToken(token);

          _currentUser = User(
            id: response.data!['userId'] ?? '${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            email: email,
            role: role,
            profileImageUrl: '',
            phoneNumber: '',
            bio: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          notifyListeners();
          return true;
        }
      }

      _setError(response.error?.toString() ?? 'Registration failed');
      return false;
    } catch (e) {
      _setError('Registration error: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Login
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiClient.login(
        email: email,
        password: password,
      );

      if (response.success && response.data != null) {
        final token = response.data!['token'] as String?;
        final userData = response.data!['user'] as Map<String, dynamic>?;

        if (token != null && userData != null) {
          _authToken = token;
          _apiService.setAuthToken(token);

          _currentUser = User(
            id: response.data!['userId'] ?? userData['userId'] ?? '${DateTime.now().millisecondsSinceEpoch}',
            name: userData['name'] ?? email.split('@')[0],
            email: userData['email'] ?? email,
            role: userData['role'] ?? 'patient',
            profileImageUrl: userData['profileImageUrl'] ?? '',
            phoneNumber: userData['phoneNumber'] ?? '',
            bio: userData['bio'] ?? '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          notifyListeners();
          return true;
        }
      }

      _setError(response.error?.toString() ?? 'Login failed');
      return false;
    } catch (e) {
      _setError('Login error: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Logout
  Future<void> logout() async {
    _setLoading(true);
    try {
      await _apiClient.logout();
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      _currentUser = null;
      _authToken = null;
      _apiService.setAuthToken('');
      _setLoading(false);
      notifyListeners();
    }
  }

  // Update Profile
  Future<bool> updateProfile({required User user}) async {
    _setLoading(true);
    _clearError();

    try {
      _currentUser = user;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Update profile error: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Refresh Token
  Future<bool> refreshToken() async {
    if (_authToken == null) return false;

    try {
      final response = await _apiClient.refreshToken(_authToken!);

      if (response.success && response.data != null) {
        final newToken = response.data!['token'] as String?;
        if (newToken != null) {
          _authToken = newToken;
          _apiService.setAuthToken(newToken);
          notifyListeners();
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Token refresh error: $e');
      return false;
    }
  }

  // Private helpers
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    if (error != null) {
      debugPrint('❌ Auth Error: $error');
    }
  }

  void _clearError() {
    _error = null;
  }

}
