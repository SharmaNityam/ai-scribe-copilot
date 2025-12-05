class Validation {
  static bool isValidEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }
  
  static bool isValidPhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return RegExp(r'^\d{10,15}$').hasMatch(cleaned);
  }
  
  static bool isNotEmpty(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
  
  static bool isValidApiResponse(Map<String, dynamic>? response) {
    return response != null && response.isNotEmpty;
  }
  
  static String? getString(Map<String, dynamic>? data, String key) {
    if (data == null) return null;
    final value = data[key];
    if (value is String) return value;
    if (value != null) return value.toString();
    return null;
  }
  
  static int? getInt(Map<String, dynamic>? data, String key) {
    if (data == null) return null;
    final value = data[key];
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
  
  static List<T>? getList<T>(Map<String, dynamic>? data, String key) {
    if (data == null) return null;
    final value = data[key];
    if (value is List) {
      try {
        return value.cast<T>().toList();
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}

