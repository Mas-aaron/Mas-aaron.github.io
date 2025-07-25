import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:food_delivery_app/models/order.dart';
import 'package:food_delivery_app/services/api_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:food_delivery_app/constants.dart';

class OrderTrackingScreen extends StatefulWidget {
  final int orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final ApiService _apiService = ApiService();
  final Completer<GoogleMapController> _mapController = Completer();
  WebSocketChannel? _channel;
Timer? _reconnectTimer;
String? _lastStatus;
LatLng? _lastRiderPosition;
BitmapDescriptor? _riderIcon;

  Future<Order>? _futureOrder;
  String? _currentStatus;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final PolylinePoints _polylinePoints = PolylinePoints();

  @override
  void initState() {
    super.initState();
    _loadRiderIcon();
    _futureOrder = _fetchOrderDetails();
  }

  void _loadRiderIcon() async {
    try {
      _riderIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/rider_marker.png', // Place your custom icon in assets and update pubspec.yaml
      );
    } catch (_) {
      _riderIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }

  Future<Order> _fetchOrderDetails() async {
    try {
      // First, fetch only the essential order details.
      final order = await _apiService.getOrderDetails(widget.orderId);
      if (mounted) {
        setState(() {
          _currentStatus = order.status;
        });
        // Once we have the order, initialize websockets and set initial map markers.
        _initializeWebSocket();
        _setMarkers(order);
        // Fetch the route in the background without blocking the UI.
        _getRouteAndDrawPolyline(order);
      }
      return order;
    } catch (e) {
      // Propagate the error to the FutureBuilder.
      rethrow;
    }
  }

    void _initializeWebSocket() {
    final urlString = 'ws://10.0.2.2:8000/ws/track/${widget.orderId}/';
_channel = WebSocketChannel.connect(Uri.parse(urlString));
    _channel!.stream.listen(
      (data) {
        if (!mounted) return;
        final decodedData = jsonDecode(data);
        final message = decodedData['message'];
        if (message is! Map<String, dynamic>) return;
        setState(() {
          // Animate marker if rider moves
          if (message['latitude'] != null && message['longitude'] != null) {
            final lat = message['latitude'];
            final lng = message['longitude'];
            _animateRiderMarker(LatLng(lat, lng));
          }
          // Status change with snackbar
          if (message['status'] != null) {
            if (_lastStatus != null && _lastStatus != message['status']) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Order status: ${message['status']}')),
              );
            }
            _lastStatus = message['status'];
            _currentStatus = message['status'];
          }
        });
      },
      onDone: _scheduleReconnect,
      onError: (_) => _scheduleReconnect(),
      cancelOnError: true,
    );
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _initializeWebSocket();
    });
  }

  void _animateRiderMarker(LatLng newPos) async {
    if (_lastRiderPosition == null) {
      _lastRiderPosition = newPos;
      _setRiderMarker(newPos);
      _autoZoom();
      return;
    }
    // Animate in 10 steps
    for (int i = 1; i <= 10; i++) {
      final lat = _lastRiderPosition!.latitude + (newPos.latitude - _lastRiderPosition!.latitude) * i / 10;
      final lng = _lastRiderPosition!.longitude + (newPos.longitude - _lastRiderPosition!.longitude) * i / 10;
      _setRiderMarker(LatLng(lat, lng));
      await Future.delayed(const Duration(milliseconds: 30));
    }
    _lastRiderPosition = newPos;
    _autoZoom();
  }

  void _setRiderMarker(LatLng position) {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'rider');
      _markers.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: position,
          icon: _riderIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Rider'),
        ),
      );
    });
  }

  void _autoZoom() async {
    if (_markers.length < 2) return;
    final GoogleMapController controller = await _mapController.future;
    LatLngBounds bounds = _computeBounds(_markers.map((m) => m.position).toList());
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  LatLngBounds _computeBounds(List<LatLng> positions) {
    final sw = LatLng(
      positions.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
      positions.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
    );
    final ne = LatLng(
      positions.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
      positions.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
    );
    return LatLngBounds(southwest: sw, northeast: ne);
  }

  void _setMarkers(Order order) {
    if (order.restaurantLat != null && order.restaurantLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('restaurant'),
        position: LatLng(order.restaurantLat!, order.restaurantLng!),
        infoWindow: InfoWindow(title: order.restaurant.name),
      ));
    }
    if (order.customerLat != null && order.customerLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('customer'),
        position: LatLng(order.customerLat!, order.customerLng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ));
    }
  }

  void _getRouteAndDrawPolyline(Order order) async {
    if (order.restaurantLat == null ||
        order.restaurantLng == null ||
        order.customerLat == null ||
        order.customerLng == null) {
      return;
    }

    PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: googleMapsApiKey,
      request: PolylineRequest(
        origin: PointLatLng(order.restaurantLat!, order.restaurantLng!),
        destination: PointLatLng(order.customerLat!, order.customerLng!),
        mode: TravelMode.driving,
      ),
    );

    if (result.points.isNotEmpty) {
      List<LatLng> polylineCoordinates = [];
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }

      if (mounted) {
        setState(() {
          _polylines.add(Polyline(
            polylineId: const PolylineId('route'),
            color: Colors.blueAccent,
            points: polylineCoordinates,
            width: 5,
          ));
        });
      }
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Track Order #${widget.orderId}'),
        elevation: 0,
      ),
      body: FutureBuilder<Order>(
        future: _futureOrder,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('Order not found.'));
          } else {
            final order = snapshot.data!;
            return Stack(
              children: [
                GoogleMap(
                  onMapCreated: (GoogleMapController controller) {
                    if (!_mapController.isCompleted) {
                      _mapController.complete(controller);
                    }
                  },
                  initialCameraPosition: CameraPosition(
                    // Default to a safe location if coordinates are invalid to prevent crashing.
                    target: LatLng(
                      (order.restaurantLat ?? 0.0) != 0.0 ? (order.restaurantLat! + order.customerLat!) / 2 : 37.7749,
                      (order.restaurantLng ?? 0.0) != 0.0 ? (order.restaurantLng! + order.customerLng!) / 2 : -122.4194,
                    ),
                    zoom: 12.5,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  padding: const EdgeInsets.only(bottom: 120), // Adjust padding for the overlay
                ),
                if (_currentStatus != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildStatusOverlay(),
                  ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildStatusOverlay() {
    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Order Status',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              _currentStatus!,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
