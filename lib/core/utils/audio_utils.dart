class AudioUtils {
  static double amplitudeToPercentage(double amplitude) {
    if (amplitude <= -160) return 0.0;
    if (amplitude >= 0) return 100.0;
    
    return ((amplitude + 160) / 160) * 100;
  }

  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

