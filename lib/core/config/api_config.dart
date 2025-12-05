class ApiConfig {
  static const String defaultBaseUrl = 'https://ai-scribe-copilot-rev9.onrender.com';
  
  static String get baseUrl {
    const String envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    return defaultBaseUrl;
  }
  
  static String getBaseUrlForPlatform() {
    return baseUrl;
  }
}

