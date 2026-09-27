import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/expense_model.dart';

/// Provides GPS location capture and reverse geocoding.
class GeoService {
  /// Requests permission and returns the current device position.
  /// Returns null if permission is denied.
  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  /// Reverse-geocodes a lat/lng to a human-readable address string.
  Future<String?> getAddressFromLatLng(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final parts = [
        if (p.name?.isNotEmpty == true)          p.name,
        if (p.subLocality?.isNotEmpty == true)   p.subLocality,
        if (p.locality?.isNotEmpty == true)      p.locality,
        if (p.administrativeArea?.isNotEmpty == true) p.administrativeArea,
      ];
      return parts.join(', ');
    } catch (_) {
      return null;
    }
  }

  /// Captures current position and returns a ready [ExpenseLocation].
  Future<ExpenseLocation?> captureLocation() async {
    final pos = await getCurrentPosition();
    if (pos == null) return null;
    final address = await getAddressFromLatLng(pos.latitude, pos.longitude);
    return ExpenseLocation(
      latitude:  pos.latitude,
      longitude: pos.longitude,
      address:   address,
    );
  }
}
