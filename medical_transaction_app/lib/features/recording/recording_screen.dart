import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/utils/audio_utils.dart';
import '../../core/theme/app_theme.dart';
import '../../features/settings/theme_language_provider.dart';
import '../../widgets/circular_audio_visualizer.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/headset_service.dart';
import '../../core/utils/accessibility_utils.dart';
import 'recording_controller.dart';

class RecordingScreen extends StatefulWidget {
  final String userId;
  final String? patientId;
  final String? patientName;

  const RecordingScreen({
    super.key,
    required this.userId,
    this.patientId,
    this.patientName,
  });

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  bool _isStarting = false;
  bool _isStopping = false;
  final ScrollController _scrollController = ScrollController();
  late final HeadsetService _headsetService;
  bool _isHeadsetConnected = false;

  @override
  void initState() {
    super.initState();
    _headsetService = HeadsetService();
    _headsetService.stateStream?.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isHeadsetConnected = isConnected;
        });
      }
    });
    _headsetService.checkConnection().then((connected) {
      if (mounted) {
        setState(() {
          _isHeadsetConnected = connected;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _headsetService.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final formatter = DateFormat('EEEE, MMMM d, yyyy');
    return formatter.format(now);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeLanguageProvider>(context);
    final localizations = AppLocalizations(themeProvider.languageCode);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Consumer<RecordingController>(
        builder: (context, controller, child) {
            if (controller.transcriptionText.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getFormattedDate(),
                        style: TextStyle(
                          fontSize: 14 * MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.5),
                          color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[600],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                            child: Text(
                                widget.patientName != null
                                    ? localizations.translate('recording') + ': ${widget.patientName}'
                                    : localizations.translate('medical_transcription'),
                                style: TextStyle(
                                  fontSize: 24 * MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.5),
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(context, '/settings');
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.15),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.language,
                                        size: 16,
                                        color: Colors.black,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        themeProvider.languageCode == 'en' ? 'English' : 'हिंदी',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                              if (controller.isRecording) ...[
                                const SizedBox(width: 12),
                                Semantics(
                                  label: 'Stop recording',
                                  hint: 'Double tap to stop recording',
                                  button: true,
                                  child: GestureDetector(
                                    onTap: () {
                                      HapticService.heavyImpact();
                                      _stopRecording(controller);
                                    },
                                    child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.red,
                                        width: 1,
                                      ),
                                    ),
                                      child: const Icon(
                                        Icons.stop,
                                        size: 20,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.15),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      size: 20,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                            ),
                      ),
                    ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Main Content - Circular Visualizer and Transcription
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 10),
                        // Large Circular Audio Visualizer (responsive size)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final screenWidth = MediaQuery.of(context).size.width;
                            final visualizerSize = (screenWidth * 0.85).clamp(250.0, 350.0);
                            return SizedBox(
                              width: visualizerSize,
                              height: visualizerSize,
                              child: CircularAudioVisualizer(
                                amplitude: controller.amplitude,
                                isRecording: controller.isRecording,
                                isPaused: controller.isPaused,
                                size: visualizerSize,
                                isDark: isDark,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Headset Status Indicator
                        if (controller.isRecording)
                          Semantics(
                            label: AccessibilityUtils.getHeadsetStatusLabel(_isHeadsetConnected),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _isHeadsetConnected 
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isHeadsetConnected ? Icons.headset : Icons.mic,
                                    size: 16,
                                    color: _isHeadsetConnected ? Colors.green : (isDark ? Colors.grey : Colors.grey[700]!),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isHeadsetConnected ? localizations.translate('headset_connected') : localizations.translate('device_mic'),
                                    style: TextStyle(
                                      fontSize: 12 * MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.5),
                                      color: _isHeadsetConnected ? Colors.green : (isDark ? Colors.grey : Colors.grey[700]!),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (controller.isRecording) const SizedBox(height: 16                        ),
                        
                        if (controller.isRecording)
                  Column(
                    children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.graphic_eq,
                                        size: 16,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        localizations.translate('gain_control'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black87.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                      Text(
                                    '${(controller.gain * 100).round()}%',
                                    style: TextStyle(
                                      fontSize: 12 * MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.5),
                                      color: isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black87.withValues(alpha: 0.7),
                              fontWeight: FontWeight.bold,
                            ),
                                  ),
                                ],
                      ),
                      const SizedBox(height: 8),
                              Semantics(
                                label: AccessibilityUtils.getGainControlLabel(controller.gain),
                                hint: AccessibilityUtils.getGainControlHint(),
                                slider: true,
                                value: '${(controller.gain * 100).round()}%',
                                child: Slider(
                                  value: controller.gain,
                                  min: 0.0,
                                  max: 1.0,
                                  divisions: 100,
                                  activeColor: isDark ? Colors.white : Colors.black87,
                                  inactiveColor: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black87.withValues(alpha: 0.3),
                                  onChanged: (value) {
                                    HapticService.selectionClick();
                                    controller.setGain(value);
                                  },
                            ),
                      ),
                    ],
                          ),
                        if (controller.isRecording) const SizedBox(height: 16),

                        // Transcription Text Area (flexible height)
                        Container(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.25,
                            minHeight: 80,
                          ),
                          width: double.infinity,
                          padding: const EdgeInsets.all(16.0),
                          child: controller.isRecording
                              ? (controller.transcriptionText.isEmpty
                                  ? Center(
                                      child: Text(
                                        localizations.translate('listening'),
                                        style: TextStyle(
                                          fontSize: 16 * MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.5),
                                          color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black87.withValues(alpha: 0.6),
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    )
                                  : Semantics(
                                      label: localizations.translate('live_transcription'),
                                      value: controller.transcriptionText.isEmpty 
                                          ? localizations.translate('listening_for_speech')
                                          : controller.transcriptionText,
                                      child: SingleChildScrollView(
                                        controller: _scrollController,
                                        child: Text(
                                          controller.transcriptionText,
                                          style: TextStyle(
                                            fontSize: 18 * MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.5),
                                            height: 1.5,
                                            color: isDark ? Colors.white : Colors.black87,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ))
                              : Center(
                                  child: Semantics(
                                    label: localizations.translate('tap_to_start_instructions'),
                                    child: Text(
                                      localizations.translate('tap_to_start_instructions'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16 * MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.5),
                                        color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black87.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: _buildBottomButton(controller, localizations, _isStarting || _isStopping, isDark),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomButton(
    RecordingController controller,
    AppLocalizations localizations,
    bool isLoading,
    bool isDark,
  ) {
    if (!controller.isRecording) {
      // Start button - circular white button with loading overlay
      return Semantics(
        label: AccessibilityUtils.getRecordingButtonLabel(false, false),
        hint: AccessibilityUtils.getRecordingButtonHint(false, false),
        button: true,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: isLoading ? null : () {
                HapticService.mediumImpact();
                _startRecording(controller);
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLoading 
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.white,
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.15),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : const Icon(
                        Icons.mic,
                        color: Colors.black,
                        size: 36,
                      ),
              ),
            ),
          ],
        ),
      );
    }

    // Recording state button - shows "Listening to You.." or status
    return Semantics(
      label: AccessibilityUtils.getRecordingButtonLabel(controller.isRecording, controller.isPaused),
      hint: AccessibilityUtils.getRecordingButtonHint(controller.isRecording, controller.isPaused),
      button: true,
      child: Stack(
        children: [
          GestureDetector(
            onTap: isLoading
                ? null
                : () {
                    HapticService.mediumImpact();
                    if (controller.isPaused) {
                      controller.resume();
                    } else {
                      controller.pause();
                    }
                  },
            onLongPress: isLoading
                ? null
                : () {
                    // Long press to stop recording
                    HapticService.heavyImpact();
                    _stopRecording(controller);
                  },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isLoading
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.12),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isStarting ? localizations.translate('starting_recording') : localizations.translate('stopping_recording'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  )
                else ...[
                  Text(
                    controller.isPaused
                        ? localizations.translate('paused')
                        : localizations.translate('listening_to_you'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  if (controller.isRecording && !controller.isPaused) ...[
                    const SizedBox(height: 4),
                    Text(
                      AudioUtils.formatDuration(controller.duration),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    localizations.translate('tap_to_pause_long_press_stop'),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                ),
                ],
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }

  Future<void> _startRecording(RecordingController controller) async {
    if (_isStarting || controller.isRecording) return;

    final themeProvider = Provider.of<ThemeLanguageProvider>(context, listen: false);
    final localizations = AppLocalizations(themeProvider.languageCode);

    setState(() => _isStarting = true);

    try {
      await controller.startRecording(
        userId: widget.userId,
        patientId: widget.patientId,
        patientName: widget.patientName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.translate('recording_started')),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations.translate('error_starting_recording')}: $errorMessage',
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: localizations.translate('retry'),
              textColor: Colors.white,
              onPressed: () => _startRecording(controller),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  Future<void> _stopRecording(RecordingController controller) async {
    if (_isStopping || !controller.isRecording) return;

    final themeProvider = Provider.of<ThemeLanguageProvider>(context, listen: false);
    final localizations = AppLocalizations(themeProvider.languageCode);

    setState(() => _isStopping = true);

    try {
      await controller.stop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.translate('recording_stopped_saved')),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations.translate('error_stopping_recording')}: $errorMessage',
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStopping = false);
      }
    }
  }
}
