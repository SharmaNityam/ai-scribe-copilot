import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeLanguageProvider with ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _languageKey = 'language_code';

  ThemeMode _themeMode = ThemeMode.system;
  String _languageCode = 'en';

  ThemeMode get themeMode => _themeMode;
  String get languageCode => _languageCode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  ThemeLanguageProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey);
    final languageCode = prefs.getString(_languageKey);

    if (themeIndex != null) {
      _themeMode = ThemeMode.values[themeIndex];
    }

    if (languageCode != null) {
      _languageCode = languageCode;
    }

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    _languageCode = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
    notifyListeners();
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else if (_themeMode == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      // System mode - switch to light
      setThemeMode(ThemeMode.light);
    }
  }
}

// Localization strings
class AppLocalizations {
  final String languageCode;

  AppLocalizations(this.languageCode);

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Medical Transaction App',
      'start_recording': 'Start Recording',
      'stop_recording': 'Stop Recording',
      'pause': 'Pause',
      'resume': 'Resume',
      'recording': 'Recording',
      'paused': 'Paused',
      'patients': 'Patients',
      'add_patient': 'Add Patient',
      'settings': 'Settings',
      'theme': 'Theme',
      'language': 'Language',
      'dark_mode': 'Dark Mode',
      'light_mode': 'Light Mode',
      'system_mode': 'System Default',
      'english': 'English',
      'hindi': 'Hindi',
      'patient_name': 'Patient Name',
      'phone_number': 'Phone Number',
      'email': 'Email',
      'save': 'Save',
      'cancel': 'Cancel',
      'select_patient': 'Select Patient',
      'no_patient_selected': 'No Patient Selected',
      'duration': 'Duration',
      'audio_level': 'Audio Level',
      'uploading': 'Uploading',
      'uploaded': 'Uploaded',
      'failed': 'Failed',
      'recordings': 'Recordings',
      'session_details': 'Session Details',
      'recording_started': 'Recording started',
      'recording_stopped_saved': 'Recording stopped and saved',
      'starting_recording': 'Starting recording...',
      'stopping_recording': 'Stopping recording...',
      'error_starting_recording': 'Error starting recording',
      'error_stopping_recording': 'Error stopping recording',
      'retry': 'Retry',
      'go_ahead_listening': 'Go ahead. I\'m listening.',
      'listening': 'Listening...',
      'medical_transcription': 'Medical Transcription',
      'tap_to_begin_session': 'Tap to begin a new medical transcription session',
      'quick_actions': 'Quick Actions',
      'session_information': 'Session Information',
      'transcript': 'Transcript',
      'session_id': 'Session ID',
      'date': 'Date',
      'start_time': 'Start Time',
      'end_time': 'End Time',
      'no_patient': 'No Patient',
      'recording_session': 'Recording Session',
      'headset_connected': 'Headset Connected',
      'device_mic': 'Device Mic',
      'gain_control': 'Gain Control',
      'live_transcription': 'Live transcription',
      'listening_for_speech': 'Listening for speech',
      'tap_to_start_instructions': 'Tap the button below to start recording',
      'listening_to_you': 'Listening to You..',
      'tap_to_pause_long_press_stop': 'Tap to pause • Long press to stop',
      'transcript_ready': 'TRANSCRIPT: READY',
      'unknown': 'Unknown',
      'error_loading_sessions': 'Error loading sessions',
    },
    'hi': {
      'app_title': 'मेडिकल ट्रांजैक्शन ऐप',
      'start_recording': 'रिकॉर्डिंग शुरू करें',
      'stop_recording': 'रिकॉर्डिंग रोकें',
      'pause': 'रोकें',
      'resume': 'जारी रखें',
      'recording': 'रिकॉर्डिंग',
      'paused': 'रोका गया',
      'patients': 'मरीज़',
      'add_patient': 'मरीज़ जोड़ें',
      'settings': 'सेटिंग्स',
      'theme': 'थीम',
      'language': 'भाषा',
      'dark_mode': 'डार्क मोड',
      'light_mode': 'लाइट मोड',
      'system_mode': 'सिस्टम डिफॉल्ट',
      'english': 'अंग्रेजी',
      'hindi': 'हिंदी',
      'patient_name': 'मरीज़ का नाम',
      'phone_number': 'फोन नंबर',
      'email': 'ईमेल',
      'save': 'सहेजें',
      'cancel': 'रद्द करें',
      'select_patient': 'मरीज़ चुनें',
      'no_patient_selected': 'कोई मरीज़ नहीं चुना गया',
      'duration': 'अवधि',
      'audio_level': 'ऑडियो स्तर',
      'uploading': 'अपलोड हो रहा है',
      'uploaded': 'अपलोड हो गया',
      'failed': 'असफल',
      'recordings': 'रिकॉर्डिंग्स',
      'session_details': 'सत्र विवरण',
      'recording_started': 'रिकॉर्डिंग शुरू हो गई',
      'recording_stopped_saved': 'रिकॉर्डिंग रोक दी गई और सहेजी गई',
      'starting_recording': 'रिकॉर्डिंग शुरू हो रही है...',
      'stopping_recording': 'रिकॉर्डिंग रोकी जा रही है...',
      'error_starting_recording': 'रिकॉर्डिंग शुरू करने में त्रुटि',
      'error_stopping_recording': 'रिकॉर्डिंग रोकने में त्रुटि',
      'retry': 'पुनः प्रयास करें',
      'go_ahead_listening': 'आगे बढ़ें। मैं सुन रहा हूं।',
      'listening': 'सुन रहे हैं...',
      'medical_transcription': 'चिकित्सा प्रतिलेखन',
      'tap_to_begin_session': 'एक नया चिकित्सा प्रतिलेखन सत्र शुरू करने के लिए टैप करें',
      'quick_actions': 'त्वरित कार्य',
      'session_information': 'सत्र जानकारी',
      'transcript': 'प्रतिलेख',
      'session_id': 'सत्र आईडी',
      'date': 'तारीख',
      'start_time': 'शुरुआती समय',
      'end_time': 'समाप्ति समय',
      'no_patient': 'कोई मरीज़ नहीं',
      'recording_session': 'रिकॉर्डिंग सत्र',
      'headset_connected': 'हेडसेट जुड़ा हुआ',
      'device_mic': 'डिवाइस माइक',
      'gain_control': 'गेन नियंत्रण',
      'live_transcription': 'लाइव प्रतिलेखन',
      'listening_for_speech': 'भाषण सुन रहे हैं',
      'tap_to_start_instructions': 'रिकॉर्डिंग शुरू करने के लिए नीचे दिए गए बटन पर टैप करें',
      'listening_to_you': 'आपको सुन रहे हैं..',
      'tap_to_pause_long_press_stop': 'रोकने के लिए टैप करें • रोकने के लिए लंबे समय तक दबाएं',
      'transcript_ready': 'प्रतिलेख: तैयार',
      'unknown': 'अज्ञात',
      'error_loading_sessions': 'सत्र लोड करने में त्रुटि',
    },
  };

  String translate(String key) {
    return _localizedValues[languageCode]?[key] ?? 
           _localizedValues['en']?[key] ?? 
           key;
  }

  static AppLocalizations of(BuildContext context) {
    final provider = context.findAncestorWidgetOfExactType<_LocalizationsProvider>();
    return provider?.localizations ?? AppLocalizations('en');
  }
}

class _LocalizationsProvider extends InheritedWidget {
  final AppLocalizations localizations;

  const _LocalizationsProvider({
    required this.localizations,
    required super.child,
  });

  @override
  bool updateShouldNotify(_LocalizationsProvider oldWidget) {
    return localizations.languageCode != oldWidget.localizations.languageCode;
  }
}

