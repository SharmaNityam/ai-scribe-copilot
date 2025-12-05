class ApiConfig {
  static const String defaultBaseUrl = 'http://192.168.29.57:3000';
  
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

