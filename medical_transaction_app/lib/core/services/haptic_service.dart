import 'package:flutter/services.dart';
import '../utils/logger.dart';

class HapticService {
  static Future<void> lightImpact() async {
    try {
      await HapticFeedback.lightImpact();
      AppLogger.debug('Haptic feedback: light impact');
    } catch (e) {
      AppLogger.debug('Haptic feedback not available: $e');
    }
  }

  static Future<void> mediumImpact() async {
    try {
      await HapticFeedback.mediumImpact();
      AppLogger.debug('Haptic feedback: medium impact');
    } catch (e) {
      AppLogger.debug('Haptic feedback not available: $e');
    }
  }

  static Future<void> heavyImpact() async {
    try {
      await HapticFeedback.heavyImpact();
      AppLogger.debug('Haptic feedback: heavy impact');
    } catch (e) {
      AppLogger.debug('Haptic feedback not available: $e');
    }
  }

  static Future<void> selectionClick() async {
    try {
      await HapticFeedback.selectionClick();
      AppLogger.debug('Haptic feedback: selection click');
    } catch (e) {
      AppLogger.debug('Haptic feedback not available: $e');
    }
  }

  static Future<void> vibrate() async {
    try {
      await HapticFeedback.vibrate();
      AppLogger.debug('Haptic feedback: vibrate');
    } catch (e) {
      AppLogger.debug('Haptic feedback not available: $e');
    }
  }
}

