import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/logger.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (initialized ?? false) {
        _initialized = true;
        AppLogger.info('Notification service initialized');
        
        if (Platform.isAndroid) {
          await _createNotificationChannels();
        }
      } else {
        AppLogger.warning('Failed to initialize notification service');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error initializing notification service', e, stackTrace);
    }
  }

  static Future<void> _createNotificationChannels() async {
    const recordingChannel = AndroidNotificationChannel(
      'recording_channel',
      'Recording Notifications',
      description: 'Notifications for active recording sessions',
      importance: Importance.high,
      playSound: false, // Respect Do Not Disturb
      enableVibration: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(recordingChannel);
  }

  static Future<void> showRecordingNotification({
    required String sessionId,
    required String patientName,
    required bool isPaused,
    required Duration duration,
    Function(String action)? onAction,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        'recording_channel',
        'Recording Notifications',
        channelDescription: 'Notifications for active recording sessions',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        playSound: false,
        enableVibration: false,
        actions: [
          AndroidNotificationAction(
            isPaused ? 'resume_action' : 'pause_action',
            isPaused ? 'Resume' : 'Pause',
          ),
          AndroidNotificationAction(
            'stop_action',
            'Stop',
          ),
        ],
      );

      final iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final title = isPaused ? 'Recording Paused' : 'Recording in Progress';
      final body = isPaused
          ? '$patientName • ${_formatDuration(duration)}'
          : '$patientName • ${_formatDuration(duration)}';

      await _notifications.show(
        888, // Notification ID
        title,
        body,
        details,
        payload: sessionId,
      );

      AppLogger.info('Recording notification shown: $title');
    } catch (e, stackTrace) {
      AppLogger.error('Error showing recording notification', e, stackTrace);
    }
  }

  static Future<void> updateRecordingNotification({
    required String sessionId,
    required String patientName,
    required bool isPaused,
    required Duration duration,
  }) async {
    await showRecordingNotification(
      sessionId: sessionId,
      patientName: patientName,
      isPaused: isPaused,
      duration: duration,
    );
  }

  static Future<void> cancelRecordingNotification() async {
    try {
      await _notifications.cancel(888);
      AppLogger.info('Recording notification cancelled');
    } catch (e) {
      AppLogger.error('Error cancelling notification', e);
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    AppLogger.info('Notification tapped: ${response.actionId}, payload: ${response.payload}');
    
    if (response.actionId != null) {
      switch (response.actionId) {
        case 'pause_action':
          break;
        case 'resume_action':
          break;
        case 'stop_action':
          break;
      }
    }
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

