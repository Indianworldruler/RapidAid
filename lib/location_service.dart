import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService._();

  static final LocationService instance =
      LocationService._();

  // Checks whether the device location service is enabled.
  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  // Requests the required location permission.
  Future<bool> requestLocationPermission() async {
    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // Gets the current GPS position of the device.
  Future<Position> getCurrentPosition() async {
    final bool serviceEnabled =
        await isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'Location services are disabled.',
      );
    }

    final bool permissionGranted =
        await requestLocationPermission();

    if (!permissionGranted) {
      throw Exception(
        'Location permission was not granted.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  // Creates a Google Maps link from the current GPS position.
  Future<String> getCurrentLocationLink() async {
    final Position position =
        await getCurrentPosition();

    return 'https://www.google.com/maps?q='
        '${position.latitude},${position.longitude}';
  }
}