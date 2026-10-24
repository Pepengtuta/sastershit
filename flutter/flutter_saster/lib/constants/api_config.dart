class ApiConfig {
  // Backend host. Override at build time without editing this file:
  //   flutter build apk --dart-define=API_BASE_URL=https://your-host.example
  // Falls back to the current Railway deployment when not provided.
  static const String _root = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ugyon-production.up.railway.app',
  );

  static const String baseUrl = '$_root/api';
  static const String fileBaseUrl = _root;

  

# Local LAN
// flutter build apk --release --dart-define=API_BASE_URL=http://192.168.123.103/vsp/sastergpt

# Ngrok (https)
// flutter build apk --release --dart-define=API_BASE_URL=https://cloud-prognosis-boogeyman.ngrok-free.dev/vsp/sastergpt

// -----Flip--to-True-----useNgrokHeader = true; for tunnel for ngrok browser warning shit
  static const bool useNgrokHeader = false;
  static Map<String, String> get ngrokHeaders =>
      useNgrokHeader ? const {'ngrok-skip-browser-warning': 'true'} : const {};
}
