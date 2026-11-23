// lib/geolocation_service.dart
import 'package:geolocator/geolocator.dart';

class GeolocationService {
  Future<Position?> getCurrentPosition() async {
    try {
      // Permission and service checks can also throw on browsers and devices
      // with restricted location access, so keep the whole flow optional.
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }

      if (!await Geolocator.isLocationServiceEnabled()) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      // A location failure must never prevent adding a client to the queue.
      print('Geolocation unavailable; client will be saved without location: $e');
      return null;
    }
  }
}
