import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service for managing local user data persistence
/// Stores user credentials and profile info after login
class UserStorageService {
  static const String _userDataKey = 'user_data';
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';
  static const String _userRoleKey = 'user_role';

  /// Save user login credentials and profile
  static Future<void> saveUserData({
    required String userId,
    required String userName,
    required String userEmail,
    required String userRole,
    required String token,
    required Map<String, dynamic> fullUserData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save individual fields for quick access
      await prefs.setString(_userIdKey, userId);
      await prefs.setString(_userNameKey, userName);
      await prefs.setString(_userEmailKey, userEmail);
      await prefs.setString(_userRoleKey, userRole);
      await prefs.setString(_tokenKey, token);
      
      // Save complete user data as JSON
      await prefs.setString(_userDataKey, jsonEncode(fullUserData));
    } catch (e) {
      throw Exception('Failed to save user data: $e');
    }
  }

  /// Retrieve saved user ID
  static Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userIdKey);
    } catch (e) {
      return null;
    }
  }

  /// Retrieve saved user name
  static Future<String?> getUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userNameKey);
    } catch (e) {
      return null;
    }
  }

  /// Retrieve saved user email
  static Future<String?> getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userEmailKey);
    } catch (e) {
      return null;
    }
  }

  /// Retrieve saved user role
  static Future<String?> getUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userRoleKey);
    } catch (e) {
      return null;
    }
  }

  /// Retrieve saved auth token
  static Future<String?> getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      return null;
    }
  }

  /// Retrieve complete user data
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataJson = prefs.getString(_userDataKey);
      
      if (userDataJson == null) return null;
      
      return jsonDecode(userDataJson) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Check if user is logged in (has saved credentials)
  static Future<bool> isUserLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Clear all user data (logout)
  static Future<void> clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userIdKey);
      await prefs.remove(_userNameKey);
      await prefs.remove(_userEmailKey);
      await prefs.remove(_userRoleKey);
      await prefs.remove(_tokenKey);
      await prefs.remove(_userDataKey);
    } catch (e) {
      throw Exception('Failed to clear user data: $e');
    }
  }

  /// Get all user info at once
  static Future<Map<String, String?>> getAllUserInfo() async {
    try {
      return {
        'userId': await getUserId(),
        'userName': await getUserName(),
        'userEmail': await getUserEmail(),
        'userRole': await getUserRole(),
        'token': await getAuthToken(),
      };
    } catch (e) {
      return {};
    }
  }
}
