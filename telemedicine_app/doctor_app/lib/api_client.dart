import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Simplified API client for the doctor app.
/// You can extend this as needed to mirror the patient-side implementation.
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final dynamic error;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.error,
  });
}

class TeleMedicineApiClient {
  String? _authToken;
  String? currentUserId; // holds logged-in user's id (doctor id if doctor)
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
          return handler.next(error);
        },
      ),
    );
  }

  void setAuthToken(String token) {
    _authToken = token;
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
        final token = data['token'] as String?;
        if (token != null) {
          setAuthToken(token);
        }
        return ApiResponse(
          success: true,
          data: data,
          message: data['message'] ?? 'Login successful',
        );
      } else {
        final errorMsg = response.data is Map
            ? (response.data['error'] ?? 'Login failed')
            : 'Login failed';
        return ApiResponse(success: false, error: errorMsg);
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.response?.data['error'] ?? e.message ?? 'Network error',
      );
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getAppointments() async {
    try {
      final response = await _dio.get('/api/users/appointments');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final appts = (data['appointments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        return ApiResponse(success: true, data: appts);
      } else {
        final errorMsg = response.data is Map
            ? (response.data['error'] ?? 'Failed to fetch appointments')
            : 'Failed to fetch appointments';
        return ApiResponse(success: false, error: errorMsg);
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.response?.data['error'] ?? e.message ?? 'Network error',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? specialization,
  }) async {
    try {
      final data = {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      };
      if (specialization != null && specialization.isNotEmpty) {
        data['specialization'] = specialization;
      }

      final response = await _dio.post(
        '/api/auth/register',
        data: data,
      );

      if (response.statusCode == 201) {
        return ApiResponse(
          success: true,
          data: response.data as Map<String, dynamic>?,
          message: response.data['message'] ?? 'Registration successful',
        );
      } else {
        final errorMsg = response.data is Map
            ? (response.data['error'] ?? 'Registration failed')
            : 'Registration failed';
        return ApiResponse(
          success: false,
          error: errorMsg,
        );
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.response?.data['error'] ?? e.message ?? 'Network error',
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
        return ApiResponse(success: true, data: response.data);
      } else {
        return ApiResponse(success: false, error: response.data['error']);
      }
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updateDoctorProfile({
    required String doctorId,
    String? bio,
    String? specialization,
    String? qualification,
    int? yearsOfExperience,
    double? consultationFee,
    List<String>? availableSlots,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (bio != null) data['bio'] = bio;
      if (specialization != null) data['specialization'] = specialization;
      if (qualification != null) data['qualification'] = qualification;
      if (yearsOfExperience != null) data['yearsOfExperience'] = yearsOfExperience;
      if (consultationFee != null) data['consultationFee'] = consultationFee;
      if (availableSlots != null) data['availableSlots'] = availableSlots;

      final response = await _dio.put(
        '/api/users/doctors/$doctorId',
        data: data,
      );

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: response.data,
          message: response.data['message'] ?? 'Profile updated successfully',
        );
      } else {
        final errorMsg = response.data is Map
            ? (response.data['error'] ?? 'Profile update failed')
            : 'Profile update failed';
        return ApiResponse(success: false, error: errorMsg);
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.response?.data['error'] ?? e.message ?? 'Network error',
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

      final errorMsg = response.data is Map
          ? (response.data['error'] ?? 'Failed to fetch ICE servers')
          : 'Failed to fetch ICE servers';
      return ApiResponse(success: false, error: errorMsg);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.response?.data['error'] ?? e.message ?? 'Network error',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getDoctorProfile(String doctorId) async {
    try {
      final response = await _dio.get('/api/users/doctors/$doctorId');
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: response.data as Map<String, dynamic>?);
      } else {
        return ApiResponse(success: false, error: response.data['error'] ?? 'Doctor not found');
      }
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message);
    }
  }

  // ---------- health metrics (doctors may read patient metrics) ----------
  Future<ApiResponse<List<Map<String, dynamic>>>> getPatientMetrics(String patientId) async {
    try {
      final response = await _dio.get('/api/users/patients/$patientId/metrics');
      if (response.statusCode == 200) {
        final list = (response.data['metrics'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        return ApiResponse(success: true, data: list);
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message);
    }
  }

  // ---------- chats ----------
  Future<ApiResponse<Map<String, dynamic>>> startChat(List<String> participants) async {
    try {
      final response = await _dio.post('/api/chats/start', data: {'participants': participants});
      if (response.statusCode == 201) return ApiResponse(success: true, data: response.data);
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> sendChatMessage(String chatId, String text) async {
    try {
      final response = await _dio.post('/api/chats/$chatId/message', data: {'text': text});
      if (response.statusCode == 200) return ApiResponse(success: true, data: response.data);
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message);
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getChatMessages(String chatId) async {
    try {
      final response = await _dio.get('/api/chats/$chatId/messages');
      if (response.statusCode == 200) {
        final msgs = (response.data['messages'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        return ApiResponse(success: true, data: msgs);
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message);
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getMyChats() async {
    try {
      final response = await _dio.get('/api/chats');
      if (response.statusCode == 200) {
        final chats = (response.data['chats'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        return ApiResponse(success: true, data: chats);
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message);
    }
  }

  // ADMIN / NOTIFICATIONS
  Future<ApiResponse<List<Map<String, dynamic>>>> getNotifications() async {
    try {
      final response = await _dio.get('/api/users/notifications');
      debugPrint('🔔 Notifications Response: ${response.statusCode} - ${response.data}');
      if (response.statusCode == 200) {
        if (response.data is! Map<String, dynamic>) {
          return ApiResponse(success: false, error: 'Invalid response format');
        }
        final notifList = response.data['notifications'];
        if (notifList is! List) {
          return ApiResponse(success: false, error: 'Invalid notifications format');
        }
        final notes = notifList.cast<Map<String, dynamic>>();
        return ApiResponse(success: true, data: notes);
      }
      if (response.data is Map && response.data['error'] != null) {
        return ApiResponse(success: false, error: response.data['error'].toString());
      }
      return ApiResponse(success: false, error: 'Failed to load notifications (Status: ${response.statusCode})');
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
        final users = (response.data['users'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        return ApiResponse(success: true, data: users);
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> adminDeleteUser(String userId) async {
    try {
      final response = await _dio.delete('/api/users/admin/users/$userId');
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: response.data);
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> adminSendNotification({
    required String target,
    required String message,
  }) async {
    try {
      final response = await _dio.post('/api/users/admin/notify', data: {
        'target': target,
        'message': message,
      });
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: response.data);
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> deleteDoctorAccount(String doctorId) async {
    try {
      final response = await _dio.delete('/api/users/doctors/$doctorId');
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: response.data as Map<String, dynamic>?,
          message: response.data['message'] ?? 'Account deleted',
        );
      } else {
        return ApiResponse(success: false, error: response.data['error'] ?? 'Deletion failed');
      }
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.response?.data['error'] ?? e.message ?? 'Network error');
    }
  }

  // ---------- Prescriptions ----------
  Future<ApiResponse<List<Map<String, dynamic>>>> getPrescriptions() async {
    try {
      final response = await _dio.get('/api/prescriptions');
      if (response.statusCode == 200) {
        final data = response.data;
        List<Map<String, dynamic>> list = [];
        if (data is Map && data['prescriptions'] is List) {
          list = (data['prescriptions'] as List).cast<Map<String, dynamic>>();
        } else if (data is List) {
          list = data.cast<Map<String, dynamic>>();
        }
        return ApiResponse(success: true, data: list);
      }
      return ApiResponse(success: false, error: response.data['error'] ?? 'Failed to load prescriptions');
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> createPrescription({
    required String patientId,
    required String diagnosis,
    required List<Map<String, String>> medications,
    String? notes,
  }) async {
    try {
      final body = {
        'patientId': patientId,
        'diagnosis': diagnosis,
        'medications': medications,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };
      final response = await _dio.post('/api/prescriptions', data: body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return ApiResponse(success: true, data: response.data as Map<String, dynamic>?);
      }
      return ApiResponse(success: false, error: response.data['error'] ?? 'Failed to create prescription');
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message);
    }
  }
}
