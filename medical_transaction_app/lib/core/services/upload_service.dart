import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/audio_chunk.dart';
import '../repositories/api_repository.dart';
import '../repositories/local_storage_repository.dart';
import '../config/api_config.dart';
import '../utils/logger.dart';
import '../utils/validation.dart';

class UploadService {
  final ApiRepository _apiRepository;
  final LocalStorageRepository _localStorage;
  final Connectivity _connectivity = Connectivity();
  
  StreamController<UploadProgress>? _progressController;
  bool _isUploading = false;
  Timer? _retryTimer;
  
  final Map<String, int> _sessionChunkCounts = {};
  final Set<String> _uploadingChunks = {};
  
  UploadService({
    ApiRepository? apiRepository,
    LocalStorageRepository? localStorage,
  })  : _apiRepository = apiRepository ?? ApiRepository(),
        _localStorage = localStorage ?? LocalStorageRepository() {
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

      final presignedUrlData = await _apiRepository.getPresignedUrl(
        sessionId: chunk.sessionId,
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
          final uri = Uri.parse(baseUrl);
      if (presignedUrl.contains('localhost')) {
        presignedUrl = presignedUrl.replaceAll('localhost', uri.host);
            AppLogger.debug('Fixed presigned URL from localhost to ${uri.host}');
      }
      if (publicUrl != null && publicUrl.contains('localhost')) {
        publicUrl = publicUrl.replaceAll('localhost', uri.host);
          }
        } catch (e) {
          AppLogger.warning('Failed to parse base URL: $e');
      }

        final finalPresignedUrl = presignedUrl!;
      await _apiRepository.uploadChunk(
          presignedUrl: finalPresignedUrl,
        filePath: chunk.filePath,
      );

        _sessionChunkCounts[chunk.sessionId] = 
            (_sessionChunkCounts[chunk.sessionId] ?? 0) + 1;
        final totalChunks = _sessionChunkCounts[chunk.sessionId] ?? chunk.sequenceNumber + 1;

      await _apiRepository.notifyChunkUploaded(
        sessionId: chunk.sessionId,
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

