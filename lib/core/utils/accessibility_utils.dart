class AccessibilityUtils {
  static String getRecordingButtonLabel(bool isRecording, bool isPaused) {
    if (!isRecording) return 'Start recording';
    if (isPaused) return 'Resume recording';
    return 'Pause recording';
  }

  static String getRecordingButtonHint(bool isRecording, bool isPaused) {
    if (!isRecording) return 'Double tap to start recording';
    if (isPaused) return 'Double tap to resume recording';
    return 'Double tap to pause recording, long press to stop';
  }

  static String getGainControlLabel(double gain) {
    final percentage = (gain * 100).round();
    return 'Microphone gain: $percentage percent';
  }

  static String getGainControlHint() {
    return 'Swipe left or right to adjust microphone sensitivity';
  }

  static String getHeadsetStatusLabel(bool isConnected) {
    return isConnected ? 'Headset connected' : 'Using device microphone';
  }
}

