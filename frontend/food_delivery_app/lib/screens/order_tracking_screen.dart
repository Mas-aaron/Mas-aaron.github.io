import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_delivery_app/constants.dart';
import 'package:food_delivery_app/models/order.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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

  BitmapDescriptor? riderIcon;
  BitmapDescriptor? restaurantIcon;
  BitmapDescriptor? homeIcon;

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
  }

  Future<void> _loadMarkerIcons() async {
    try {
            riderIcon = await _getMarkerIcon('assets/images/rider_marker.png', 120);
      restaurantIcon = await _getMarkerIcon('assets/images/restaurant-marker.png', 80);
      homeIcon = await _getMarkerIcon('assets/images/home-marker.png', 80);
    } catch (e) {
      // Log or handle asset loading errors
    }
    if (mounted) {
      _setupInitialMarkers();
      _initWebSocket();
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
    if (restaurantIcon != null) {
      final restaurantMarker = Marker(
        markerId: const MarkerId('restaurant'),
        position: LatLng(widget.order.restaurant.lat, widget.order.restaurant.lng),
        infoWindow: InfoWindow(title: widget.order.restaurant.name),
        icon: restaurantIcon!,
      );
      _markers.add(restaurantMarker);
    }

    if (homeIcon != null) {
      final deliveryMarker = Marker(
        markerId: const MarkerId('delivery'),
        position: LatLng(widget.order.deliveryLat, widget.order.deliveryLng),
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: homeIcon!,
      );
      _markers.add(deliveryMarker);
    }
    setState(() {});
  }

  void _initWebSocket() {
    final uri = Uri.parse('$kWebSocketUrl/ws/tracking/${widget.order.id}/');
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
      // Handle WebSocket errors
    }, onDone: () {
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
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        title: Text('Tracking Order #${widget.order.id}'),
        backgroundColor: Colors.orange,
      ),
      body: GoogleMap(
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
      ),
    );
  }
}
