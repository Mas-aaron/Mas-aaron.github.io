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
  LatLng? _currentPosition;
  final Set<Marker> _markers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  void _initializeLocation() async {
    LatLng positionToSet;
    if (widget.initialPosition != null) {
      positionToSet = widget.initialPosition!;
    } else {
      try {
        final position = await LocationService.getCurrentLocation();
        if (position != null) {
          positionToSet = LatLng(position.latitude, position.longitude);
        } else {
          // Fallback to default if service returns null
          positionToSet = const LatLng(37.7749, -122.4194);
        }
      } catch (e) {
        print("Error fetching initial location: $e");
        // Fallback to default on error
        positionToSet = const LatLng(37.7749, -122.4194);
      }
    }

    if (mounted) {
      setState(() {
        _currentPosition = positionToSet;
        _isLoading = false;
        _updateMarker();
      });
    }
  }

  void _updateMarker() {
    if (_currentPosition == null) return;
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: _currentPosition!,
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
    if (_currentPosition == null) return; // Don't proceed if location isn't set

    // Create a Position object from the selected LatLng.
    final newPosition = Position(
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      timestamp: DateTime.now(),
      accuracy: 100.0, // Placeholder accuracy
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0, 
      headingAccuracy: 0.0, 
    );

    // Update the provider, which will notify listeners (like HomeScreen and CartScreen)
    context.read<LocationProvider>().updateLocation(newPosition);

    Navigator.of(context).pop(_currentPosition);
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
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _currentPosition == null
                  ? const Center(child: Text('Could not determine location.'))
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _currentPosition!,
                              zoom: 15.0,
                            ),
                            markers: _markers,
                            onCameraMove: (CameraPosition position) {
                              setState(() {
                                _currentPosition = position.target;
                                _updateMarker();
                              });
                            },
                          ),
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
        ],
      ),
    );
  }
}
