import 'dart:async';
import 'package:flutter/services.dart';
import '../utils/logger.dart';

class HeadsetService {
  static const MethodChannel _channel = MethodChannel('com.example.medical_transaction_app/headset');
  
  StreamController<bool>? _stateController;
  Stream<bool>? get stateStream => _stateController?.stream;
  
  bool _isHeadsetConnected = false;
  bool get isHeadsetConnected => _isHeadsetConnected;
  StreamSubscription? _subscription;

  HeadsetService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _stateController = StreamController<bool>.broadcast();
      
      _isHeadsetConnected = await checkConnection();
      _stateController?.add(_isHeadsetConnected);
      
      _channel.setMethodCallHandler(_handleMethodCall);
      
      // Try to start listening, but don't crash if native implementation doesn't exist
      try {
        await _channel.invokeMethod('startListening');
      } catch (e) {
        AppLogger.debug('startListening not implemented on native side: $e');
      }
      
      AppLogger.info('Headset service initialized. Connected: $_isHeadsetConnected');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize headset service', e, stackTrace);
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onHeadsetConnected':
        _isHeadsetConnected = true;
        _stateController?.add(true);
        AppLogger.info('Headset connected');
        break;
      case 'onHeadsetDisconnected':
        _isHeadsetConnected = false;
        _stateController?.add(false);
        AppLogger.info('Headset disconnected');
        break;
    }
  }

  Future<bool> checkConnection() async {
    try {
      final result = await _channel.invokeMethod<bool>('isHeadsetConnected');
      _isHeadsetConnected = result ?? false;
      return _isHeadsetConnected;
    } catch (e) {
      AppLogger.debug('Error checking headset connection: $e');
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _stateController?.close();
    _stateController = null;
    // Try to stop listening, but don't crash if native implementation doesn't exist
    _channel.invokeMethod('stopListening').catchError((error) {
      AppLogger.debug('stopListening not implemented on native side: $error');
    });
  }
}

