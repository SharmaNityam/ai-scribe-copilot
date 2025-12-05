import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../utils/logger.dart';

class TranscriptionService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isAvailable = false;
  String _currentText = '';
  final StreamController<String> _transcriptionController = StreamController<String>.broadcast();
  
  Stream<String> get transcriptionStream => _transcriptionController.stream;
  String get currentText => _currentText;
  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;

  Future<bool> initialize() async {
    try {
      AppLogger.info('Initializing speech recognition...');
      _isAvailable = await _speech.initialize(
        onError: (error) {
          final errorMsg = error.errorMsg;
          final isPermanent = error.permanent;
          
          AppLogger.warning('Speech recognition error: $errorMsg (permanent: $isPermanent)');
          
          if (errorMsg == 'error_no_match' && !isPermanent) {
            AppLogger.debug('No speech match detected (expected during silence)');
            return;
          }
          
          if (errorMsg == 'error_busy') {
            AppLogger.warning('Speech recognition busy - microphone may be in use by audio recorder');
            _isListening = false;
            return;
          }
          
          if (isPermanent) {
            AppLogger.warning('Permanent speech recognition error: $errorMsg');
            _isAvailable = false;
          } else {
            AppLogger.debug('Speech recognition error (non-permanent): $errorMsg');
          }
          
          if (isPermanent || !errorMsg.contains('no_match')) {
            _transcriptionController.addError(errorMsg);
          }
        },
        onStatus: (status) {
          AppLogger.info('Speech recognition status changed: $status');
        },
      );
      
      if (_isAvailable) {
        AppLogger.info('Speech recognition initialized successfully');
        final locales = await _speech.locales();
        AppLogger.debug('Available locales: ${locales.length}');
        if (locales.isNotEmpty) {
          AppLogger.debug('Sample locales: ${locales.take(3).map((l) => '${l.localeId}').join(', ')}');
        }
      } else {
        AppLogger.warning('Speech recognition not available - check permissions and device support');
      }
      
      return _isAvailable;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize speech recognition', e, stackTrace);
      _isAvailable = false;
      return false;
    }
  }

  Future<void> startListening({
    String? localeId,
    bool cancelOnError = false,
    bool partialResults = true,
  }) async {
    if (!_isAvailable) {
      AppLogger.warning('Speech recognition not available');
      return;
    }

    // Always cancel/stop any existing listening first to avoid busy errors
    if (_isListening) {
      AppLogger.debug('Already listening, stopping first...');
      try {
        await _speech.cancel();
        await Future.delayed(const Duration(milliseconds: 300)); // Give it time to release
      } catch (e) {
        AppLogger.debug('Error cancelling existing listening: $e');
      }
      _isListening = false;
    }

    try {
      try {
        await _speech.cancel();
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        AppLogger.debug('No existing session to cancel: $e');
      }

      _currentText = '';
      _transcriptionController.add('');
      
      final locales = await _speech.locales();
      AppLogger.debug('Available locales: ${locales.length}');
      
      String selectedLocaleId = localeId ?? 'en_US';
      
      if (localeId == null) {
        final systemLocale = await _speech.systemLocale();
        if (systemLocale != null) {
          selectedLocaleId = systemLocale.localeId;
          AppLogger.info('Using system locale: $selectedLocaleId');
        } else {
          if (locales.isNotEmpty) {
            final enLocale = locales.firstWhere(
              (l) => l.localeId.startsWith('en'),
              orElse: () => locales.first,
            );
            selectedLocaleId = enLocale.localeId;
          } else {
            selectedLocaleId = 'en_US'; // Fallback
          }
          AppLogger.info('Using default locale: $selectedLocaleId');
        }
      }
      
      final isLocaleAvailable = locales.any((l) => l.localeId == selectedLocaleId);
      if (!isLocaleAvailable && locales.isNotEmpty) {
        AppLogger.warning('Locale $selectedLocaleId not available, using first available: ${locales.first.localeId}');
        selectedLocaleId = locales.first.localeId;
      }
      
      AppLogger.info('Starting transcription with locale: $selectedLocaleId');
      
      final result = await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isEmpty) {
            AppLogger.debug('Empty speech result received');
            return;
          }
          
          AppLogger.info('Speech result: "$words" (final: ${result.finalResult})');
          
          if (result.finalResult) {
            if (_currentText.isNotEmpty && !_currentText.endsWith(' ')) {
              _currentText += ' ';
            }
            _currentText += words;
            _transcriptionController.add(_currentText);
            AppLogger.info('Final transcription updated: "$_currentText"');
          } else {
            final displayText = _currentText.isEmpty 
                ? words 
                : '$_currentText $words';
            _transcriptionController.add(displayText);
            AppLogger.debug('Partial transcription: "$displayText"');
          }
        },
        localeId: selectedLocaleId,
        cancelOnError: cancelOnError,
        partialResults: partialResults,
        listenMode: stt.ListenMode.dictation,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );

      _isListening = result ?? false;

      if (_isListening) {
        AppLogger.info('✅ Successfully started listening for transcription with locale: $selectedLocaleId');
      } else {
        AppLogger.warning('⚠️ Failed to start listening - speech recognition returned false or null');
        AppLogger.warning('This may be due to microphone conflict with audio recording (non-critical)');
        _isListening = false;
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error starting speech recognition', e, stackTrace);
      _isListening = false;
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) {
      return;
    }

    try {
      await _speech.stop();
      _isListening = false;
      AppLogger.info('Stopped listening for transcription');
    } catch (e) {
      AppLogger.error('Error stopping speech recognition', e);
    }
  }

  Future<void> cancel() async {
    try {
      await _speech.cancel();
      _isListening = false;
      _currentText = '';
      AppLogger.info('Cancelled speech recognition');
    } catch (e) {
      AppLogger.error('Error cancelling speech recognition', e);
    }
  }

  void clearText() {
    _currentText = '';
    _transcriptionController.add('');
  }

  Future<void> dispose() async {
    await stopListening();
    await _transcriptionController.close();
  }
}

