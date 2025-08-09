import 'package:flutter/material.dart';
import 'package:food_delivery_app/providers/location_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:food_delivery_app/services/location_service.dart'; // To get initial location
import 'package:provider/provider.dart';

class SetLocationScreen extends StatefulWidget {
  final LatLng? initialPosition;

  const SetLocationScreen({super.key, this.initialPosition});

  @override
  _SetLocationScreenState createState() => _SetLocationScreenState();
}

class _SetLocationScreenState extends State<SetLocationScreen> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(37.7749, -122.4194); // Default to SF
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _currentPosition = widget.initialPosition!;
    } else {
      _fetchInitialLocation();
    }
    _updateMarker();
  }

  void _fetchInitialLocation() async {
    try {
      final position = await LocationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition));
          _updateMarker();
        });
      }
    } catch (e) {
      print("Error fetching initial location: $e");
      // Keep default location if fetching fails
    }
  }

  void _updateMarker() {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: _currentPosition,
          draggable: true,
          onDragEnd: (newPosition) {
            setState(() {
              _currentPosition = newPosition;
            });
          },
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    });
  }

  void _onConfirmLocation() {
    // Create a Position object from the selected LatLng.
    // The other fields are not critical for our address lookup logic.
    final newPosition = Position(
      latitude: _currentPosition.latitude,
      longitude: _currentPosition.longitude,
      timestamp: DateTime.now(),
      accuracy: 100.0, // Placeholder accuracy
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0, // Add this line for null safety
      headingAccuracy: 0.0, // Add this line for null safety
    );

    // Update the provider, which will notify listeners (like HomeScreen and CartScreen)
    context.read<LocationProvider>().updateLocation(newPosition);

    // Just pop the screen, no need to return a value
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drag the pin to your location'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 15.0,
            ),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            markers: _markers,
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _onConfirmLocation,
              child: const Text('Confirm Location', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
