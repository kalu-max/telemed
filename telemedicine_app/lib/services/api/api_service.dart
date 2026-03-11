/// Base API Service
/// Provides centralized HTTP client configuration using Dio
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../config/app_config.dart';

class ApiService {
  late final Dio _dio;
  String? _authToken;

  ApiService() {
    _initializeDio();
  }

  void _initializeDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        contentType: Headers.jsonContentType,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    // Add interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_authToken != null) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
          debugPrint('🔵 API Request: ${options.method} ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint('🟢 API Response: ${response.statusCode} ${response.requestOptions.path}');
          return handler.next(response);
        },
        onError: (error, handler) {
          debugPrint('🔴 API Error: ${error.message}');
          if (error.response?.statusCode == 401) {
            _onTokenExpired();
          }
          return handler.next(error);
        },
      ),
    );
  }

  void setAuthToken(String token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  void _onTokenExpired() {
    debugPrint('Token expired, user needs to re-login');
    // Handle token expiration - could navigate to login or refresh token
  }

  // GET Request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
    _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );

  // POST Request
  Future<Response<T>> post<T>(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
    _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );

  // PUT Request
  Future<Response<T>> put<T>(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
    _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );

  // PATCH Request
  Future<Response<T>> patch<T>(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
    _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );

  // DELETE Request
  Future<Response<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
    _dio.delete<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );

  Dio get dio => _dio;
}

/// Generic API Response Model
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? error;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.error,
    this.statusCode,
  });

  factory ApiResponse.fromResponse(
    Response response,
    dynamic Function(dynamic)? fromJson,
  ) {
    final data = response.data as Map<String, dynamic>?;
    final statusCode = response.statusCode ?? 500;
    final success = statusCode >= 200 && statusCode < 300;

    return ApiResponse(
      success: success,
      statusCode: statusCode,
      message: data?['message'] as String?,
      error: data?['error'] as String?,
      data: success && fromJson != null
        ? fromJson(data?['data'])
        : null,
    );
  }

  factory ApiResponse.error({
    required String error,
    int statusCode = 500,
  }) =>
    ApiResponse(
      success: false,
      error: error,
      statusCode: statusCode,
    );
}
