import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position> determinePosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const LocationException('휴대폰의 위치 서비스를 켜주세요.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationException('현재 위치를 사용하려면 위치 권한이 필요해요.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        '위치 권한이 영구적으로 거부됐어요. 휴대폰 설정에서 권한을 허용해주세요.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
  }
}

class LocationException implements Exception {
  const LocationException(this.message);
  final String message;

  @override
  String toString() => message;
}
