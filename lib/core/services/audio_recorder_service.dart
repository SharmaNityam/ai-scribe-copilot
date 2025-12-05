import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/audio_chunk.dart';
import '../utils/logger.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  final Uuid _uuid = const Uuid();
  static const MethodChannel _channel = MethodChannel('com.example.medical_transaction_app/recording');
  
  StreamController<double>? _amplitudeController;
  StreamController<AudioChunk>? _chunkController;
  StreamController<bool>? _recordingStateController;
  
  Timer? _chunkTimer;
  String? _currentSessionId;
  int _currentSequenceNumber = 0;
  String? _currentFilePath;
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isCreatingChunk = false;
  
  Stream<bool>? get recordingStateStream => _recordingStateController?.stream;
  
  static const int chunkDurationSeconds = 5;
  static const int sampleRate = 44100;
  static const int bitRate = 128000;
  
  double _gain = 1.0;
  
  double get gain => _gain;
  
  void setGain(double gain) {
    if (gain < 0.0 || gain > 1.0) {
      AppLogger.warning('Gain value $gain out of range, clamping to [0.0, 1.0]');
      _gain = gain.clamp(0.0, 1.0);
    } else {
      _gain = gain;
    }
    AppLogger.debug('Microphone gain set to: $_gain');
  }

  Stream<double>? get amplitudeStream => _amplitudeController?.stream;
  Stream<AudioChunk>? get chunkStream => _chunkController?.stream;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<bool> requestPermission() async {
    if (await hasPermission()) {
      return true;
    }
    
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      return true;
    }
    
    AppLogger.warning('Microphone permission denied');
    return false;
  }

  Future<void> startRecording(String sessionId) async {
    if (_isRecording) {
      throw Exception('Recording already in progress');
    }

    if (!await requestPermission()) {
      throw Exception('Microphone permission denied');
    }

    _currentSessionId = sessionId;
    _currentSequenceNumber = 0;
    _isRecording = true;
    _isPaused = false;

    _amplitudeController = StreamController<double>.broadcast();
    _chunkController = StreamController<AudioChunk>.broadcast();
    _recordingStateController = StreamController<bool>.broadcast();

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
        _currentFilePath = path.join(
          directory.path,
          'recordings',
          sessionId,
          'chunk_$timestamp.wav',
        );

    final file = File(_currentFilePath!);
    await file.parent.create(recursive: true);

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: sampleRate,
        bitRate: bitRate,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ),
      path: _currentFilePath!,
    );
    
    try {
      await WakelockPlus.enable();
      AppLogger.info('Wake lock enabled - recording will continue when screen is locked');
    } catch (e) {
      AppLogger.warning('Failed to enable wake lock: $e');
    }
    
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('startForegroundService');
        AppLogger.info('Foreground service started for background recording');
      } catch (e) {
        AppLogger.warning('Failed to start foreground service: $e');
      }
    }
    
    AppLogger.info('Recording started - background recording should be active');
    
    AppLogger.info('Started recording with gain: $_gain');

    _startAmplitudeMonitoring();
    _chunkTimer = Timer.periodic(
      const Duration(seconds: chunkDurationSeconds),
      (_) => _createChunk(),
    );
  }

  Timer? _amplitudeTimer;

  void _startAmplitudeMonitoring() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!_isRecording || _isPaused) {
        timer.cancel();
        _amplitudeTimer = null;
        return;
      }

      try {
        final amplitude = await _recorder.getAmplitude();
        final adjustedAmplitude = amplitude.current * _gain;
        _amplitudeController?.add(adjustedAmplitude);
      } catch (e) {
        AppLogger.debug('Amplitude monitoring error: $e');
      }
    });
  }

  Future<void> _createChunk() async {
    if (!_isRecording || _isPaused || _currentSessionId == null || _currentFilePath == null) {
      return;
    }

    if (_isCreatingChunk) {
      AppLogger.debug('Chunk creation already in progress, skipping');
      return;
    }

    _isCreatingChunk = true;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final nextFilePath = path.join(
        directory.path,
        'recordings',
        _currentSessionId!,
        'chunk_$timestamp.wav',
      );
      final nextFile = File(nextFilePath);
      await nextFile.parent.create(recursive: true);

      final previousPath = _currentFilePath;
      if (previousPath == null) {
        AppLogger.warning('Cannot create chunk: no file path');
        return;
      }
      
      await _recorder.stop();

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: sampleRate,
          bitRate: bitRate,
        ),
        path: nextFilePath,
      );
      
      _currentFilePath = nextFilePath;

      final chunkId = _uuid.v4();
      final file = File(previousPath);
      final fileSize = await file.exists() ? await file.length() : null;
      
      if (!await file.exists()) {
        AppLogger.warning('Chunk file does not exist: $previousPath');
        return;
      }
      
      final chunk = AudioChunk(
        chunkId: chunkId,
        sessionId: _currentSessionId!,
        sequenceNumber: _currentSequenceNumber++,
        filePath: previousPath,
        timestamp: DateTime.now(),
        fileSize: fileSize,
        status: 'pending',
      );

      if (_chunkController != null && !_chunkController!.isClosed) {
        _chunkController!.add(chunk);
        AppLogger.debug('Created chunk ${chunk.chunkId} (sequence ${chunk.sequenceNumber}), size: ${fileSize} bytes');
      } else {
        AppLogger.warning('Chunk controller is null or closed, chunk not sent');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error creating chunk', e, stackTrace);
      _chunkController?.addError(e);
      
      if (_isRecording && !_isPaused && _currentSessionId != null) {
        try {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        _currentFilePath = path.join(
          directory.path,
          'recordings',
          _currentSessionId!,
          'chunk_$timestamp.wav',
        );
        final file = File(_currentFilePath!);
        await file.parent.create(recursive: true);
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: sampleRate,
            bitRate: bitRate,
          ),
          path: _currentFilePath!,
        );
          AppLogger.info('Recovered recording after chunk creation error');
        } catch (recoveryError) {
          AppLogger.error('Failed to recover recording', recoveryError);
        }
      }
    } finally {
      _isCreatingChunk = false;
    }
  }

  Future<void> pause() async {
    if (!_isRecording || _isPaused) {
      return;
    }

    _isPaused = true;
    _chunkTimer?.cancel();
    await _recorder.pause();
    
    _recordingStateController?.add(true);
    
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('stopForegroundService');
        AppLogger.info('Foreground service stopped (paused)');
      } catch (e) {
        AppLogger.warning('Failed to stop foreground service: $e');
      }
    }
    
    try {
      await WakelockPlus.disable();
      AppLogger.info('Wake lock disabled (paused)');
    } catch (e) {
      AppLogger.warning('Failed to disable wake lock: $e');
    }
  }

  Future<void> resume() async {
    if (!_isRecording || !_isPaused) {
      return;
    }

    _isPaused = false;
    await _recorder.resume();

    _recordingStateController?.add(false);
    
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('startForegroundService');
        AppLogger.info('Foreground service started (resumed)');
      } catch (e) {
        AppLogger.warning('Failed to start foreground service: $e');
      }
    }
    
    // Re-enable wake lock when resuming
    try {
      await WakelockPlus.enable();
      AppLogger.info('Wake lock enabled (resumed)');
    } catch (e) {
        AppLogger.warning('Failed to enable wake lock: $e');
    }

    _chunkTimer?.cancel();
    _chunkTimer = Timer.periodic(
      const Duration(seconds: chunkDurationSeconds),
      (_) => _createChunk(),
    );
    
    AppLogger.info('Recording resumed - chunk timer restarted');
  }

  Future<String?> stop() async {
    if (!_isRecording) {
      return null;
    }

    _isRecording = false;
    _isPaused = false;
    _chunkTimer?.cancel();
    
    _recordingStateController?.add(false);
    
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('stopForegroundService');
        AppLogger.info('Foreground service stopped');
      } catch (e) {
        AppLogger.warning('Failed to stop foreground service: $e');
      }
    }
    
    try {
      await WakelockPlus.disable();
      AppLogger.info('Wake lock disabled');
    } catch (e) {
      AppLogger.warning('Failed to disable wake lock: $e');
    }
    
    final path = await _recorder.stop();
    
    AudioChunk? finalChunk;
    if (path != null && _currentSessionId != null) {
      final chunkId = _uuid.v4();
      finalChunk = AudioChunk(
        chunkId: chunkId,
        sessionId: _currentSessionId!,
        sequenceNumber: _currentSequenceNumber++,
        filePath: path,
        timestamp: DateTime.now(),
        status: 'pending',
      );
      
      AppLogger.info('Creating final chunk ${finalChunk.chunkId} for session ${finalChunk.sessionId}');
      if (_chunkController != null && !_chunkController!.isClosed) {
        _chunkController!.add(finalChunk);
        AppLogger.debug('Final chunk added to stream, waiting for listener...');
        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        AppLogger.warning('Chunk stream is null or closed, final chunk not sent!');
      }
    }

    // Cleanup
    _currentSessionId = null;
    _currentSequenceNumber = 0;
    _currentFilePath = null;

    await _amplitudeController?.close();
    await _chunkController?.close();
    _amplitudeController = null;
    _chunkController = null;

    return path;
  }

  Future<void> dispose() async {
    if (_isRecording) {
      await stop();
    }
    
    try {
      await WakelockPlus.disable();
      AppLogger.debug('Wake lock disabled on dispose');
    } catch (e) {
      AppLogger.debug('Error disabling wake lock on dispose: $e');
    }
    
    _chunkTimer?.cancel();
    _amplitudeTimer?.cancel();
    await _recorder.dispose();
    await _amplitudeController?.close();
    await _chunkController?.close();
    await _recordingStateController?.close();
    _amplitudeController = null;
    _chunkController = null;
    _recordingStateController = null;
  }

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
}

