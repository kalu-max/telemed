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
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
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

      if (response.statusCode == 200 || response.statusCode == 201) {
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
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(success: true, data: response.data);
      }
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

  Future<ApiResponse<Map<String, dynamic>>> sendChatMedia(String chatId, String filePath) async {
    try {
      final formData = FormData.fromMap({'image': await MultipartFile.fromFile(filePath)});
      final response = await _dio.post('/api/chats/$chatId/message/media', data: formData);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(success: true, data: Map<String, dynamic>.from(response.data ?? {}));
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message ?? 'Error uploading media');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> requestPasswordOtp(String email) async {
    try {
      final response = await _dio.post('/api/auth/request-otp', data: {'email': email});
      if (response.statusCode == 200) return ApiResponse(success: true, data: Map<String, dynamic>.from(response.data ?? {}));
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message ?? 'Error requesting OTP');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> resetPasswordWithOtp(String email, String otp, String newPassword) async {
    try {
      final response = await _dio.post('/api/auth/reset-password', data: {'email': email, 'otp': otp, 'newPassword': newPassword});
      if (response.statusCode == 200) return ApiResponse(success: true, data: Map<String, dynamic>.from(response.data ?? {}));
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message ?? 'Error resetting password');
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

  // ---- Doctor Availability Slots ----

  Future<ApiResponse<Map<String, dynamic>>> getDoctorAvailability(String doctorId) async {
    try {
      final response = await _dio.get('/api/users/doctors/$doctorId/availability');
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: Map<String, dynamic>.from(response.data ?? {}));
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message ?? 'Error fetching availability');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updateDoctorAvailability(
    String doctorId,
    List<Map<String, dynamic>> slots,
  ) async {
    try {
      final response = await _dio.put('/api/users/doctors/$doctorId/availability', data: {'slots': slots});
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: Map<String, dynamic>.from(response.data ?? {}));
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message ?? 'Error updating availability');
    }
  }

  // ---- Search ----

  Future<ApiResponse<Map<String, dynamic>>> search(String query) async {
    try {
      final response = await _dio.get('/api/users/search', queryParameters: {'q': query});
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: Map<String, dynamic>.from(response.data ?? {}));
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message ?? 'Error searching');
    }
  }

  // ---- File sharing in chat ----

  Future<ApiResponse<Map<String, dynamic>>> sendChatFile(
    String chatId,
    String filePath,
    {String? caption}
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        if (caption != null) 'caption': caption,
      });
      final response = await _dio.post(
        '/api/chats/$chatId/message/file',
        data: formData,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(success: true, data: Map<String, dynamic>.from(response.data ?? {}));
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message ?? 'Error uploading file');
    }
  }

  // ---- FCM Token Registration ----

  Future<ApiResponse<Map<String, dynamic>>> registerFcmToken(String token) async {
    try {
      final response = await _dio.post('/api/users/fcm-token', data: {'token': token});
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: Map<String, dynamic>.from(response.data ?? {}));
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message ?? 'Error registering FCM token');
    }
  }

  // ---- Missed Calls ----

  Future<ApiResponse<Map<String, dynamic>>> getMissedCalls() async {
    try {
      final response = await _dio.get('/api/calls/missed');
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: Map<String, dynamic>.from(response.data ?? {}));
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message ?? 'Error fetching missed calls');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> requestCallback({
    required String targetUserId,
    required String type,
    String? message,
  }) async {
    try {
      final response = await _dio.post('/api/calls/callback-request', data: {
        'targetUserId': targetUserId,
        'type': type,
        if (message != null) 'message': message,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(success: true, data: Map<String, dynamic>.from(response.data ?? {}));
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message ?? 'Error requesting callback');
    }
  }

  // ---- Medical Records ----

  Future<ApiResponse<Map<String, dynamic>>> getMedicalRecords({String? patientId}) async {
    try {
      final params = <String, dynamic>{};
      if (patientId != null) params['patientId'] = patientId;
      final response = await _dio.get('/api/users/medical-records', queryParameters: params);
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: Map<String, dynamic>.from(response.data ?? {}));
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message ?? 'Error fetching records');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> createMedicalRecord({
    required String patientId,
    required String diagnosis,
    String? treatment,
    String? consultationId,
  }) async {
    try {
      final response = await _dio.post('/api/users/medical-records', data: {
        'patientId': patientId,
        'diagnosis': diagnosis,
        if (treatment != null) 'treatment': treatment,
        if (consultationId != null) 'consultationId': consultationId,
      });
      if (response.statusCode == 201) {
        return ApiResponse(success: true, data: Map<String, dynamic>.from(response.data ?? {}));
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message ?? 'Error creating record');
    }
  }

  // ---- Doctor Reviews ----

  Future<ApiResponse<Map<String, dynamic>>> getDoctorReviews(String doctorId) async {
    try {
      final response = await _dio.get('/api/users/doctors/$doctorId/reviews');
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: Map<String, dynamic>.from(response.data ?? {}));
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message ?? 'Error fetching reviews');
    }
  }

  // ---- Chat Message Search ----

  Future<ApiResponse<Map<String, dynamic>>> searchChatMessages(String chatId, String query) async {
    try {
      final response = await _dio.get('/api/users/chats/$chatId/search', queryParameters: {'q': query});
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: Map<String, dynamic>.from(response.data ?? {}));
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message ?? 'Error searching');
    }
  }

  // ---- Consultation Notes ----

  Future<ApiResponse<Map<String, dynamic>>> getConsultationNotes(String consultationId) async {
    try {
      final response = await _dio.get('/api/users/consultations/$consultationId/notes');
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: Map<String, dynamic>.from(response.data ?? {}));
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message ?? 'Error fetching notes');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updateConsultationNotes(String consultationId, String notes) async {
    try {
      final response = await _dio.put('/api/users/consultations/$consultationId/notes', data: {'notes': notes});
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: Map<String, dynamic>.from(response.data ?? {}));
      }
      return ApiResponse(success: false, error: response.data['error']);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message ?? 'Error updating notes');
    }
  }
}
