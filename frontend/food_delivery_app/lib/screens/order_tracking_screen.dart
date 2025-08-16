import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_delivery_app/constants.dart';
import 'package:food_delivery_app/services/api_service.dart';
import 'package:food_delivery_app/services/auth_service.dart';
import 'package:food_delivery_app/models/order.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:food_delivery_app/services/directions_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  final Order order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  _OrderTrackingScreenState createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  late WebSocketChannel _channel;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  BitmapDescriptor? riderIcon;

  Order? _currentOrder;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // Wait for both the order details and marker icons to load in parallel.
    await Future.wait([
      _loadOrderDetails(),
      _loadMarkerIcons(),
    ]);

    // Once all data is ready, proceed with setting up the map.
    if (mounted) {
      _setupInitialMarkers();
      _initWebSocket();
      _drawRoute();
    }
  }

  Future<void> _loadOrderDetails() async {
    try {
      final order = await _apiService.getOrderDetails(widget.order.id);
      if (mounted) {
        setState(() {
          _currentOrder = order;
        });
      }
    } catch (e) {
      print('Failed to load order details: $e');
      // Optionally, show an error message to the user
    }
  }

  Future<void> _loadMarkerIcons() async {
    try {
      riderIcon = await _getMarkerIcon('assets/images/rider_marker.png', 120);
    } catch (e) {
      print('Error loading rider icon: $e');
    }
  }

  Future<BitmapDescriptor> _getMarkerIcon(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    final Uint8List resizedData = (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(resizedData);
  }

  void _setupInitialMarkers() {
    if (_currentOrder == null) return;

    // Restaurant Marker (default)
    if (_currentOrder!.restaurant.lat != 0) {
      final restaurantMarker = Marker(
        markerId: const MarkerId('restaurant'),
        position: LatLng(_currentOrder!.restaurant.lat, _currentOrder!.restaurant.lng),
        infoWindow: InfoWindow(title: _currentOrder!.restaurant.name),
      );
      _markers.add(restaurantMarker);
    }

    // Delivery Address Marker (default)
    if (_currentOrder!.deliveryLat != 0) {
      final deliveryMarker = Marker(
        markerId: const MarkerId('delivery_address'),
        position: LatLng(_currentOrder!.deliveryLat, _currentOrder!.deliveryLng),
        infoWindow: const InfoWindow(title: 'Your Location'),
      );
      _markers.add(deliveryMarker);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _drawRoute() async {
    if (_currentOrder == null) {
      print("DrawRoute skipped: currentOrder is null.");
      return;
    }

    final directionsService = DirectionsService();
    final LatLng origin = LatLng(_currentOrder!.restaurant.lat, _currentOrder!.restaurant.lng);
    final LatLng destination = LatLng(_currentOrder!.deliveryLat, _currentOrder!.deliveryLng);

    print("Drawing route from $origin to $destination");

    final List<LatLng> polylineCoordinates = await directionsService.getRouteCoordinates(origin, destination);

    if (polylineCoordinates.isNotEmpty) {
      final Polyline polyline = Polyline(
        polylineId: const PolylineId('route'),
        color: Colors.blue,
        points: polylineCoordinates,
        width: 5,
      );
      if (mounted) {
        setState(() {
          _polylines.add(polyline);
        });

        final GoogleMapController controller = await _controller.future;
        controller.animateCamera(CameraUpdate.newLatLngBounds(
          _boundsFromLatLngList(polylineCoordinates),
          100.0, // Padding
        ));
      }
    } else {
      print("Could not draw route: polylineCoordinates is empty.");
    }
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(northeast: LatLng(x1!, y1!), southwest: LatLng(x0!, y0!));
  }

  void _initWebSocket() async {
    if (_currentOrder == null) return;

    final token = await AuthService.getToken();
    if (token == null) {
      print('Authentication token not found, cannot connect to WebSocket.');
      return;
    }

    final uri = Uri.parse('$baseWebsocketUrl/ws/tracking/${_currentOrder!.id}/?token=$token');
    _channel = WebSocketChannel.connect(uri);

    _channel.stream.listen((message) {
      if (!mounted) return;
      final data = jsonDecode(message);
      if (data['type'] == 'rider_location') {
        final lat = data['latitude'];
        final lng = data['longitude'];
        _updateRiderMarker(LatLng(lat, lng));
      }
    }, onError: (error) {
      print('WebSocket error: $error');
      // Handle WebSocket errors
    }, onDone: () {
      print('WebSocket connection closed.');
      // Handle WebSocket connection closed
    });
  }

  void _updateRiderMarker(LatLng position) {
    if (riderIcon == null) return;
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'rider');
      _markers.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: position,
          infoWindow: const InfoWindow(title: 'Rider'),
          icon: riderIcon!,
        ),
      );
    });
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    // A list of statuses that are considered final and not trackable.
    const nonTrackableStatuses = ['delivered', 'cancelled'];

    // Check if the current order's status is one of the non-trackable ones.
    if (nonTrackableStatuses.contains(widget.order.status.toLowerCase())) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('Order Details #${widget.order.id}'),
          backgroundColor: Colors.orange,
        ),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.orange.shade100,
            child: Text(
              'This order is not available for live tracking (Status: ${widget.order.status})',
              style: TextStyle(fontSize: 16, color: Colors.orange.shade900),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // If the status is trackable, show the map.
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentOrder != null ? 'Track Order #${_currentOrder!.id}' : 'Loading Order...'),
        backgroundColor: Colors.orange,
      ),
      body: SizedBox.expand(
        child: GoogleMap(
          onMapCreated: (GoogleMapController controller) {
            if (!_controller.isCompleted) {
              _controller.complete(controller);
            }
          },
          initialCameraPosition: CameraPosition(
            target: LatLng(widget.order.restaurant.lat, widget.order.restaurant.lng),
            zoom: 14.5,
          ),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
        ),
      ),
    );
  }
}
