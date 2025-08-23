import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rider_app/constants.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:convert';
import '../models/order.dart';
import '../constants.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/location_service.dart';
import '../services/arrival_notification_service.dart';
import 'package:location/location.dart';

// Helper function to programmatically resize marker icons
Future<BitmapDescriptor> getMarkerIcon(String path, int width) async {
  ByteData data = await rootBundle.load(path);
  ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
  ui.FrameInfo fi = await codec.getNextFrame();
  final Uint8List resizedData = (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  return BitmapDescriptor.fromBytes(resizedData);
}

class OrderTrackingScreen extends StatefulWidget {
  final Order order;
  final ApiService apiService;

  const OrderTrackingScreen({super.key, required this.order, required this.apiService});

  @override
  _OrderTrackingScreenState createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final ApiService _apiService = ApiService();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _polylineCoordinates = [];
  final PolylinePoints _polylinePoints = PolylinePoints();
  LocationData? _currentLocation;
  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  StreamSubscription? _webSocketSubscription;
  WebSocketChannel? _channel;
  Timer? _broadcastTimer;
  Timer? _reconnectTimer;
  bool _wsConnected = false;

  BitmapDescriptor? _riderIcon;
  
  // Arrival notification services
  final LocationService _locationService = LocationService();
  final ArrivalNotificationService _arrivalService = ArrivalNotificationService();

  @override
  void initState() {
    super.initState();
    // Log the incoming order details to debug coordinate issues
    print('--- Order Tracking Screen ---');
    print('Order ID: ${widget.order.id}');
    print('Restaurant Coords: (${widget.order.restaurantLat}, ${widget.order.restaurantLng})');
    print('Customer Coords: (${widget.order.customerLat}, ${widget.order.customerLng})');
    print('---------------------------');
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // Ensure the custom marker is loaded before any other map-related setup
    await _loadCustomMarker();

    // Now that assets are ready, proceed with the rest of the setup
    if (mounted) {
      _setMarkers();
      _initializeLocation();
      _getRouteAndDrawPolyline();
      _initWebSocket();
      _initializeArrivalNotifications();
    }
  }

  Future<void> _initializeArrivalNotifications() async {
    // Start monitoring location for arrival detection if order is active
    if (widget.order.status.toLowerCase() == 'on the way') {
      try {
        await _locationService.startRiderLocationTracking(widget.order);
        print('Arrival notification system initialized for order ${widget.order.id}');
      } catch (error) {
        print('Failed to initialize arrival notifications: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to start location tracking: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _loadCustomMarker() async {
    // Use the new helper function to get a resized marker icon
    final icon = await getMarkerIcon('assets/images/rider_marker.png', 80);
    if (mounted) {
      setState(() {
        _riderIcon = icon;
      });
    }
  }

  void _setMarkers() {
    final restaurantLat = widget.order.restaurantLat;
    final restaurantLng = widget.order.restaurantLng;
    final customerLat = widget.order.customerLat;
    final customerLng = widget.order.customerLng;

    if (restaurantLat != null && restaurantLng != null) {
      _markers.add(
        Marker(
          markerId: MarkerId('restaurant'),
          position: LatLng(restaurantLat, restaurantLng),
          infoWindow: InfoWindow(title: 'Restaurant: ${widget.order.restaurantName}'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }

    if (customerLat != null && customerLng != null) {
      _markers.add(
        Marker(
          markerId: MarkerId('customer'),
          position: LatLng(customerLat, customerLng),
          infoWindow: InfoWindow(title: 'Delivery Address', snippet: widget.order.deliveryAddress),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }
    setState(() {});
  }

  Future<void> _initWebSocket() async {
    final token = await ApiService.getToken();
    if (token == null) {
      print('Authentication token not found, cannot connect to WebSocket.');
      return;
    }

    final wsUrl = Uri.parse('$webSocketUrl/ws/tracking/${widget.order.id}/?token=$token');
    _channel = WebSocketChannel.connect(wsUrl);

    // Assume the connection is active immediately and handle errors reactively.
    if (mounted) {
      setState(() {
        _wsConnected = true;
      });
    }

    _webSocketSubscription = _channel!.stream.listen(
      (event) {
        // Handle incoming messages if needed, but connection is already active.
        print('Received WebSocket message: $event');
      },
      onDone: () {
        if (mounted) {
          print('WebSocket connection closed.');
          setState(() {
            if (_wsConnected) {
              _wsConnected = false;
            }
          });
          _scheduleReconnect();
        }
      },
      onError: (error) {
        if (mounted) {
          print('WebSocket error: $error');
          setState(() {
            _wsConnected = false;
          });
          _scheduleReconnect();
        }
      },
      cancelOnError: true,
    );
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _initWebSocket();
    });
  }

  void _sendLocationData(LocationData locationData) {
    if (!_wsConnected || _channel == null || locationData.latitude == null || locationData.longitude == null) {
      return;
    }
    if (!_shouldBroadcast()) {
      return;
    }

    // Add a 'type' to help the backend distinguish message types
    final data = jsonEncode({
      'type': 'rider_location_update', // Corrected to match backend consumer
      'latitude': locationData.latitude,
      'longitude': locationData.longitude,
    });

    try {
      print('Sending location update: $data');
      _channel!.sink.add(data);
    } catch (e) {
      print('Error sending location data: $e');
    }
  }

  bool _shouldBroadcast() {
    // Only broadcast if order is active (customize statuses as needed)
    // Broadcast as long as the order is active.
    final status = widget.order.status.toLowerCase();
    return status != 'delivered' && status != 'cancelled';
  }

  Future<void> _getRouteAndDrawPolyline() async {
    final restaurantLat = widget.order.restaurantLat;
    final restaurantLng = widget.order.restaurantLng;
    final customerLat = widget.order.customerLat;
    final customerLng = widget.order.customerLng;

    if (restaurantLat == null || restaurantLng == null || customerLat == null || customerLng == null) {
      print('Error: Missing location coordinates.');
      return;
    }

    try {
      final token = await ApiService.getToken();
      if (token == null) {
        print('Error: Auth token not available.');
        return;
      }

      final directions = await _apiService.getDirections(
        origin: '$restaurantLat,$restaurantLng',
        destination: '$customerLat,$customerLng',
        token: token,
      );

      if (directions['routes'] != null && directions['routes'].isNotEmpty) {
        final points = _polylinePoints.decodePolyline(directions['routes'][0]['overview_polyline']['points']);
        if (points.isNotEmpty) {
          for (var point in points) {
            _polylineCoordinates.add(LatLng(point.latitude, point.longitude));
          }
        }
      }
    } catch (e) {
      print('Error fetching directions: $e');
    }

    setState(() {
      _polylines.add(Polyline(
        polylineId: PolylineId('route'),
        color: Colors.blue,
        points: _polylineCoordinates,
        width: 5,
      ));
    });
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    if (!kIsWeb) {
      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }
    }

    // Set desired accuracy for the location updates.
    await _location.changeSettings(accuracy: LocationAccuracy.high);

    _locationSubscription = _location.onLocationChanged.listen((LocationData currentLocation) {
      setState(() {
        _currentLocation = currentLocation;
        _updateRiderMarker(currentLocation);
      });

      // Throttle: only send every 3 seconds
      _broadcastTimer?.cancel();
      _broadcastTimer = Timer(const Duration(seconds: 3), () {
        if (_shouldBroadcast()) {
          _sendLocationData(currentLocation);
        }
      });
    });
  }

  void _updateRiderMarker(LocationData locationData) {
    if (locationData.latitude == null || locationData.longitude == null) return;

    final LatLng riderPosition = LatLng(locationData.latitude!, locationData.longitude!);
    final Marker riderMarker = Marker(
      markerId: MarkerId('rider'),
      position: riderPosition,
      infoWindow: InfoWindow(title: 'Your Location'),
      icon: _riderIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'rider');
      _markers.add(riderMarker);
    });
  }

  Future<void> _animateCameraToPosition(LatLng position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: position, zoom: 15.5, tilt: 30.0),
    ));
  }

  Future<void> _notifyArrival() async {
    if (_currentLocation?.latitude == null || _currentLocation?.longitude == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location not available. Please wait for GPS signal.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final success = await _arrivalService.triggerArrivalNotification(
        widget.order,
        _currentLocation!.latitude!,
        _currentLocation!.longitude!,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer notified of your arrival!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send arrival notification. You may not be close enough to the customer.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completeOrder() async {
    try {
      await _apiService.completeOrder(widget.order.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order delivered successfully!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete order: $e')),
      );
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _webSocketSubscription?.cancel();
    _broadcastTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    
    // Stop location tracking services
    _locationService.stopLocationTracking();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show a loader if we don't have coordinates yet.
    if (widget.order.restaurantLat == null || widget.order.restaurantLng == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading Route...'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final CameraPosition initialCameraPosition = CameraPosition(
      target: LatLng(widget.order.restaurantLat!, widget.order.restaurantLng!),
      zoom: 12,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Route'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_currentLocation != null && _shouldBroadcast()) {
                _animateCameraToPosition(LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!));
              }
            },
          )
        ],
      ),
      body: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: initialCameraPosition,
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
        markers: _markers,
        polylines: _polylines,
      ),
      floatingActionButton: widget.order.status == 'On the way'
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // DEBUG: Force arrival test button
                FloatingActionButton.extended(
                  onPressed: () async {
                    // Test with fake coordinates near customer
                    final success = await _arrivalService.triggerArrivalNotification(
                      widget.order,
                      widget.order.customerLat ?? 0.0,
                      widget.order.customerLng ?? 0.0,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? 'DEBUG: Arrival test successful!' : 'DEBUG: Arrival test failed'),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                  label: const Text('DEBUG: Force Arrival'),
                  icon: const Icon(Icons.bug_report),
                  heroTag: 'debugArrival',
                  backgroundColor: Colors.purple,
                ),
                const SizedBox(height: 8),
                FloatingActionButton.extended(
                  onPressed: _notifyArrival,
                  label: const Text('Notify Arrival'),
                  icon: const Icon(Icons.notifications_active),
                  heroTag: 'notifyArrival',
                ),
                const SizedBox(height: 8),
                FloatingActionButton.extended(
                  onPressed: _completeOrder,
                  label: const Text('Mark as Delivered'),
                  icon: const Icon(Icons.check),
                  heroTag: 'completeOrder',
                ),
              ],
            )
          : null,
    );
  }
}
