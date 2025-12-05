import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryBlue = Color(0xFF6366F1);
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color accentPink = Color(0xFFEC4899);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, primaryPurple],
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentPink, accentCyan],
  );
  
  static const LinearGradient recordingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [errorRed, Color(0xFFFF6B6B)],
  );
  
  static BoxDecoration modernCardDecoration(BuildContext context, {bool elevated = true}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ]
          : null,
    );
  }
  
  static ButtonStyle modernElevatedButton(BuildContext context) {
    return ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
    );
  }
  
  static ButtonStyle modernOutlinedButton(BuildContext context) {
    return OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      side: BorderSide(
        width: 2,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

