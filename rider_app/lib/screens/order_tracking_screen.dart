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
import '../services/contact_service.dart';
import '../services/distance_service.dart';
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
  
  // Distance tracking
  String _restaurantDistance = 'Calculating...';
  String _customerDistance = 'Calculating...';

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
      _calculateDistances();
      _initializeArrivalNotifications();
    }
  }

  Future<void> _calculateDistances() async {
    if (widget.order.restaurantLat != null && widget.order.restaurantLng != null) {
      final restaurantDistance = await DistanceService.getFormattedDistanceFromCurrentLocation(
        widget.order.restaurantLat!,
        widget.order.restaurantLng!,
      );
      if (mounted) {
        setState(() {
          _restaurantDistance = restaurantDistance;
        });
      }
    }

    if (widget.order.customerLat != null && widget.order.customerLng != null) {
      final customerDistance = await DistanceService.getFormattedDistanceFromCurrentLocation(
        widget.order.customerLat!,
        widget.order.customerLng!,
      );
      if (mounted) {
        setState(() {
          _customerDistance = customerDistance;
        });
      }
    }
  }

  Future<void> _initializeArrivalNotifications() async {
    // Start monitoring location for arrival detection if order is active
    if (widget.order.status.toLowerCase() == 'out for delivery') {
      try {
        await _locationService.startRiderLocationTracking(widget.order);
        print('Arrival notification system initialized for order ${widget.order.id}');
      } catch (error) {
        print('Failed to initialize arrival notifications: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location tracking unavailable: ${error.toString()}'),
              backgroundColor: Colors.orange,
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
    return status == 'out for delivery' || status == 'ready for pickup';
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
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Loading Route...',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF00C851)),
              SizedBox(height: 16),
              Text('Loading delivery route...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final CameraPosition initialCameraPosition = CameraPosition(
      target: LatLng(widget.order.restaurantLat!, widget.order.restaurantLng!),
      zoom: 12,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Full-screen map
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: initialCameraPosition,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          
          // Modern top app bar overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${widget.order.id}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          _getStatusText(),
                          style: TextStyle(
                            fontSize: 14,
                            color: _getStatusColor(),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.my_location, color: Color(0xFF00C851)),
                    onPressed: () {
                      if (_currentLocation != null && _shouldBroadcast()) {
                        _animateCameraToPosition(LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // Modern bottom sheet with order details and actions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Order details
                    _buildOrderDetails(),
                    
                    const SizedBox(height: 24),
                    
                    // Action buttons
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText() {
    switch (widget.order.status.toLowerCase()) {
      case 'out for delivery':
        return 'Delivering to customer';
      case 'ready for pickup':
        return 'Ready for pickup';
      default:
        return widget.order.status;
    }
  }

  Color _getStatusColor() {
    switch (widget.order.status.toLowerCase()) {
      case 'out for delivery':
        return const Color(0xFF00C851);
      case 'ready for pickup':
        return Colors.orange[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  Widget _buildOrderDetails() {
    return Column(
      children: [
        // Restaurant info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red[100]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.restaurant, color: Colors.red[600], size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pickup from',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.order.restaurantName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on, size: 14, color: Colors.red[700]),
                              const SizedBox(width: 4),
                              Text(
                                _restaurantDistance,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Customer info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[100]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.location_on, color: Colors.blue[600], size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Deliver to',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on, size: 14, color: Colors.blue[700]),
                              const SizedBox(width: 4),
                              Text(
                                _customerDistance,
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (widget.order.customerPhone != null)
                          GestureDetector(
                            onTap: () => ContactService.showContactOptions(
                              context,
                              customerName: widget.order.customerName ?? 'Customer',
                              phoneNumber: widget.order.customerPhone!,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C851).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.phone, size: 14, color: Color(0xFF00C851)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Contact',
                                    style: TextStyle(
                                      color: Color(0xFF00C851),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.order.deliveryAddress,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.order.customerName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Customer: ${widget.order.customerName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (widget.order.status != 'Out for Delivery') {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Primary action button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _completeOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C851),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: const Icon(Icons.check_circle, size: 20),
            label: const Text(
              'Mark as Delivered',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Secondary action button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _notifyArrival,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF00C851),
              side: const BorderSide(color: Color(0xFF00C851)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.notifications_active, size: 20),
            label: const Text(
              'Notify Customer of Arrival',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
