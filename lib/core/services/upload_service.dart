import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../models/audio_chunk.dart';
import '../repositories/api_repository.dart';
import '../repositories/local_storage_repository.dart';
import '../config/api_config.dart';
import '../utils/logger.dart';
import '../utils/validation.dart';
import 'session_service.dart';

class UploadService {
  final ApiRepository _apiRepository;
  final LocalStorageRepository _localStorage;
  final SessionService? _sessionService;
  final Connectivity _connectivity = Connectivity();
  
  StreamController<UploadProgress>? _progressController;
  bool _isUploading = false;
  Timer? _retryTimer;
  
  final Map<String, int> _sessionChunkCounts = {};
  final Set<String> _uploadingChunks = {};
  final Map<String, String> _sessionIdMap = {};
  
  UploadService({
    ApiRepository? apiRepository,
    LocalStorageRepository? localStorage,
    SessionService? sessionService,
  })  : _apiRepository = apiRepository ?? ApiRepository(),
        _localStorage = localStorage ?? LocalStorageRepository(),
        _sessionService = sessionService {
    _progressController = StreamController<UploadProgress>.broadcast();
    _monitorConnectivity();
  }

  Stream<UploadProgress> get progressStream => _progressController!.stream;

  void _monitorConnectivity() {
    _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none && !_isUploading) {
        _processPendingChunks();
      }
    });
  }

  Future<void> uploadChunk(AudioChunk chunk, {bool isLast = false}) async {
    if (_uploadingChunks.contains(chunk.chunkId)) {
      AppLogger.warning('Chunk ${chunk.chunkId} is already being uploaded, skipping');
      return;
    }
    
    _uploadingChunks.add(chunk.chunkId);
    
    try {
      AppLogger.debug('Saving chunk ${chunk.chunkId} to local storage for session ${chunk.sessionId}');
    await _localStorage.saveChunk(chunk.copyWith(status: 'pending'));
    
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _progressController?.add(UploadProgress(
        chunkId: chunk.chunkId,
        status: 'queued',
        message: 'No network connection',
      ));
      return;
    }

    try {
      final updatedChunk = chunk.copyWith(status: 'uploading');
      await _localStorage.saveChunk(updatedChunk);
      _progressController?.add(UploadProgress(
        chunkId: chunk.chunkId,
        status: 'uploading',
      ));

      final currentSessionId = _sessionIdMap[chunk.sessionId] ?? chunk.sessionId;
      
      final presignedUrlData = await _apiRepository.getPresignedUrl(
        sessionId: currentSessionId,
          chunkNumber: chunk.sequenceNumber,
        mimeType: 'audio/wav',
      );

        String? presignedUrl = Validation.getString(presignedUrlData, 'url');
        final gcsPath = Validation.getString(presignedUrlData, 'gcsPath');
        String? publicUrl = Validation.getString(presignedUrlData, 'publicUrl');

        if (presignedUrl == null) {
          throw Exception('Presigned URL is null');
        }
        if (gcsPath == null) {
          throw Exception('GCS path is null');
        }

      final baseUrl = ApiConfig.getBaseUrlForPlatform();
        try {
      if (presignedUrl.contains('localhost') || presignedUrl.startsWith('http://')) {
        final localhostUri = Uri.parse(presignedUrl);
        final path = localhostUri.path;
        final query = localhostUri.query;
        final fullPath = query.isNotEmpty ? '$path?$query' : path;
        presignedUrl = '$baseUrl$fullPath';
            AppLogger.debug('Fixed presigned URL from ${localhostUri.toString()} to $presignedUrl');
      }
      if (publicUrl != null && (publicUrl.contains('localhost') || publicUrl.startsWith('http://'))) {
        final localhostUri = Uri.parse(publicUrl);
        final path = localhostUri.path;
        final query = localhostUri.query;
        final fullPath = query.isNotEmpty ? '$path?$query' : path;
        publicUrl = '$baseUrl$fullPath';
            AppLogger.debug('Fixed public URL from ${localhostUri.toString()} to $publicUrl');
          }
        } catch (e) {
          AppLogger.warning('Failed to parse base URL: $e');
      }

        final finalPresignedUrl = presignedUrl!;
      await _apiRepository.uploadChunk(
          presignedUrl: finalPresignedUrl,
        filePath: chunk.filePath,
      );

      final sessionIdForCounts = _sessionIdMap[chunk.sessionId] ?? chunk.sessionId;
      _sessionChunkCounts[sessionIdForCounts] = 
          (_sessionChunkCounts[sessionIdForCounts] ?? 0) + 1;
      final totalChunks = _sessionChunkCounts[sessionIdForCounts] ?? chunk.sequenceNumber + 1;

      final effectiveSessionId = _sessionIdMap[chunk.sessionId] ?? chunk.sessionId;
      
      await _apiRepository.notifyChunkUploaded(
        sessionId: effectiveSessionId,
        gcsPath: gcsPath,
        chunkNumber: chunk.sequenceNumber,
          isLast: isLast,
        totalChunksClient: totalChunks,
        publicUrl: publicUrl,
        mimeType: 'audio/wav',
        model: 'fast',
      );

      final successChunk = updatedChunk.copyWith(
        status: 'uploaded',
        presignedUrl: presignedUrl,
      );
      await _localStorage.saveChunk(successChunk);

      _progressController?.add(UploadProgress(
        chunkId: chunk.chunkId,
        status: 'uploaded',
      ));

        AppLogger.info('Successfully uploaded chunk ${chunk.chunkId} (sequence ${chunk.sequenceNumber})');
    } catch (e) {
      final isSessionNotFound = _isSessionNotFoundError(e);
      
      if (isSessionNotFound && _sessionService != null) {
        try {
          AppLogger.info('Session not found, attempting to recreate session ${chunk.sessionId}');
          final newSessionId = await _recreateSession(chunk.sessionId);
          
          if (newSessionId != null) {
            _sessionIdMap[chunk.sessionId] = newSessionId;
            
            final updatedChunk = chunk.copyWith(sessionId: newSessionId);
            await _localStorage.saveChunk(updatedChunk);
            
            AppLogger.info('Session recreated: ${chunk.sessionId} -> $newSessionId, retrying upload');
            
            await uploadChunk(updatedChunk, isLast: isLast);
            return;
          }
        } catch (recreateError) {
          AppLogger.error('Failed to recreate session: $recreateError');
        }
      }
      
      final retryCount = chunk.retryCount + 1;
        const maxRetries = 5;

      if (retryCount < maxRetries) {
        final delaySeconds = 1 << retryCount;
        
        final failedChunk = chunk.copyWith(
          status: 'failed',
          retryCount: retryCount,
          errorMessage: e.toString(),
        );
        await _localStorage.saveChunk(failedChunk);

        _progressController?.add(UploadProgress(
          chunkId: chunk.chunkId,
          status: 'failed',
          message: 'Retrying in ${delaySeconds}s (attempt $retryCount/$maxRetries)',
        ));

          AppLogger.warning('Chunk ${chunk.chunkId} upload failed, retrying in ${delaySeconds}s: $e');

          await Future.delayed(Duration(seconds: delaySeconds));
          await uploadChunk(failedChunk, isLast: isLast);
      } else {
        final finalChunk = chunk.copyWith(
          status: 'failed',
          retryCount: retryCount,
          errorMessage: 'Max retries reached: ${e.toString()}',
        );
        await _localStorage.saveChunk(finalChunk);

        _progressController?.add(UploadProgress(
          chunkId: chunk.chunkId,
          status: 'failed',
          message: 'Max retries reached',
        ));
          
          AppLogger.error('Chunk ${chunk.chunkId} failed after $maxRetries retries', e);
        }
      }
    } finally {
      _uploadingChunks.remove(chunk.chunkId);
    }
  }

  Future<void> _processPendingChunks() async {
    if (_isUploading) {
      AppLogger.debug('Upload already in progress, skipping');
      return;
    }
    _isUploading = true;

    try {
      final pendingChunks = await _localStorage.getAllPendingChunks();
      
      if (pendingChunks.isEmpty) {
        AppLogger.debug('No pending chunks to upload');
        return;
      }
      
      AppLogger.info('Processing ${pendingChunks.length} pending chunks');
      
      for (final chunk in pendingChunks) {
        try {
        await uploadChunk(chunk);
        await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          AppLogger.error('Error processing chunk ${chunk.chunkId}', e);
        }
      }
    } finally {
      _isUploading = false;
    }
  }

  Future<void> processPendingChunks() => _processPendingChunks();

  bool _isSessionNotFoundError(dynamic error) {
    if (error is DioException) {
      if (error.response?.statusCode == 404) {
        final responseData = error.response?.data;
        if (responseData is Map<String, dynamic>) {
          final errorMessage = responseData['error'] as String?;
          return errorMessage?.toLowerCase().contains('session not found') ?? false;
        } else if (responseData is String) {
          return responseData.toLowerCase().contains('session not found');
        }
      }
    } else if (error is Exception) {
      final errorString = error.toString().toLowerCase();
      return errorString.contains('session not found') || 
             (errorString.contains('404') && errorString.contains('session'));
    }
    return false;
  }

  Future<String?> _recreateSession(String oldSessionId) async {
    try {
      final session = await _localStorage.getSession(oldSessionId);
      if (session == null) {
        AppLogger.warning('Cannot recreate session: session not found in local storage');
        return null;
      }

      final newSession = await _sessionService!.createSession(
        userId: session.userId,
        patientId: session.patientId,
        patientName: null,
        templateId: null,
      );

      AppLogger.info('Recreated session: $oldSessionId -> ${newSession.sessionId}');
      
      final chunks = await _localStorage.getChunksBySession(oldSessionId);
      for (final chunk in chunks) {
        if (chunk.status != 'uploaded') {
          final updatedChunk = chunk.copyWith(sessionId: newSession.sessionId);
          await _localStorage.saveChunk(updatedChunk);
        }
      }

      return newSession.sessionId;
    } catch (e) {
      AppLogger.error('Failed to recreate session: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    _retryTimer?.cancel();
    await _progressController?.close();
  }
}

class UploadProgress {
  final String chunkId;
  final String status;
  final String? message;

  UploadProgress({
    required this.chunkId,
    required this.status,
    this.message,
  });
}

