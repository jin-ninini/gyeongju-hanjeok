import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class AppEnv {
  static String get mode => dotenv.env['APP_MODE']?.trim().toLowerCase() ?? 'preview';
  static bool get isPreview => mode != 'live';

  static String get backendContract =>
      dotenv.env['BACKEND_CONTRACT']?.trim().toLowerCase() ?? 'snake_flat';

  static bool get usesCamelContract => backendContract == 'camel_nested';

  static String get backendBaseUrl {
    final value = dotenv.env['BACKEND_BASE_URL']?.trim();
    if (value == null || value.isEmpty) return 'http://10.0.2.2:8000';
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  static String get kakaoJavaScriptKey =>
      dotenv.env['KAKAO_JAVASCRIPT_KEY']?.trim() ?? '';

  static String get kakaoMapBaseUrl =>
      dotenv.env['KAKAO_MAP_BASE_URL']?.trim() ?? 'https://localhost';

  static double get defaultLatitude =>
      double.tryParse(dotenv.env['DEFAULT_LATITUDE'] ?? '') ?? 35.8562;

  static double get defaultLongitude =>
      double.tryParse(dotenv.env['DEFAULT_LONGITUDE'] ?? '') ?? 129.2247;

  static int get congestionRefreshMinutes =>
      int.tryParse(dotenv.env['CONGESTION_REFRESH_MINUTES'] ?? '') ?? 5;
}
