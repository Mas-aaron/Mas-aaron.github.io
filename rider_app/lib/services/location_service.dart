import 'dart:async';
import 'dart:math';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/order.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  Timer? _locationUpdateTimer;
  
  // Tracking state
  bool _isTracking = false;
  Order? _currentOrder;
  bool _arrivalNotified = false;
  bool _approachingNotified = false;

  Future<void> startRiderLocationTracking(Order order) async {
    try {
      // Request permissions
      await _requestLocationPermissions();
      
      _currentOrder = order;
      _isTracking = true;
      _arrivalNotified = false;
      _approachingNotified = false;
      
      // Start listening to location updates
      _locationSubscription = _location.onLocationChanged.listen(
        (LocationData currentLocation) {
          _handleLocationUpdate(currentLocation);
        },
        onError: (error) {
          print('Location tracking error: $error');
        }
      );
      
      // Also send periodic location updates to backend
      _startPeriodicLocationUpdates();
      
      print('Started location tracking for order ${order.id}');
    } catch (error) {
      print('Failed to start location tracking: $error');
      rethrow;
    }
  }

  Future<void> _requestLocationPermissions() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }
    }

    PermissionStatus permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
      if (permission != PermissionStatus.granted) {
        throw Exception('Location permissions denied');
      }
    }
  }

  void _handleLocationUpdate(LocationData currentLocation) {
    if (!_isTracking || _currentOrder == null) return;
    
    if (currentLocation.latitude == null || currentLocation.longitude == null) {
      return;
    }

    // Check if customer coordinates are available
    if (_currentOrder!.customerLat == null || _currentOrder!.customerLng == null) {
      print('Customer coordinates not available');
      return;
    }

    final double distance = calculateDistance(
      currentLocation.latitude!,
      currentLocation.longitude!,
      _currentOrder!.customerLat!,
      _currentOrder!.customerLng!,
    );

    print('Distance to customer: ${distance.toStringAsFixed(1)}m');

    // DEBUG: Larger radii for testing (remove in production)
    const double arrivalRadius = 1000; // 1km for testing
    const double approachingRadius = 2000; // 2km for testing
    
    // Check if rider is within arrival radius
    if (distance <= arrivalRadius && !_arrivalNotified) {
      _triggerArrivalNotification(currentLocation);
      _arrivalNotified = true;
    }

    // Check if approaching
    if (distance <= approachingRadius && distance > arrivalRadius && !_approachingNotified) {
      _triggerApproachingNotification(currentLocation, distance);
      _approachingNotified = true;
    }
  }

  void _startPeriodicLocationUpdates() {
    _locationUpdateTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      if (!_isTracking || _currentOrder == null) {
        timer.cancel();
        return;
      }
      
      try {
        LocationData currentLocation = await _location.getLocation();
        if (currentLocation.latitude != null && currentLocation.longitude != null) {
          await _sendLocationUpdateToBackend(currentLocation);
        }
      } catch (error) {
        print('Error getting location for update: $error');
      }
    });
  }

  Future<void> _sendLocationUpdateToBackend(LocationData location) async {
    if (_currentOrder == null) return;
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rider-orders/${_currentOrder!.id}/location-update/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token ${await _getAuthToken()}',
        },
        body: json.encode({
          'latitude': location.latitude,
          'longitude': location.longitude,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Location update sent. Distance: ${data['distance_to_customer']?.toStringAsFixed(1)}m');
      }
    } catch (error) {
      print('Error sending location update: $error');
    }
  }

  Future<void> _triggerArrivalNotification(LocationData currentLocation) async {
    if (_currentOrder == null) return;
    
    try {
      print('Triggering arrival notification...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/rider-orders/${_currentOrder!.id}/arrival/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token ${await _getAuthToken()}',
        },
        body: json.encode({
          'latitude': currentLocation.latitude,
          'longitude': currentLocation.longitude,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Arrival notification sent successfully: ${data['message']}');
        
        // Show confirmation to rider
        _showRiderConfirmation('Customer Notified', 'The customer has been notified of your arrival');
      } else {
        final error = json.decode(response.body);
        print('Arrival notification failed: ${error['error']}');
        
        if (error['error'].toString().contains('not close enough')) {
          _showRiderConfirmation(
            'Too Far Away', 
            'You need to be within ${error['required_distance']}m of the customer location'
          );
        }
      }
    } catch (error) {
      print('Error sending arrival notification: $error');
    }
  }

  Future<void> _triggerApproachingNotification(LocationData currentLocation, double distance) async {
    print('Rider is approaching customer (${distance.toStringAsFixed(1)}m away)');
    // The backend will handle sending the approaching notification
  }

  Future<void> manualArrivalConfirmation() async {
    if (_currentOrder == null) return;
    
    try {
      LocationData currentLocation = await _location.getLocation();
      if (currentLocation.latitude != null && currentLocation.longitude != null) {
        await _triggerArrivalNotification(currentLocation);
        _arrivalNotified = true;
      }
    } catch (error) {
      print('Error with manual arrival confirmation: $error');
      _showRiderConfirmation('Error', 'Failed to confirm arrival. Please try again.');
    }
  }

  void _showRiderConfirmation(String title, String message) {
    // This would typically show a dialog or snackbar
    // Implementation depends on your UI framework
    print('$title: $message');
  }

  double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000; // meters
    
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLng = _degreesToRadians(lng2 - lng1);
    
    double a = sin(dLat/2) * sin(dLat/2) +
              cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
              sin(dLng/2) * sin(dLng/2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1-a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken') ?? '';
  }

  void stopLocationTracking() {
    _isTracking = false;
    _locationSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _currentOrder = null;
    _arrivalNotified = false;
    _approachingNotified = false;
    print('Stopped location tracking');
  }

  bool get isTracking => _isTracking;
  Order? get currentOrder => _currentOrder;
  bool get hasArrived => _arrivalNotified;
}
