import 'dart:io';
import 'package:dio/dio.dart';
import '../models/session.dart';
import '../models/patient.dart';
import '../config/api_config.dart';
import '../utils/logger.dart';
import '../utils/validation.dart';

class ApiRepository {
  final Dio _dio;
  final String baseUrl;
  String? _authToken;

  ApiRepository({String? baseUrl, String? authToken})
      : baseUrl = baseUrl ?? ApiConfig.getBaseUrlForPlatform(),
        _authToken = authToken,
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? ApiConfig.getBaseUrlForPlatform(),
          connectTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 120),
          headers: {
            'Content-Type': 'application/json',
          },
        )) {
    const bool isDebug = bool.fromEnvironment('dart.vm.product') == false;
    if (isDebug) {
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
        logPrint: (object) => AppLogger.debug(object.toString()),
    ));
    }
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        AppLogger.error(
          'API Error: ${error.requestOptions.path}',
          error,
          error.stackTrace,
        );
        handler.next(error);
      },
    ));
  }

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Future<Map<String, dynamic>> createUploadSession({
    required String userId,
    String? patientId,
    String? patientName,
    String? templateId,
  }) async {
    if (!Validation.isNotEmpty(userId)) {
      throw ArgumentError('userId cannot be empty');
    }
    
    try {
    final response = await _dio.post(
      '/v1/upload-session',
      data: {
        'userId': userId,
        if (patientId != null) 'patientId': patientId,
        if (patientName != null) 'patientName': patientName,
        'status': 'recording',
        'startTime': DateTime.now().toIso8601String(),
        if (templateId != null) 'templateId': templateId,
      },
    );
      
      final data = response.data;
      if (!Validation.isValidApiResponse(data)) {
        throw Exception('Invalid API response: empty or null');
      }
      
      if (Validation.getString(data, 'id') == null) {
        throw Exception('API response missing required field: id');
      }
      
      return data;
    } on DioException catch (e) {
      AppLogger.error('Failed to create upload session', e);
      throw Exception('Failed to create upload session: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> getPresignedUrl({
    required String sessionId,
    required int chunkNumber,
    String mimeType = 'audio/wav',
  }) async {
    if (!Validation.isNotEmpty(sessionId)) {
      throw ArgumentError('sessionId cannot be empty');
    }
    if (chunkNumber < 0) {
      throw ArgumentError('chunkNumber must be non-negative');
    }
    
    try {
    final response = await _dio.post(
      '/v1/get-presigned-url',
      data: {
        'sessionId': sessionId,
        'chunkNumber': chunkNumber,
        'mimeType': mimeType,
      },
    );
      
      final data = response.data;
      if (!Validation.isValidApiResponse(data)) {
        throw Exception('Invalid API response: empty or null');
      }
      
      if (Validation.getString(data, 'url') == null) {
        throw Exception('API response missing required field: url');
      }
      if (Validation.getString(data, 'gcsPath') == null) {
        throw Exception('API response missing required field: gcsPath');
      }
      
      return data;
    } on DioException catch (e) {
      AppLogger.error('Failed to get presigned URL', e);
      throw Exception('Failed to get presigned URL: ${e.message}');
    }
  }

  Future<void> uploadChunk({
    required String presignedUrl,
    required String filePath,
  }) async {
    if (!Validation.isNotEmpty(presignedUrl)) {
      throw ArgumentError('presignedUrl cannot be empty');
    }
    if (!Validation.isNotEmpty(filePath)) {
      throw ArgumentError('filePath cannot be empty');
    }
    
    try {
      final uri = Uri.parse(presignedUrl);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        throw ArgumentError('Invalid presigned URL scheme: ${uri.scheme}');
      }
      
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileSystemException('File not found', filePath);
      }
      
    final audioData = await file.readAsBytes();
      
      if (audioData.isEmpty) {
        throw Exception('Audio file is empty');
      }

      AppLogger.debug('Uploading chunk to: $presignedUrl (${audioData.length} bytes)');

    await _dio.put(
      presignedUrl,
      data: audioData,
      options: Options(
        headers: {
          'Content-Type': 'audio/wav',
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        },
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
      
      AppLogger.debug('Successfully uploaded chunk: $filePath');
    } on DioException catch (e) {
      AppLogger.error('Failed to upload chunk', e);
      throw Exception('Failed to upload chunk: ${e.message}');
    } on FileSystemException catch (e) {
      AppLogger.error('File system error during upload', e);
      rethrow;
    }
  }

  Future<void> notifyChunkUploaded({
    required String sessionId,
    required String gcsPath,
    required int chunkNumber,
    required bool isLast,
    required int totalChunksClient,
    String? publicUrl,
    String mimeType = 'audio/wav',
    String? selectedTemplate,
    String? selectedTemplateId,
    String model = 'fast',
  }) async {
    await _dio.post(
      '/v1/notify-chunk-uploaded',
      data: {
        'sessionId': sessionId,
        'gcsPath': gcsPath,
        'chunkNumber': chunkNumber,
        'isLast': isLast,
        'totalChunksClient': totalChunksClient,
        if (publicUrl != null) 'publicUrl': publicUrl,
        'mimeType': mimeType,
        if (selectedTemplate != null) 'selectedTemplate': selectedTemplate,
        if (selectedTemplateId != null) 'selectedTemplateId': selectedTemplateId,
        'model': model,
      },
    );
  }

  // Patient Management

  Future<List<Patient>> getPatients(String userId) async {
    if (!Validation.isNotEmpty(userId)) {
      throw ArgumentError('userId cannot be empty');
    }
    
    try {
    final response = await _dio.get(
      '/v1/patients',
      queryParameters: {'userId': userId},
    );
      
    final data = response.data;
      if (data == null || data is! Map<String, dynamic>) {
        AppLogger.warning('Invalid response format for getPatients');
        return [];
      }
      
      final patientsList = Validation.getList<dynamic>(data, 'patients');
      if (patientsList == null) {
        return [];
      }
      
      return patientsList
          .map((json) {
            try {
              return Patient.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              AppLogger.warning('Failed to parse patient: $e');
              return null;
            }
          })
          .whereType<Patient>()
          .toList();
    } on DioException catch (e) {
      AppLogger.error('Failed to get patients', e);
      throw Exception('Failed to get patients: ${e.message}');
    }
  }

  Future<Patient> addPatient(Patient patient) async {
    if (!Validation.isNotEmpty(patient.name)) {
      throw ArgumentError('Patient name cannot be empty');
    }
    if (patient.email != null && !Validation.isValidEmail(patient.email)) {
      throw ArgumentError('Invalid email format');
    }
    if (patient.phoneNumber != null && !Validation.isValidPhoneNumber(patient.phoneNumber)) {
      throw ArgumentError('Invalid phone number format');
    }
    
    try {
    final response = await _dio.post(
      '/v1/add-patient-ext',
      data: patient.toJson(),
    );
      
      final data = response.data;
      if (data == null || data is! Map<String, dynamic>) {
        throw Exception('Invalid API response format');
      }
      
      final patientData = data['patient'];
      if (patientData == null || patientData is! Map<String, dynamic>) {
        throw Exception('API response missing patient data');
      }
      
      return Patient.fromJson(patientData);
    } on DioException catch (e) {
      AppLogger.error('Failed to add patient', e);
      throw Exception('Failed to add patient: ${e.message}');
    }
  }

  Future<List<RecordingSession>> getSessionsByPatient(String patientId) async {
    if (!Validation.isNotEmpty(patientId)) {
      throw ArgumentError('patientId cannot be empty');
    }
    
    try {
    final response = await _dio.get(
      '/v1/fetch-session-by-patient/$patientId',
    );
      
    final data = response.data;
      if (data == null || data is! Map<String, dynamic>) {
        AppLogger.warning('Invalid response format for getSessionsByPatient');
        return [];
      }
      
      final sessionsList = Validation.getList<dynamic>(data, 'sessions');
      if (sessionsList == null) {
        return [];
      }
      
      return sessionsList
          .map((json) {
            try {
              return RecordingSession.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              AppLogger.warning('Failed to parse session: $e');
              return null;
            }
          })
          .whereType<RecordingSession>()
          .toList();
    } on DioException catch (e) {
      AppLogger.error('Failed to get sessions by patient', e);
      throw Exception('Failed to get sessions: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> getPatientDetails(String patientId) async {
    final response = await _dio.get('/v1/patient-details/$patientId');
    return response.data;
  }

  Future<Map<String, dynamic>> getAllSessions(String userId) async {
    final response = await _dio.get(
      '/v1/all-session',
      queryParameters: {'userId': userId},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getUserTemplates(String userId) async {
    final response = await _dio.get(
      '/v1/fetch-default-template-ext',
      queryParameters: {'userId': userId},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getUserByEmail(String email) async {
    if (!Validation.isValidEmail(email)) {
      throw ArgumentError('Invalid email format');
    }
    
    try {
    final response = await _dio.get(
      '/users/asd3fd2faec',
      queryParameters: {'email': email},
    );
      
      final data = response.data;
      if (!Validation.isValidApiResponse(data)) {
        throw Exception('Invalid API response');
      }
      
      return data;
    } on DioException catch (e) {
      AppLogger.error('Failed to get user by email', e);
      throw Exception('Failed to get user: ${e.message}');
    }
  }
}

