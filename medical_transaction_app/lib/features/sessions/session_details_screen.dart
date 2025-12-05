import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../features/settings/theme_language_provider.dart';
import '../../core/services/audio_player_service.dart';
import '../../core/services/share_service.dart';
import '../../core/repositories/local_storage_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/audio_player_widget.dart';

class SessionDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> session;

  const SessionDetailsScreen({
    super.key,
    required this.session,
  });

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  late final AudioPlayerService _audioPlayerService;

  @override
  void initState() {
    super.initState();
    _audioPlayerService = AudioPlayerService();
  }

  @override
  void dispose() {
    _audioPlayerService.dispose();
    super.dispose();
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return '';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeString;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'recording':
        return Colors.blue;
      case 'paused':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeLanguageProvider>(context);
    final localizations = AppLocalizations(themeProvider.languageCode);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final patientName = (widget.session['patient_name'] as String?) ?? localizations.translate('no_patient');
    final sessionTitle = widget.session['session_title'] as String? ?? localizations.translate('recording_session');
    final status = widget.session['status'] as String? ?? 'unknown';
    final transcriptStatus = widget.session['transcript_status'] as String? ?? 'pending';
    final transcript = widget.session['transcript'] as String? ?? '';
    final date = _formatDate(widget.session['date'] as String?);
    final startTime = _formatDateTime(widget.session['start_time'] as String?);
    final endTime = _formatDateTime(widget.session['end_time'] as String?);
    final duration = widget.session['duration'] as String?;
    final sessionId = widget.session['id'] as String? ?? localizations.translate('unknown');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        title: Text(
          localizations.translate('session_details'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          // Share button
          IconButton(
            icon: Icon(
              Icons.share,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () => _shareSession(context),
            tooltip: 'Share recording',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mic,
                          color: Colors.black,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                              style: TextStyle(
                                fontSize: 22,
                            fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                          ),
                    ),
                            const SizedBox(height: 4),
                    Text(
                      sessionTitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    ),
                    const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (transcriptStatus != 'pending')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            ),
                          child: Text(
                            localizations.translate('transcript_ready'),
                            style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            
            // Audio Player
            AudioPlayerWidget(
              sessionId: sessionId,
              audioPlayerService: _audioPlayerService,
            ),
            const SizedBox(height: 20),
            
            Text(
              localizations.translate('session_information'),
              style: TextStyle(
                fontSize: 20,
                    fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
                child: Column(
                  children: [
                  _buildInfoRow(localizations.translate('session_id'), sessionId, Icons.tag, isDark),
                  const Divider(height: 24),
                  _buildInfoRow(localizations.translate('date'), date, Icons.calendar_today, isDark),
                  const Divider(height: 24),
                    _buildInfoRow(localizations.translate('start_time'), startTime, Icons.play_arrow, isDark),
                    if (endTime.isNotEmpty) ...[
                    const Divider(height: 24),
                    _buildInfoRow(localizations.translate('end_time'), endTime, Icons.stop, isDark),
                    ],
                    if (duration != null) ...[
                    const Divider(height: 24),
                    _buildInfoRow(localizations.translate('duration'), duration, Icons.timer, isDark),
                      ],
                    ],
                ),
              ),
            const SizedBox(height: 20),

            if (transcript.isNotEmpty) ...[
              Text(
                localizations.translate('transcript'),
                style: TextStyle(
                  fontSize: 20,
                      fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                    ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                  child: Text(
                    transcript,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _shareSession(BuildContext context) async {
    final sessionId = widget.session['id'] as String? ?? widget.session['session_id'] as String?;
    if (sessionId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to share: Session ID not found'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
      return;
    }

    try {
      // Get all chunks for this session
      final localStorage = LocalStorageRepository();
      final chunks = await localStorage.getChunksBySession(sessionId);
      
      if (chunks.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No audio files found to share'),
              backgroundColor: AppTheme.warningOrange,
            ),
          );
        }
        return;
      }

      // Share the first chunk file (or all chunks)
      final filePaths = chunks.map((chunk) => chunk.filePath).toList();
      
      // Check if files exist
      final existingFiles = <String>[];
      for (final path in filePaths) {
        final file = File(path);
        if (await file.exists()) {
          existingFiles.add(path);
        }
      }

      if (existingFiles.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Audio files not found on device'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
        return;
      }

      // Share files using native share sheet
      if (existingFiles.length == 1) {
        await ShareService.shareFile(
          existingFiles.first,
          subject: 'Medical Recording - ${widget.session['patient_name'] ?? 'Session'}',
          text: 'Medical recording session',
        );
      } else {
        await ShareService.shareFiles(
          existingFiles,
          subject: 'Medical Recording - ${widget.session['patient_name'] ?? 'Session'}',
          text: 'Medical recording session (${existingFiles.length} files)',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Widget _buildInfoRow(String label, String value, IconData icon, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black87,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
