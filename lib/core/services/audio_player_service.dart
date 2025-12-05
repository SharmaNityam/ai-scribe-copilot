import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import '../models/audio_chunk.dart';
import '../repositories/local_storage_repository.dart';
import '../utils/logger.dart';

class AudioPlayerService {
  AudioPlayer _audioPlayer = AudioPlayer();
  final LocalStorageRepository _localStorage = LocalStorageRepository();
  
  bool _isPlaying = false;
  bool _isPaused = false;
  List<AudioChunk> _chunks = [];
  int _currentChunkIndex = 0;
  int _retryCount = 0; // Track retries per chunk
  Duration _totalDuration = Duration.zero;
  List<Duration> _chunkDurations = [];
  
  // Guards to prevent race conditions
  bool _isLoadingChunk = false;
  bool _isTransitioning = false;
  Completer<void>? _currentLoadCompleter;
  
  StreamController<Duration>? _positionController;
  StreamController<Duration>? _durationController;
  StreamController<bool>? _playingStateController;
  
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;
  
  Stream<Duration>? get positionStream => _positionController?.stream;
  Stream<Duration>? get durationStream => _durationController?.stream;
  Stream<bool>? get playingStateStream => _playingStateController?.stream;
  
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  
  AudioPlayerService() {
    _setupListeners();
  }
  
  void _setupListeners() {
    // Cancel existing subscriptions if any
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _stateSubscription?.cancel();
    
    _positionController ??= StreamController<Duration>.broadcast();
    _durationController ??= StreamController<Duration>.broadcast();
    _playingStateController ??= StreamController<bool>.broadcast();
    
    // Listen to position updates
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      // Calculate total position: sum of previous chunks + current chunk position
      Duration totalPosition = Duration.zero;
      for (int i = 0; i < _currentChunkIndex; i++) {
        if (i < _chunkDurations.length) {
          totalPosition += _chunkDurations[i];
        }
      }
      totalPosition += position;
      _positionController?.add(totalPosition);
    });
    
    // Listen to duration updates
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      // Store duration for current chunk
      if (_currentChunkIndex < _chunkDurations.length) {
        _chunkDurations[_currentChunkIndex] = duration;
      } else {
        _chunkDurations.add(duration);
      }
      
      // Calculate total duration
      _totalDuration = _chunkDurations.fold<Duration>(
        Duration.zero,
        (sum, d) => sum + d,
      );
      
      _durationController?.add(_totalDuration);
    });
    
    // Listen to state changes
    _stateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) async {
      final wasPlaying = _isPlaying;
      _isPlaying = state == PlayerState.playing;
      _isPaused = state == PlayerState.paused;
      
      if (wasPlaying != _isPlaying) {
        _playingStateController?.add(_isPlaying);
      }
      
      // Auto-advance to next chunk when current finishes
      // Only advance if we're not already transitioning and not loading
      if (state == PlayerState.completed && !_isTransitioning && !_isLoadingChunk) {
        AppLogger.debug('Chunk $_currentChunkIndex completed, advancing to next...');
        _isTransitioning = true;
        try {
        _currentChunkIndex++;
        if (_currentChunkIndex < _chunks.length) {
            // Wait a bit longer to ensure player is fully stopped
          await Future.delayed(const Duration(milliseconds: 100));
          await _playChunk(_currentChunkIndex);
        } else {
            AppLogger.debug('All chunks completed');
          _isPlaying = false;
          _playingStateController?.add(false);
          _positionController?.add(_totalDuration);
          }
        } finally {
          _isTransitioning = false;
        }
      }
    });
  }
  
  Future<void> loadSession(String sessionId) async {
    // Get all chunks for this session (including uploaded ones)
    final allChunks = await _localStorage.getChunksBySession(sessionId);
    
    // Sort by sequence number
    allChunks.sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
    
    _chunks = allChunks;
    _currentChunkIndex = 0;
    _chunkDurations = List.filled(_chunks.length, Duration.zero);
    _totalDuration = Duration.zero;
    
    AppLogger.info('Loaded ${_chunks.length} chunks for session $sessionId');
    
    if (_chunks.isEmpty) {
      throw Exception('No audio chunks found for this session. Make sure you recorded for at least a few seconds.');
    }
    
    // Verify at least one file exists
    bool hasPlayableChunk = false;
    for (final chunk in _chunks) {
      final file = File(chunk.filePath);
      if (await file.exists()) {
        hasPlayableChunk = true;
        break;
      }
    }
    
    if (!hasPlayableChunk) {
      throw Exception('Audio files not found. The recording may have been too short or files were deleted.');
    }
    
    // Pre-load durations for all chunks to calculate total duration
    await _preloadDurations();
  }
  
  Future<void> _preloadDurations() async {
    Duration total = Duration.zero;
    for (int i = 0; i < _chunks.length; i++) {
      final chunk = _chunks[i];
      final file = File(chunk.filePath);
      if (await file.exists()) {
        try {
          // Create a temporary player to get duration
          final tempPlayer = AudioPlayer();
          await tempPlayer.setSource(DeviceFileSource(file.path));
          final duration = await tempPlayer.getDuration();
          await tempPlayer.dispose();
          
          if (duration != null) {
            _chunkDurations[i] = duration;
            total += duration;
            AppLogger.debug('Chunk $i duration: ${duration.inSeconds}s');
          }
        } catch (e) {
          AppLogger.warning('Could not get duration for chunk $i: $e');
        }
      }
    }
    _totalDuration = total;
    AppLogger.debug('Total duration: ${_totalDuration.inSeconds}s');
    _durationController?.add(_totalDuration);
  }
  
  Future<void> play() async {
    if (_chunks.isEmpty) {
      throw Exception('No audio chunks loaded');
    }
    
    if (_isPlaying && !_isPaused) {
      return; // Already playing
    }
    
    if (_isPaused) {
      // Resume from pause
      await _audioPlayer.resume();
      return;
    }
    
    // Start playing from current chunk
    await _playChunk(_currentChunkIndex);
  }
  
  Future<void> _playChunk(int chunkIndex) async {
    // Prevent concurrent calls to _playChunk
    if (_isLoadingChunk) {
      AppLogger.debug('Already loading a chunk, ignoring duplicate call for chunk $chunkIndex');
      return;
    }
    
    if (chunkIndex >= _chunks.length) {
      // Finished playing all chunks
      await stop();
      return;
    }
    
    _isLoadingChunk = true;
    _currentLoadCompleter = Completer<void>();
    
    try {
    final chunk = _chunks[chunkIndex];
    final file = File(chunk.filePath);
    
    if (!await file.exists()) {
      // Log missing file for debugging
        AppLogger.warning('File not found: ${file.path}');
      // Try next chunk
        _currentChunkIndex = chunkIndex + 1;
      if (_currentChunkIndex < _chunks.length) {
          _isLoadingChunk = false;
          await Future.delayed(const Duration(milliseconds: 50));
        await _playChunk(_currentChunkIndex);
      } else {
        // No more chunks available
        await stop();
        throw Exception('No playable audio chunks found. Files may have been deleted.');
      }
      return;
    }
    
      // Check file size - skip if file is too small (likely corrupted or incomplete)
      final fileSize = await file.length();
      if (fileSize < 1000) { // Less than 1KB is likely corrupted
        AppLogger.warning('Skipping chunk ${chunkIndex + 1}: file too small (${fileSize} bytes)');
        _currentChunkIndex = chunkIndex + 1;
        if (_currentChunkIndex < _chunks.length) {
          _isLoadingChunk = false;
          await Future.delayed(const Duration(milliseconds: 50));
          await _playChunk(_currentChunkIndex);
        } else {
          await stop();
        }
        return;
      }
      
      _currentChunkIndex = chunkIndex;
      AppLogger.debug('Playing chunk ${chunkIndex + 1}/${_chunks.length}: ${file.path} (${(fileSize / 1024).toStringAsFixed(2)} KB)');
      
      // Stop and reset player properly before loading new source
      try {
        if (_isPlaying || _audioPlayer.state != PlayerState.stopped) {
          await _audioPlayer.stop();
        }
        // Wait for player to fully stop
        await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
        // Ignore errors when stopping - player might already be stopped
        AppLogger.debug('Error stopping player (ignored): $e');
      }
      
      // Set source with timeout
      try {
        await _audioPlayer.setSource(DeviceFileSource(file.path))
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                throw TimeoutException('setSource timed out after 5 seconds for chunk ${chunkIndex + 1}');
              },
            );
        
        // Small delay to ensure source is set
        await Future.delayed(const Duration(milliseconds: 50));
        
        // Start playing
        await _audioPlayer.resume();
        _retryCount = 0; // Reset retry count on success
      } on TimeoutException catch (e) {
        AppLogger.warning('Timeout loading chunk ${chunkIndex + 1}, skipping: $e');
        // Skip this chunk and move to next
        _currentChunkIndex = chunkIndex + 1;
        if (_currentChunkIndex < _chunks.length) {
          _isLoadingChunk = false;
          await Future.delayed(const Duration(milliseconds: 100));
          await _playChunk(_currentChunkIndex);
        } else {
          await stop();
        }
        return;
      } on PlatformException catch (e) {
        // Handle IllegalStateException and other platform errors
        if (e.code == 'AndroidAudioError' || e.message?.contains('IllegalStateException') == true) {
          AppLogger.warning('MediaPlayer state error for chunk ${chunkIndex + 1}: ${e.message}');
          
          // Try to recover by recreating the player
          if (_retryCount < 1) {
            _retryCount++;
            try {
              await _audioPlayer.dispose();
              await Future.delayed(const Duration(milliseconds: 200));
              
              // Recreate player to reset state
              _audioPlayer = AudioPlayer();
              _setupListeners();
              
              AppLogger.info('Recreated audio player after state error');
              
              // Retry with new player
              _isLoadingChunk = false;
              await Future.delayed(const Duration(milliseconds: 100));
              await _playChunk(chunkIndex);
              return;
            } catch (recoveryError) {
              _retryCount = 0;
              AppLogger.error('Failed to recover from state error', recoveryError);
            }
          }
          
          // Skip this chunk after retry failure
          _retryCount = 0;
          AppLogger.warning('Skipping chunk ${chunkIndex + 1} after state error');
          _currentChunkIndex = chunkIndex + 1;
          if (_currentChunkIndex < _chunks.length) {
            _isLoadingChunk = false;
            await Future.delayed(const Duration(milliseconds: 100));
            await _playChunk(_currentChunkIndex);
          } else {
            _isPlaying = false;
            _playingStateController?.add(false);
          }
          return;
        }
        rethrow; // Re-throw if it's not a state error
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error playing chunk ${chunkIndex + 1}', e, stackTrace);
      
      // Try to recover by creating a new player instance (only once per chunk)
      if (_retryCount < 1) {
        _retryCount++;
        try {
          await _audioPlayer.dispose();
          await Future.delayed(const Duration(milliseconds: 200));
          
          // Recreate player to reset state
          _audioPlayer = AudioPlayer();
          _setupListeners();
          
          AppLogger.info('Recreated audio player after error');
          
          // Try playing the chunk again with new player
          _isLoadingChunk = false;
          await Future.delayed(const Duration(milliseconds: 100));
          await _playChunk(chunkIndex);
          return; // Success, exit
        } catch (recoveryError) {
          _retryCount = 0; // Reset on failure
          AppLogger.error('Failed to recover from player error', recoveryError);
        }
      }
      
      // Skip this chunk and move to next
      _retryCount = 0; // Reset
      AppLogger.warning('Skipping chunk ${chunkIndex + 1} after retry failure');
      _currentChunkIndex = chunkIndex + 1;
      if (_currentChunkIndex < _chunks.length) {
        _isLoadingChunk = false;
        await Future.delayed(const Duration(milliseconds: 100));
        await _playChunk(_currentChunkIndex);
      } else {
      _isPlaying = false;
      _playingStateController?.add(false);
      }
    } finally {
      _isLoadingChunk = false;
      _currentLoadCompleter?.complete();
      _currentLoadCompleter = null;
    }
  }
  
  Future<void> pause() async {
    if (!_isPlaying || _isPaused) return;
    await _audioPlayer.pause();
  }
  
  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentChunkIndex = 0;
    _retryCount = 0; // Reset retry count
    _positionController?.add(Duration.zero);
  }
  
  Future<void> seek(Duration position) async {
    // Find which chunk this position falls into
    Duration accumulated = Duration.zero;
    int targetChunkIndex = 0;
    Duration positionInChunk = position;
    
    for (int i = 0; i < _chunkDurations.length; i++) {
      if (position < accumulated + _chunkDurations[i]) {
        targetChunkIndex = i;
        positionInChunk = position - accumulated;
        break;
      }
      accumulated += _chunkDurations[i];
    }
    
    // If we need to switch chunks
    if (targetChunkIndex != _currentChunkIndex) {
      await stop();
      _currentChunkIndex = targetChunkIndex;
      await _playChunk(_currentChunkIndex);
      // Wait a bit for the player to be ready
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    // Seek within the current chunk
    await _audioPlayer.seek(positionInChunk);
  }
  
  Future<void> dispose() async {
    await stop();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _stateSubscription?.cancel();
    await _audioPlayer.dispose();
    await _positionController?.close();
    await _durationController?.close();
    await _playingStateController?.close();
    _positionController = null;
    _durationController = null;
    _playingStateController = null;
  }
}

