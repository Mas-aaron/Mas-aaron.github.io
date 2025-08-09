import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:food_delivery_app/services/api_service.dart';

class LocationProvider with ChangeNotifier {
  Position? _currentPosition;
  String? _currentAddress;
  bool _isLocationAccurate = false;
  final ApiService _apiService = ApiService();

  Position? get currentPosition => _currentPosition;
  String? get currentAddress => _currentAddress;
  bool get isLocationAccurate => _isLocationAccurate;

  Future<void> updateLocation(Position position) async {
    _currentPosition = position;
    // Check accuracy. 20 meters is a stricter threshold for delivery apps.
    _isLocationAccurate = position.accuracy <= 20;

    try {
      _currentAddress = await _apiService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      _currentAddress = 'Could not get address';
      print('Error getting address in LocationProvider: $e');
    }
    notifyListeners();
  }

  Future<void> determineInitialLocation() async {
    if (_currentPosition != null) return; // Already have a location

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _currentAddress = 'Location permission denied.';
        notifyListeners();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await updateLocation(position);
    } catch (e) {
      _currentAddress = 'Could not fetch location.';
      print('Error in determineInitialLocation: $e');
      notifyListeners();
    }
  }
}
