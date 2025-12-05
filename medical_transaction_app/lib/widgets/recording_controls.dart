import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RecordingControls extends StatelessWidget {
  final bool isRecording;
  final bool isPaused;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onPause;
  final VoidCallback onResume;

  const RecordingControls({
    super.key,
    required this.isRecording,
    required this.isPaused,
    required this.onStart,
    required this.onStop,
    required this.onPause,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    if (!isRecording) {
      return FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          onStart();
        },
        icon: const Icon(Icons.mic),
        label: const Text('Start Recording'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Stop button
        FloatingActionButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            onStop();
          },
          backgroundColor: Colors.red,
          child: const Icon(Icons.stop, color: Colors.white),
        ),
        const SizedBox(width: 20),
        // Pause/Resume button
        FloatingActionButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            if (isPaused) {
              onResume();
            } else {
              onPause();
            }
          },
          backgroundColor: isPaused ? Colors.green : Colors.orange,
          child: Icon(
            isPaused ? Icons.play_arrow : Icons.pause,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

