import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/repositories/api_repository.dart';
import '../../features/settings/theme_language_provider.dart';
import 'session_details_screen.dart';

class SessionsListScreen extends StatefulWidget {
  final String userId;

  const SessionsListScreen({
    super.key,
    required this.userId,
  });

  @override
  State<SessionsListScreen> createState() => _SessionsListScreenState();
}

class _SessionsListScreenState extends State<SessionsListScreen> {
  final ApiRepository _apiRepository = ApiRepository();
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiRepository.getAllSessions(widget.userId);
      setState(() {
        _sessions = List<Map<String, dynamic>>.from(response['sessions'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final themeProvider = Provider.of<ThemeLanguageProvider>(context, listen: false);
        final localizations = AppLocalizations(themeProvider.languageCode);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations.translate('error_loading_sessions')}: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
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

  String _formatTime(String? timeString) {
    if (timeString == null) return '';
    try {
      final time = DateTime.parse(timeString);
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'recording':
        return Icons.mic;
      case 'paused':
        return Icons.pause_circle;
      case 'failed':
        return Icons.error;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeLanguageProvider>(context);
    final localizations = AppLocalizations(themeProvider.languageCode);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        title: Text(
          localizations.translate('recordings'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? Colors.white : Colors.black,
              ),
            )
          : _sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                        Icons.mic_none,
                          size: 60,
                          color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No recordings yet',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start a recording to see it here',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSessions,
                  color: isDark ? Colors.white : Colors.black,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      return _buildSessionCard(context, session, isDark);
                    },
                  ),
                ),
    );
  }

  Widget _buildSessionCard(BuildContext context, Map<String, dynamic> session, bool isDark) {
    final themeProvider = Provider.of<ThemeLanguageProvider>(context);
    final localizations = AppLocalizations(themeProvider.languageCode);
                      final patientName = (session['patient_name'] as String?) ?? localizations.translate('no_patient');
                      final date = _formatDate(session['date'] as String?);
                      final startTime = _formatTime(session['start_time'] as String?);
                      final duration = session['duration'] as String?;
                      final status = session['status'] as String? ?? 'unknown';
                      final sessionTitle = session['session_title'] as String? ?? localizations.translate('recording_session');
                      final transcriptStatus = session['transcript_status'] as String? ?? 'pending';
    final statusIcon = _getStatusIcon(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SessionDetailsScreen(
                  session: session,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Status Icon - white circle with black icon (matching design)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                            child: Icon(
                        statusIcon,
                        color: Colors.black,
                        size: 24,
                            ),
                          ),
                    const SizedBox(width: 16),
                    // Patient Name & Title
                    Expanded(
                      child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                            patientName,
                            style: TextStyle(
                              fontSize: 18,
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
                    Icon(
                      Icons.chevron_right,
                      color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey[400],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Date & Time
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                      size: 16,
                      color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey[600],
                                  ),
                    const SizedBox(width: 8),
                                  Text(
                                    '$date ${startTime.isNotEmpty ? 'at $startTime' : ''}',
                                    style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey[600],
                                    ),
                              ),
                              if (duration != null) ...[
                      const SizedBox(width: 16),
                                    Icon(
                                      Icons.timer,
                        size: 16,
                        color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey[600],
                                    ),
                      const SizedBox(width: 8),
                                    Text(
                                      duration,
                                      style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                  ],
                ),
                const SizedBox(height: 12),
                // Status Badges
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
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                                        fontWeight: FontWeight.bold,
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
                            fontSize: 12,
                            color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
          ),
                  ),
                ),
    );
  }
}
