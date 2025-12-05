import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/audio_recorder_service.dart';
import '../../core/services/session_service.dart';
import '../../core/services/upload_service.dart';
import '../../core/services/transcription_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/models/session.dart';
import '../../core/models/audio_chunk.dart';
import '../../core/utils/logger.dart';

class RecordingController extends ChangeNotifier {
  final AudioRecorderService _audioRecorder;
  final SessionService _sessionService;
  final UploadService _uploadService;
  final TranscriptionService _transcriptionService;

  RecordingSession? _currentSession;
  String? _currentPatientName; // Store patient name separately
  bool _isRecording = false;
  bool _isPaused = false;
  double _amplitude = 0.0;
  Duration _duration = Duration.zero;
  String _transcriptionText = '';
  Timer? _durationTimer;
  Timer? _pauseStateCheckTimer; // Periodic check for external pause/resume (e.g., phone calls)
  StreamSubscription<double>? _amplitudeSubscription;
  StreamSubscription<AudioChunk>? _chunkSubscription;
  StreamSubscription<UploadProgress>? _uploadSubscription;
  StreamSubscription<String>? _transcriptionSubscription;
  StreamSubscription<bool>? _recordingStateSubscription; // Listen to recorder's paused state

  RecordingController({
    required AudioRecorderService audioRecorder,
    required SessionService sessionService,
    required UploadService uploadService,
    required TranscriptionService transcriptionService,
  })  : _audioRecorder = audioRecorder,
        _sessionService = sessionService,
        _uploadService = uploadService,
        _transcriptionService = transcriptionService {
    _setupUploadListener();
    _setupTranscriptionListener();
  }
  
  void _setupTranscriptionListener() {
    _transcriptionSubscription = _transcriptionService.transcriptionStream.listen(
      (text) {
        _transcriptionText = text;
        notifyListeners();
      },
      onError: (error) {
        final errorStr = error.toString();
        if (!errorStr.contains('no_match') && !errorStr.contains('error_no_match')) {
          AppLogger.warning('Transcription error: $errorStr');
        } else {
          AppLogger.debug('Transcription: No speech detected (expected)');
        }
      },
    );
  }

  void _setupUploadListener() {
    _uploadSubscription = _uploadService.progressStream.listen((progress) {
      notifyListeners();
    });
  }

  bool _isStopping = false;
  int _totalChunksReceived = 0;

  void _setupChunkListener() {
    _chunkSubscription?.cancel();
    
    _chunkSubscription = _audioRecorder.chunkStream?.listen(
      (chunk) {
        _totalChunksReceived++;
        AppLogger.debug('Received chunk ${chunk.chunkId} (${_totalChunksReceived}) for session ${chunk.sessionId}');
        
        final isLast = _isStopping;
        
        _uploadService.uploadChunk(chunk, isLast: isLast).catchError((error, stackTrace) {
          AppLogger.error('Error uploading chunk', error, stackTrace);
        });
      },
      onError: (error, stackTrace) {
        AppLogger.error('Error in chunk stream', error, stackTrace);
      },
    );
    
    if (_chunkSubscription == null) {
      AppLogger.warning('chunkStream is null, listener not set up');
    }
  }

  RecordingSession? get currentSession => _currentSession;
  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  double get amplitude => _amplitude;
  Duration get duration => _duration;
  String get transcriptionText => _transcriptionText;
  double get gain => _audioRecorder.gain;
  
  void setGain(double gain) {
    _audioRecorder.setGain(gain);
    notifyListeners();
  }

  Future<void> startRecording({
    required String userId,
    String? patientId,
    String? patientName,
    String? templateId,
  }) async {
    if (_isRecording) return;

    try {
      _currentSession = await _sessionService.createSession(
        userId: userId,
        patientId: patientId,
        patientName: patientName,
        templateId: templateId,
      );
      _currentPatientName = patientName;

      await _audioRecorder.startRecording(_currentSession!.sessionId);
      
      _setupChunkListener();

      _isRecording = true;
      _isPaused = false;
      _duration = Duration.zero;

      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _duration = Duration(seconds: timer.tick);
        if (!_isPaused && _currentSession != null) {
          NotificationService.updateRecordingNotification(
            sessionId: _currentSession!.sessionId,
            patientName: _currentPatientName ?? 'Unknown Patient',
            isPaused: false,
            duration: _duration,
          );
        }
        notifyListeners();
      });

      _amplitudeSubscription = _audioRecorder.amplitudeStream?.listen((amp) {
        _amplitude = amp;
        notifyListeners();
      });

      _recordingStateSubscription = _audioRecorder.recordingStateStream?.listen((recorderIsPaused) async {
        AppLogger.info('Recording state stream: recorderIsPaused=$recorderIsPaused, controllerIsPaused=$_isPaused');
        await _syncPauseState(recorderIsPaused, 'recordingStateStream');
      });
      
      _pauseStateCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
        if (!_isRecording) {
          timer.cancel();
          return;
        }
        
        final recorderIsPaused = _audioRecorder.isPaused;
        if (_isPaused != recorderIsPaused) {
          AppLogger.info('⚠️ Pause state mismatch detected via periodic check: controller=$_isPaused, recorder=$recorderIsPaused');
          await _syncPauseState(recorderIsPaused, 'periodicCheck');
        }
      });

      await NotificationService.initialize();
      await NotificationService.showRecordingNotification(
        sessionId: _currentSession!.sessionId,
        patientName: patientName ?? 'Unknown Patient',
        isPaused: false,
        duration: _duration,
      );

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }


  Future<void> pause() async {
    if (!_isRecording || _isPaused) return;

    await _audioRecorder.pause();
    _isPaused = true;
    _durationTimer?.cancel();
    
    if (_currentSession != null) {
      await _sessionService.pauseSession(_currentSession!.sessionId);
      await NotificationService.updateRecordingNotification(
        sessionId: _currentSession!.sessionId,
        patientName: _currentPatientName ?? 'Unknown Patient',
        isPaused: true,
        duration: _duration,
      );
    }

    notifyListeners();
  }

  Future<void> resume() async {
    if (!_isRecording || !_isPaused) return;

    await _audioRecorder.resume();
    _isPaused = false;

    final elapsedSeconds = _duration.inSeconds;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _duration = Duration(seconds: elapsedSeconds + timer.tick);
      notifyListeners();
    });

    if (_currentSession != null) {
      await _sessionService.resumeSession(_currentSession!.sessionId);
      await NotificationService.updateRecordingNotification(
        sessionId: _currentSession!.sessionId,
        patientName: _currentPatientName ?? 'Unknown Patient',
        isPaused: false,
        duration: _duration,
      );
    }

    notifyListeners();
  }

  void handlePhoneCallPause() {
    AppLogger.info('handlePhoneCallPause called: isRecording=$_isRecording, isPaused=$_isPaused, duration=${_duration.inSeconds}s');
    if (!_isRecording || _isPaused) {
      AppLogger.warning('handlePhoneCallPause: Not recording or already paused, ignoring');
      return;
    }
    
    AppLogger.info('Handling phone call pause - stopping duration timer at ${_duration.inSeconds} seconds');
    _durationTimer?.cancel();
    _durationTimer = null;
    _isPaused = true;
    
    if (_currentSession != null) {
      NotificationService.updateRecordingNotification(
        sessionId: _currentSession!.sessionId,
        patientName: _currentPatientName ?? 'Unknown Patient',
        isPaused: true,
        duration: _duration,
      );
    }
    
    AppLogger.info('Duration timer cancelled, isPaused set to true, notification updated');
    notifyListeners();
  }

  void handlePhoneCallResume() {
    AppLogger.info('handlePhoneCallResume called: isRecording=$_isRecording, isPaused=$_isPaused, duration=${_duration.inSeconds}s');
    if (!_isRecording || !_isPaused) {
      AppLogger.warning('handlePhoneCallResume: Not recording or not paused, ignoring');
      return;
    }
    
    AppLogger.info('Handling phone call resume - restarting duration timer from ${_duration.inSeconds} seconds');
    _isPaused = false;
    final elapsedSeconds = _duration.inSeconds;
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _duration = Duration(seconds: elapsedSeconds + timer.tick);
        if (_currentSession != null) {
        NotificationService.updateRecordingNotification(
          sessionId: _currentSession!.sessionId,
          patientName: _currentPatientName ?? 'Unknown Patient',
          isPaused: false,
          duration: _duration,
        );
      }
      notifyListeners();
    });
    
    // Update notification immediately
    if (_currentSession != null) {
      NotificationService.updateRecordingNotification(
        sessionId: _currentSession!.sessionId,
        patientName: _currentPatientName ?? 'Unknown Patient',
        isPaused: false,
        duration: _duration,
      );
    }
    
    AppLogger.info('Duration timer restarted from $elapsedSeconds seconds, notification updated');
    notifyListeners();
  }
  
  Future<void> _syncPauseState(bool recorderIsPaused, String source) async {
    AppLogger.info('[$source] Syncing pause state: controller=$_isPaused, recorder=$recorderIsPaused');
    
    if (_isPaused == recorderIsPaused) {
      AppLogger.debug('[$source] State already in sync, no action needed');
      return;
    }
    
    AppLogger.info('[$source] State mismatch detected - syncing: controller=$_isPaused, recorder=$recorderIsPaused');
    _isPaused = recorderIsPaused;
    
    if (recorderIsPaused) {
      // Recording was paused (e.g., by phone call or audio focus loss)
      AppLogger.info('[$source] Pausing duration timer due to recording state change');
      _durationTimer?.cancel();
      _durationTimer = null; // Clear reference
      
      // Update notification to show paused state
      if (_currentSession != null) {
        await NotificationService.updateRecordingNotification(
          sessionId: _currentSession!.sessionId,
          patientName: _currentPatientName ?? 'Unknown Patient',
          isPaused: true,
          duration: _duration,
        );
      }
    } else {
      // Recording was resumed (e.g., after phone call)
      AppLogger.info('[$source] Resuming duration timer due to recording state change');
      final elapsedSeconds = _duration.inSeconds;
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _duration = Duration(seconds: elapsedSeconds + timer.tick);
        // Update notification with current duration
        if (_currentSession != null && !_isPaused) {
          NotificationService.updateRecordingNotification(
            sessionId: _currentSession!.sessionId,
            patientName: _currentPatientName ?? 'Unknown Patient',
            isPaused: false,
            duration: _duration,
          );
        }
        notifyListeners();
      });
      
      // Update notification to show resumed state
      if (_currentSession != null) {
        await NotificationService.updateRecordingNotification(
          sessionId: _currentSession!.sessionId,
          patientName: _currentPatientName ?? 'Unknown Patient',
          isPaused: false,
          duration: _duration,
        );
      }
    }
    notifyListeners();
  }

  Future<void> stop() async {
    if (!_isRecording) return;

    try {
      // Mark that we're stopping so the next chunk will be marked as last
      _isStopping = true;

    // Stop recording - this will create final chunk
      // The chunk listener will mark it as isLast: true
    await _audioRecorder.stop();
    
      // Give a moment for final chunk to be created and uploaded
      await Future.delayed(const Duration(milliseconds: 500));
    
    _durationTimer?.cancel();
    _pauseStateCheckTimer?.cancel();
    await _amplitudeSubscription?.cancel();
    // Transcription disabled - no need to stop
    // await _transcriptionService.stopListening();

    _isRecording = false;
    _isPaused = false;
      _isStopping = false;
      _totalChunksReceived = 0;
      _transcriptionText = '';

    if (_currentSession != null) {
      await _sessionService.completeSession(_currentSession!.sessionId);
      AppLogger.info('Completed session: ${_currentSession!.sessionId} with $_totalChunksReceived chunks');
    }

    // Cancel recording notification
    await NotificationService.cancelRecordingNotification();

    _currentSession = null;
    _currentPatientName = null;
    _duration = Duration.zero;
    _amplitude = 0.0;

    notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.error('Error stopping recording', e, stackTrace);
      _isStopping = false;
      rethrow;
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _pauseStateCheckTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _chunkSubscription?.cancel();
    _uploadSubscription?.cancel();
    _transcriptionSubscription?.cancel();
    _recordingStateSubscription?.cancel();
    super.dispose();
  }
}

