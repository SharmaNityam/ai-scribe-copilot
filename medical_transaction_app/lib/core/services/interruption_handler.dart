import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:phone_state/phone_state.dart';
import 'package:permission_handler/permission_handler.dart';
import 'audio_recorder_service.dart';
import 'session_service.dart';
import 'upload_service.dart';
import 'transcription_service.dart';
import '../utils/logger.dart';

class InterruptionHandler {
  final AudioRecorderService _audioRecorder;
  final SessionService _sessionService;
  final UploadService _uploadService;
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<AppLifecycleState>? _lifecycleSubscription;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  StreamSubscription<PhoneState>? _phoneStateSubscription;
  MethodChannel? _platformChannel;

  bool _wasRecordingBeforeCall = false;
  String? _currentSessionId;
  
  Function(bool isPaused)? _onPhoneCallStateChanged;

  InterruptionHandler({
    required AudioRecorderService audioRecorder,
    required SessionService sessionService,
    required UploadService uploadService,
    TranscriptionService? transcriptionService,
    Function(bool isPaused)? onPhoneCallStateChanged,
  })  : _audioRecorder = audioRecorder,
        _sessionService = sessionService,
        _uploadService = uploadService,
        _onPhoneCallStateChanged = onPhoneCallStateChanged {
    _initialize();
  }
  
  void setPhoneCallStateCallback(Function(bool isPaused) callback) {
    _onPhoneCallStateChanged = callback;
  }

  void _initialize() {
    _setupLifecycleListener();
    
    _setupConnectivityListener();
    
    _setupPhoneStateListener().catchError((error, stackTrace) {
      AppLogger.error('Failed to initialize phone state listener', error, stackTrace);
    });
    
    _setupPlatformChannel();
  }

  void _setupLifecycleListener() {
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (result) {
        if (result != ConnectivityResult.none) {
          _uploadService.processPendingChunks();
        }
      },
    );
  }

  Future<void> _setupPhoneStateListener() async {
    try {
      AppLogger.info('📞 Setting up phone state listener using phone_state package');
      
      if (Platform.isAndroid) {
        AppLogger.info('📞 Requesting READ_PHONE_STATE permission...');
        final status = await Permission.phone.request();
        if (status.isGranted) {
          AppLogger.info('📞 READ_PHONE_STATE permission granted');
        } else {
          AppLogger.warning('📞 READ_PHONE_STATE permission denied: $status');
          AppLogger.warning('📞 Phone call detection may not work without this permission');
        }
      }
      
      AppLogger.info('📞 Subscribing to PhoneState.stream...');
      _phoneStateSubscription = PhoneState.stream.listen(
        (PhoneState state) {
          AppLogger.info('📞 Phone state changed: ${state.status}');
          AppLogger.info('📞 Phone state details: number=${state.number}');
          
          switch (state.status) {
            case PhoneStateStatus.CALL_INCOMING:
              AppLogger.info('📞 Incoming call detected - number: ${state.number}');
              break;
            case PhoneStateStatus.CALL_STARTED:
              AppLogger.info('🔴 Call started (answered) - pausing recording');
              handlePhoneCallStart();
              break;
            case PhoneStateStatus.CALL_ENDED:
              AppLogger.info('🟢 Call ended - resuming recording');
              handlePhoneCallEnd();
              break;
            default:
              AppLogger.debug('📞 Phone state: ${state.status}');
              break;
          }
        },
        onError: (error, stackTrace) {
          AppLogger.error('❌ Error in phone state stream', error, stackTrace);
          AppLogger.warning('📞 Phone state stream error - falling back to native detection');
        },
        onDone: () {
          AppLogger.warning('📞 Phone state stream closed');
        },
        cancelOnError: false,
      );
      AppLogger.info('📞 Phone state listener set up successfully - subscription active');
    } catch (e, stackTrace) {
      AppLogger.error('❌ Failed to set up phone state listener', e, stackTrace);
      AppLogger.warning('📞 Falling back to native platform channel detection');
    }
  }

  void _setupPlatformChannel() {
    _platformChannel = const MethodChannel('com.aiscribe.interruptions');
    _platformChannel?.setMethodCallHandler(_handlePlatformCall);
  }

  Future<void> _handlePlatformCall(MethodCall call) async {
    switch (call.method) {
      case 'onPhoneCallStarted':
        await handlePhoneCallStart();
        break;
      case 'onPhoneCallEnded':
        await handlePhoneCallEnd();
        break;
      default:
        break;
    }
  }

  Future<void> handlePhoneCallStart() async {
    AppLogger.info('🔴 Phone call started - checking recording state');
    AppLogger.info('🔴 isRecording=${_audioRecorder.isRecording}, isPaused=${_audioRecorder.isPaused}');
    
    if (_audioRecorder.isRecording && !_audioRecorder.isPaused) {
      AppLogger.info('🔴 Recording is active, pausing due to phone call');
      _wasRecordingBeforeCall = true;
      _currentSessionId = await _getCurrentSessionId();
      
      AppLogger.info('🔴 Calling phone call state callback with isPaused=true (BEFORE pausing recorder)');
      if (_onPhoneCallStateChanged != null) {
        try {
          _onPhoneCallStateChanged!(true);
          AppLogger.info('🔴 Phone call state callback completed successfully');
        } catch (e, stackTrace) {
          AppLogger.error('🔴 Error in phone call state callback', e, stackTrace);
        }
      } else {
        AppLogger.warning('🔴 Phone call state callback is NULL!');
      }
      
      await _audioRecorder.pause();
      AppLogger.info('🔴 Audio recorder paused due to phone call');
      
      if (_currentSessionId != null) {
        await _sessionService.pauseSession(_currentSessionId!);
        AppLogger.info('🔴 Session paused: $_currentSessionId');
      } else {
        AppLogger.warning('🔴 No current session ID found when pausing for phone call');
      }
    } else {
      AppLogger.debug('🔴 Recording not active or already paused, no action needed');
    }
  }

  Future<void> handlePhoneCallEnd() async {
    AppLogger.info('🟢 Phone call ended - checking if should resume');
    if (_wasRecordingBeforeCall) {
      AppLogger.info('🟢 Was recording before call, resuming recording');
      
      if (_currentSessionId != null) {
        await _audioRecorder.resume();
        AppLogger.info('🟢 Audio recorder resumed after phone call');
        
        AppLogger.info('🟢 Calling phone call state callback with isPaused=false');
        if (_onPhoneCallStateChanged != null) {
          try {
            _onPhoneCallStateChanged!(false);
            AppLogger.info('🟢 Phone call state callback completed successfully');
          } catch (e, stackTrace) {
            AppLogger.error('🟢 Error in phone call state callback', e, stackTrace);
          }
        } else {
          AppLogger.warning('🟢 Phone call state callback is NULL!');
        }
        
        await _sessionService.resumeSession(_currentSessionId!);
        AppLogger.info('🟢 Session resumed: $_currentSessionId');
        
        _wasRecordingBeforeCall = false;
        _currentSessionId = null;
      } else {
        AppLogger.warning('🟢 No session ID found when resuming after phone call');
        _wasRecordingBeforeCall = false;
      }
    } else {
      AppLogger.debug('🟢 Was not recording before call, no action needed');
    }
  }

  Future<void> handleAppPaused() async {
  }

  Future<void> handleAppResumed() async {
    try {
    await _uploadService.processPendingChunks();
    
    final recoveredSession = await _sessionService.recoverSession();
    if (recoveredSession != null) {
        AppLogger.info('Recovered session on app resume: ${recoveredSession.sessionId}');
      }
    } catch (e) {
      AppLogger.error('Error handling app resume', e);
    }
  }

  Future<void> handleAppDetached() async {
    try {
      if (_audioRecorder.isRecording) {
        final sessionId = await _getCurrentSessionId();
        if (sessionId != null) {
          final session = await _sessionService.getSession(sessionId);
          if (session != null) {
            await _sessionService.updateSession(session);
            AppLogger.info('Saved session state before app detach: $sessionId');
          }
        }
      }
    } catch (e) {
      AppLogger.error('Error saving state on app detach', e);
    }
  }

  Future<String?> _getCurrentSessionId() async {
    final activeSessions = await _sessionService.getActiveSessions();
    if (activeSessions.isNotEmpty) {
      return activeSessions.first.sessionId;
    }
    return null;
  }

  Future<void> dispose() async {
    await _lifecycleSubscription?.cancel();
    await _connectivitySubscription?.cancel();
    await _phoneStateSubscription?.cancel();
  }
}

