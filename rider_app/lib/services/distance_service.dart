import 'dart:math';
import 'package:geolocator/geolocator.dart';

class DistanceService {
  /// Calculate distance between two points using Haversine formula
  static double calculateDistance(
    double lat1, double lon1, 
    double lat2, double lon2
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;
    
    return distance;
  }
  
  /// Convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }
  
  /// Format distance for display
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()}m';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)}km';
    } else {
      return '${distanceKm.round()}km';
    }
  }
  
  /// Get current location with error handling
  static Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled.');
        return null;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      return position;
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }
  
  /// Calculate distance from current location to a point
  static Future<double?> getDistanceFromCurrentLocation(
    double targetLat, 
    double targetLon
  ) async {
    Position? currentPosition = await getCurrentLocation();
    if (currentPosition == null) return null;
    
    return calculateDistance(
      currentPosition.latitude, 
      currentPosition.longitude,
      targetLat, 
      targetLon
    );
  }
  
  /// Get formatted distance from current location
  static Future<String> getFormattedDistanceFromCurrentLocation(
    double targetLat, 
    double targetLon
  ) async {
    double? distance = await getDistanceFromCurrentLocation(targetLat, targetLon);
    if (distance == null) return 'Distance unavailable';
    return formatDistance(distance);
  }
}
