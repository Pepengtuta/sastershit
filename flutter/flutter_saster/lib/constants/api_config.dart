class ApiConfig {
  // Local APK testing through laptop XAMPP.
  // Laptop must use this static IP, and phone must be on the same Wi-Fi.
 //  static const String baseUrl = 'http://192.168.123.62/vsp/sastergpt/api';
  // static const String fileBaseUrl = 'http://192.168.123.62/vsp/sastergpt';

  // For Flutter Chrome testing on the laptop, temporarily use:
  // static const String baseUrl = 'http://localhost/vsp/sastergpt/api';
  // static const String fileBaseUrl = 'http://localhost/vsp/sastergpt';

  // ngrok demo tunnel (Android APK over the internet).
  // Swap in the real ngrok forwarding URL once ngrok is running.
 // static const String baseUrl = 'https://YOUR-SUBDOMAIN.ngrok-free.app/vsp/sastergpt/api';
 // static const String fileBaseUrl = 'https://YOUR-SUBDOMAIN.ngrok-free.app/vsp/sastergpt';

  //current ngrok service
  // static const String baseUrl = 'https://cloud-prognosis-boogeyman.ngrok-free.dev/vsp/sastergpt/api';
  // static const String fileBaseUrl = 'https://cloud-prognosis-boogeyman.ngrok-free.dev/vsp/sastergpt';

    //current railway service
  static const String baseUrl =
      'ugyon-production.up.railway.app/vsp/sastergpt/api';
  static const String fileBaseUrl =
      'ugyon-production.up.railway.app/vsp/sastergpt';

  // Flip to false for plain localhost/LAN browser testing (no ngrok in the loop).
  // Flip back to true when going through an ngrok URL.
  static const bool useNgrokHeader = false;
 static Map<String, String> get ngrokHeaders =>
      useNgrokHeader ? const {'ngrok-skip-browser-warning': 'true'} : const {};
 }
