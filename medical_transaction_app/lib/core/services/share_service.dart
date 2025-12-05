import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../utils/logger.dart';

/// Service for native share sheet integration
class ShareService {
  /// Share text using native share sheet
  static Future<void> shareText(String text, {String? subject}) async {
    try {
      await Share.share(
        text,
        subject: subject,
      );
      AppLogger.info('Shared text via native share sheet');
    } catch (e, stackTrace) {
      AppLogger.error('Error sharing text', e, stackTrace);
      rethrow;
    }
  }

  /// Share file using native share sheet
  static Future<void> shareFile(String filePath, {String? subject, String? text}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      final xFile = XFile(filePath);
      await Share.shareXFiles(
        [xFile],
        subject: subject,
        text: text,
      );
      AppLogger.info('Shared file via native share sheet: $filePath');
    } catch (e, stackTrace) {
      AppLogger.error('Error sharing file', e, stackTrace);
      rethrow;
    }
  }

  /// Share multiple files using native share sheet
  static Future<void> shareFiles(List<String> filePaths, {String? subject, String? text}) async {
    try {
      final xFiles = filePaths.map((path) => XFile(path)).toList();
      await Share.shareXFiles(
        xFiles,
        subject: subject,
        text: text,
      );
      AppLogger.info('Shared ${filePaths.length} files via native share sheet');
    } catch (e, stackTrace) {
      AppLogger.error('Error sharing files', e, stackTrace);
      rethrow;
    }
  }
}

