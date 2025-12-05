import 'package:logger/logger.dart';

class AppLogger {
  static Logger? _instance;
  
  static Logger get instance {
    _instance ??= Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: true,
      ),
      level: _getLogLevel(),
    );
    return _instance!;
  }
  
  static Level _getLogLevel() {
    const bool isDebug = bool.fromEnvironment('dart.vm.product') == false;
    return isDebug ? Level.debug : Level.warning;
  }
  
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    instance.d(message, error: error, stackTrace: stackTrace);
  }
  
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    instance.i(message, error: error, stackTrace: stackTrace);
  }
  
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    instance.w(message, error: error, stackTrace: stackTrace);
  }
  
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    instance.e(message, error: error, stackTrace: stackTrace);
  }
  
  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    instance.f(message, error: error, stackTrace: stackTrace);
  }
}

