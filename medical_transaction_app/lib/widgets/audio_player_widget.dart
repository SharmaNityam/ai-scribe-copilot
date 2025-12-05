import 'dart:async';
import 'package:flutter/material.dart';
import '../core/services/audio_player_service.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String sessionId;
  final AudioPlayerService audioPlayerService;

  const AudioPlayerWidget({
    super.key,
    required this.sessionId,
    required this.audioPlayerService,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _error;
  
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<bool>? _playingStateSubscription;

  @override
  void initState() {
    super.initState();
    _loadSession();
    _setupListeners();
  }

  Future<void> _loadSession() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await widget.audioPlayerService.loadSession(widget.sessionId);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _setupListeners() {
    _positionSubscription = widget.audioPlayerService.positionStream?.listen(
      (position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      },
    );

    _durationSubscription = widget.audioPlayerService.durationStream?.listen(
      (duration) {
        if (mounted) {
          setState(() {
            _duration = duration;
          });
        }
      },
    );

    _playingStateSubscription = widget.audioPlayerService.playingStateStream?.listen(
      (isPlaying) {
        if (mounted) {
          setState(() {
            _isPlaying = isPlaying;
          });
        }
      },
    );
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await widget.audioPlayerService.pause();
      } else {
        await widget.audioPlayerService.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _stop() async {
    await widget.audioPlayerService.stop();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playingStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return Card(
        color: Colors.red[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.error_outline, color: Colors.red[700]),
              const SizedBox(height: 8),
              Text(
                'Cannot play recording',
                style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _error!,
                style: TextStyle(color: Colors.red[600], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.audiotrack, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Audio Recording',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress bar
            Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (value) {
                if (_duration.inMilliseconds > 0) {
                  final newPosition = Duration(
                    milliseconds: (value * _duration.inMilliseconds).toInt(),
                  );
                  widget.audioPlayerService.seek(newPosition);
                }
              },
            ),
            // Time indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_position),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: _duration.inMilliseconds > 0 ? _stop : null,
                  tooltip: 'Stop',
                ),
                const SizedBox(width: 16),
                IconButton(
                  iconSize: 48,
                  icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle),
                  onPressed: _togglePlayPause,
                  tooltip: _isPlaying ? 'Pause' : 'Play',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

