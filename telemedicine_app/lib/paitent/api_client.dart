import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final dynamic error;

  ApiResponse({required this.success, this.data, this.message, this.error});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    Function(dynamic) fromJson,
  ) {
    return ApiResponse(
      success: json['success'] ?? false,
      data: json['data'] != null ? fromJson(json['data']) : null,
      message: json['message'],
      error: json['error'],
    );
  }
}

class TeleMedicineApiClient {
  String? _authToken;
  String? currentUserId;
  late final Dio _dio;
  final String baseUrl;

  TeleMedicineApiClient(this.baseUrl) {
    _initHttpClient();
  }

  void _initHttpClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    // Add interceptors for logging and auth
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
          debugPrint(
            '🟢 API Response: ${response.statusCode} ${response.requestOptions.path}',
          );
          return handler.next(response);
        },
        onError: (error, handler) {
          debugPrint('🔴 API Error: ${error.message}');
          return handler.next(error);
        },
      ),
    );
  }

  void setAuthToken(String token) {
    _authToken = token;
  }

  // Auth APIs
  Future<ApiResponse<Map<String, dynamic>>> register({
    required String email,
    required String password,
    required String name,
    required String role,
    String? specialization,
  }) async {
    try {
      final response = await _dio.post(
        '/api/auth/register',
        data: {
          'email': email,
          'password': password,
          'name': name,
          'role': role,
          if (specialization != null && specialization.isNotEmpty)
            'specialization': specialization,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return ApiResponse(
          success: true,
          data: data,
          message: data['message'] ?? 'Registration successful',
        );
      } else {
        return ApiResponse(
          success: false,
          error: response.data['error'] ?? 'Registration failed',
        );
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error during registration',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['token'] != null) {
          setAuthToken(data['token']);
        }
        return ApiResponse(
          success: true,
          data: data,
          message: data['message'] ?? 'Login successful',
        );
      } else {
        return ApiResponse(
          success: false,
          error: response.data['error'] ?? 'Login failed',
        );
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error during login',
      );
    }
  }

  // Call Management APIs
  Future<ApiResponse<Map<String, dynamic>>> initiateCall({
    required String recipientId,
    required String type,
    required String initiatorName,
  }) async {
    try {
      final response = await _dio.post(
        '/api/calls/initiate',
        data: {
          'recipientId': recipientId,
          'type': type,
          'initiatorName': initiatorName,
        },
      );

      if (response.statusCode == 201) {
        return ApiResponse(
          success: true,
          data: response.data,
          message: response.data['message'] ?? 'Call initiated',
        );
      } else {
        return ApiResponse(
          success: false,
          error: response.data['error'] ?? 'Call initiation failed',
        );
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error initiating call',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> answerCall(String callId) async {
    try {
      final response = await _dio.post(
        '/api/calls/answer',
        data: {'callId': callId},
      );

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: response.data,
          message: response.data['message'] ?? 'Call answered',
        );
      } else {
        return ApiResponse(
          success: false,
          error: response.data['error'] ?? 'Call answer failed',
        );
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error answering call',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> rejectCall(String callId) async {
    try {
      final response = await _dio.post(
        '/api/calls/reject',
        data: {'callId': callId},
      );

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: response.data,
          message: response.data['message'] ?? 'Call rejected',
        );
      } else {
        return ApiResponse(
          success: false,
          error: response.data['error'] ?? 'Call rejection failed',
        );
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error rejecting call',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> endCall(String callId) async {
    try {
      final response = await _dio.post(
        '/api/calls/end',
        data: {'callId': callId},
      );

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: response.data,
          message: response.data['message'] ?? 'Call ended',
        );
      } else {
        return ApiResponse(
          success: false,
          error: response.data['error'] ?? 'Call end failed',
        );
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error ending call',
      );
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getIceServers({
    int ttlSeconds = 3600,
  }) async {
    try {
      final response = await _dio.get(
        '/api/users/rtc/ice-servers',
        queryParameters: {'ttl': ttlSeconds},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final iceServers =
            (data['iceServers'] as List?)
                ?.whereType<Map>()
                .map((entry) => Map<String, dynamic>.from(entry))
                .toList(growable: false) ??
            <Map<String, dynamic>>[];

        return ApiResponse(
          success: true,
          data: iceServers,
          message: 'ICE server configuration loaded',
        );
      }

      return ApiResponse(
        success: false,
        error: response.data['error'] ?? 'Failed to fetch ICE servers',
      );
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error fetching ICE servers',
      );
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getCallHistory() async {
    try {
      final response = await _dio.get('/api/calls/history');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final calls =
            (data['calls'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        return ApiResponse(
          success: true,
          data: calls,
          message: 'Call history retrieved',
        );
      } else {
        return ApiResponse(
          success: false,
          error: response.data['error'] ?? 'Failed to get call history',
        );
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error retrieving call history',
      );
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getOngoingCalls() async {
    try {
      final response = await _dio.get('/api/calls/ongoing');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final calls =
            (data['calls'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        return ApiResponse(
          success: true,
          data: calls,
          message: 'Ongoing calls retrieved',
        );
      } else {
        return ApiResponse(
          success: false,
          error: response.data['error'] ?? 'Failed to get ongoing calls',
        );
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error retrieving ongoing calls',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updateCallMetrics({
    required String callId,
    required Map<String, dynamic> metrics,
  }) async {
    try {
      final response = await _dio.post(
        '/api/calls/$callId/metrics',
        data: metrics,
      );

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: response.data,
          message: response.data['message'] ?? 'Metrics updated',
        );
      } else {
        return ApiResponse(
          success: false,
          error: response.data['error'] ?? 'Metrics update failed',
        );
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error updating metrics',
      );
    }
  }

  // Doctor APIs
  Future<ApiResponse<Map<String, dynamic>>> getDoctorProfile(
    String doctorId,
  ) async {
    try {
      final response = await _dio.get('/api/users/doctors/$doctorId');

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: response.data,
          message: 'Doctor profile retrieved',
        );
      } else {
        return ApiResponse(
          success: false,
          error: response.data['error'] ?? 'Doctor not found',
        );
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error retrieving doctor profile',
      );
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getAvailableDoctors({
    String? specialization,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (specialization != null) {
        queryParams['specialization'] = specialization;
      }
      queryParams['sortBy'] = 'rating';

      final response = await _dio.get(
        '/api/users/doctors/available',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final doctors =
            (data['doctors'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        return ApiResponse(
          success: true,
          data: doctors,
          message: 'Available doctors retrieved',
        );
      } else {
        return ApiResponse(
          success: false,
          error: response.data['error'] ?? 'Failed to fetch doctors',
        );
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error retrieving available doctors',
      );
    }
  }

  // Appointment APIs
  Future<ApiResponse<List<Map<String, dynamic>>>> getAppointments() async {
    try {
      final response = await _dio.get('/api/users/appointments');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final appointments =
            (data['appointments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        return ApiResponse(
          success: true,
          data: appointments,
          message: 'Appointments retrieved',
        );
      } else {
        return ApiResponse(
          success: false,
          error: response.data['error'] ?? 'Failed to fetch appointments',
        );
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error retrieving appointments',
      );
    }
  }

  // ---------- notifications/admin ----------
  Future<ApiResponse<List<Map<String, dynamic>>>> getNotifications() async {
    try {
      final response = await _dio.get('/api/users/notifications');
      debugPrint(
        '🔔 Notifications Response: ${response.statusCode} - ${response.data}',
      );
      if (response.statusCode == 200) {
        if (response.data is! Map<String, dynamic>) {
          return ApiResponse(success: false, error: 'Invalid response format');
        }
        final notifList = response.data['notifications'];
        if (notifList is! List) {
          return ApiResponse(
            success: false,
            error: 'Invalid notifications format',
          );
        }
        final notes = notifList.cast<Map<String, dynamic>>();
        return ApiResponse(success: true, data: notes);
      }
      if (response.data is Map && response.data['error'] != null) {
        return ApiResponse(
          success: false,
          error: response.data['error'].toString(),
        );
      }
      return ApiResponse(
        success: false,
        error: 'Failed to load notifications (Status: ${response.statusCode})',
      );
    } on DioException catch (e) {
      debugPrint('🔴 Notifications Error: ${e.message} - ${e.response?.data}');
      String errorMsg = 'Network error fetching notifications';
      if (e.response?.data is Map && e.response?.data['error'] != null) {
        errorMsg = e.response!.data['error'].toString();
      } else if (e.message != null) {
        errorMsg = e.message!;
      }
      return ApiResponse(success: false, error: errorMsg);
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getAllUsers() async {
    try {
      final response = await _dio.get('/api/users/admin/users');
      if (response.statusCode == 200) {
        final users =
            (response.data['users'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
        return ApiResponse(success: true, data: users);
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Error fetching users',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> adminDeleteUser(
    String userId,
  ) async {
    try {
      final response = await _dio.delete('/api/users/admin/users/$userId');
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: response.data);
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Error deleting user',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> adminSendNotification({
    required String target,
    required String message,
  }) async {
    try {
      final response = await _dio.post(
        '/api/users/admin/notify',
        data: {'target': target, 'message': message},
      );
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: response.data);
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Error sending notification',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> bookAppointment({
    required String doctorId,
    required DateTime slotTime,
    required String reason,
  }) async {
    try {
      final response = await _dio.post(
        '/api/users/appointments/book',
        data: {
          'doctorId': doctorId,
          'slotTime': slotTime.toIso8601String(),
          'reason': reason,
        },
      );

      if (response.statusCode == 201) {
        return ApiResponse(
          success: true,
          data: response.data,
          message: response.data['message'] ?? 'Appointment booked',
        );
      } else {
        return ApiResponse(
          success: false,
          error: response.data['error'] ?? 'Appointment booking failed',
        );
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error booking appointment',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updateAppointmentStatus(
    String appointmentId,
    String status,
  ) async {
    try {
      final response = await _dio.put(
        '/api/users/appointments/$appointmentId',
        data: {'status': status},
      );

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: response.data,
          message: 'Appointment status updated',
        );
      } else {
        return ApiResponse(
          success: false,
          error: response.data['error'] ?? 'Status update failed',
        );
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error updating appointment',
      );
    }
  }

  // ---------- health metrics ----------
  Future<ApiResponse<List<Map<String, dynamic>>>> getPatientMetrics(
    String patientId,
  ) async {
    try {
      final response = await _dio.get('/api/users/patients/$patientId/metrics');
      if (response.statusCode == 200) {
        final list =
            (response.data['metrics'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
        return ApiResponse(success: true, data: list);
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Error fetching metrics',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> postPatientMetric(
    String patientId,
    String metric,
    dynamic value,
  ) async {
    try {
      final response = await _dio.post(
        '/api/users/patients/$patientId/metrics',
        data: {'metric': metric, 'value': value},
      );
      if (response.statusCode == 201) {
        return ApiResponse(success: true, data: response.data);
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Error posting metric',
      );
    }
  }

  // ---------- chats ----------
  Future<ApiResponse<Map<String, dynamic>>> startChat(
    List<String> participants,
  ) async {
    try {
      final response = await _dio.post(
        '/api/chats/start',
        data: {'participants': participants},
      );
      if (response.statusCode == 201) {
        return ApiResponse(success: true, data: response.data);
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Error starting chat',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> sendChatMessage(
    String chatId,
    String text,
  ) async {
    try {
      final response = await _dio.post(
        '/api/chats/$chatId/message',
        data: {'text': text},
      );
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: response.data);
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Error sending message',
      );
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getMyChats() async {
    try {
      final response = await _dio.get('/api/chats');
      if (response.statusCode == 200) {
        final chats =
            (response.data['chats'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
        return ApiResponse(success: true, data: chats);
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Error fetching chats',
      );
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getChatMessages(
    String chatId,
  ) async {
    try {
      final response = await _dio.get('/api/chats/$chatId/messages');
      if (response.statusCode == 200) {
        final msgs =
            (response.data['messages'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        return ApiResponse(success: true, data: msgs);
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Error fetching messages',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> uploadReport(
    String appointmentId,
    String filePath,
  ) async {
    try {
      final formData = FormData.fromMap({
        'report': await MultipartFile.fromFile(filePath),
      });

      final response = await _dio.post(
        '/api/users/appointments/$appointmentId/report',
        data: formData,
      );

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: response.data,
          message: 'Report uploaded successfully',
        );
      } else {
        return ApiResponse(
          success: false,
          error: response.data['error'] ?? 'Report upload failed',
        );
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error uploading report',
      );
    }
  }

  // ---------- prescriptions ----------
  Future<ApiResponse<List<Map<String, dynamic>>>> getPrescriptions() async {
    try {
      final response = await _dio.get('/api/prescriptions');
      if (response.statusCode == 200) {
        final raw = response.data;
        final list = ((raw['prescriptions'] ?? raw['data'] ?? []) as List)
            .cast<Map<String, dynamic>>();
        return ApiResponse(success: true, data: list);
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Error fetching prescriptions',
      );
    }
  }

  /// Upload a report from raw bytes (web-compatible; works on all platforms).
  Future<ApiResponse<Map<String, dynamic>>> uploadReportBytes(
    String appointmentId,
    List<int> bytes,
    String filename,
  ) async {
    try {
      final formData = FormData.fromMap({
        'report': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final response = await _dio.post(
        '/api/users/appointments/$appointmentId/report',
        data: formData,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(
          success: true,
          data: response.data,
          message: 'Report uploaded',
        );
      }
      return ApiResponse(
        success: false,
        error: response.data['error'] ?? 'Upload failed',
      );
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error uploading report',
      );
    }
  }

  // Metrics APIs
  Future<ApiResponse<Map<String, dynamic>>> getCallMetrics(
    String callId,
  ) async {
    try {
      final response = await _dio.get('/api/metrics/call/$callId');

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: response.data,
          message: 'Call metrics retrieved',
        );
      } else {
        return ApiResponse(
          success: false,
          error: response.data['error'] ?? 'Failed to fetch metrics',
        );
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error retrieving metrics',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getUserStatistics() async {
    try {
      final response = await _dio.get('/api/metrics/user/stats');

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: response.data,
          message: 'User statistics retrieved',
        );
      } else {
        return ApiResponse(
          success: false,
          error: response.data['error'] ?? 'Failed to fetch statistics',
        );
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error retrieving statistics',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getNetworkPerformance({
    int days = 7,
  }) async {
    try {
      final response = await _dio.get(
        '/api/metrics/network/performance',
        queryParameters: {'days': days},
      );

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: response.data,
          message: 'Network performance data retrieved',
        );
      } else {
        return ApiResponse(
          success: false,
          error: response.data['error'] ?? 'Failed to fetch performance data',
        );
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error retrieving performance data',
      );
    }
  }

  // Auth Utility Methods
  Future<ApiResponse<Map<String, dynamic>>> refreshToken(
    String currentToken,
  ) async {
    try {
      final response = await _dio.post(
        '/api/auth/refresh',
        data: {'token': currentToken},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['token'] != null) {
          setAuthToken(data['token']);
        }
        return ApiResponse(
          success: true,
          data: data,
          message: 'Token refreshed',
        );
      } else {
        return ApiResponse(
          success: false,
          error: response.data['error'] ?? 'Token refresh failed',
        );
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error refreshing token',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> logout() async {
    try {
      final response = await _dio.post('/api/auth/logout');

      _authToken = null;

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: response.data,
          message: 'Logged out successfully',
        );
      } else {
        return ApiResponse(
          success: false,
          error: response.data['error'] ?? 'Logout failed',
        );
      }
    } on DioException catch (e) {
      _authToken = null;
      return ApiResponse(
        success: false,
        error: e.message ?? 'Network error during logout',
      );
    }
  }

  String? getAuthToken() => _authToken;

  Future<ApiResponse<Map<String, dynamic>>> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        '/api/auth/reset-password',
        data: {'email': email, 'newPassword': newPassword},
      );
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: response.data as Map<String, dynamic>,
          message: 'Password reset successfully',
        );
      }
      return ApiResponse(
        success: false,
        error:
            (response.data as Map<String, dynamic>?)?['error'] ??
            'Reset failed',
      );
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error:
            e.response?.data?['error']?.toString() ??
            e.message ??
            'Network error',
      );
    }
  }
}
