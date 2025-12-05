import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkUtils {
  static final Connectivity _connectivity = Connectivity();

  static Future<bool> isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  static Future<ConnectivityResult> getConnectivityType() async {
    return await _connectivity.checkConnectivity();
  }

  static Stream<ConnectivityResult> get connectivityStream {
    return _connectivity.onConnectivityChanged;
  }
}

