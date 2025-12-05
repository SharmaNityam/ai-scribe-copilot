import 'package:flutter/material.dart';
import '../core/utils/audio_utils.dart';

class AudioLevelIndicator extends StatelessWidget {
  final double amplitude;
  final double height;
  final double width;

  const AudioLevelIndicator({
    super.key,
    required this.amplitude,
    this.height = 200,
    this.width = 50,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = AudioUtils.amplitudeToPercentage(amplitude);
    final normalizedPercentage = percentage.clamp(0.0, 100.0);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.green,
                  Colors.yellow,
                  Colors.orange,
                  Colors.red,
                ],
                stops: const [0.0, 0.4, 0.7, 1.0],
              ),
            ),
          ),
          // Level indicator
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: height * (normalizedPercentage / 100),
              width: width,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
            ),
          ),
          // Level text
          Center(
            child: Text(
              '${normalizedPercentage.toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 2,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

