import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:food_delivery_app/models/order.dart';
import 'package:food_delivery_app/services/api_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:food_delivery_app/constants.dart';
import 'package:geolocator/geolocator.dart';

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
  bool _myLocationEnabled = false;

  Future<Order>? _futureOrder;
  String? _currentStatus;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final PolylinePoints _polylinePoints = PolylinePoints();

  @override
  void initState() {
    super.initState();
    _futureOrder = _initializeScreen();
  }

  Future<Order> _initializeScreen() async {
    await _requestLocationPermission();
    final order = await _apiService.getOrderDetails(widget.orderId);

    if (mounted) {
      setState(() {
        _currentStatus = order.status;
        _setMarkers(order);
      });

      // Use a small delay to ensure the UI is fully rendered before initializing WebSocket
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _initializeWebSocket();
          _getRouteAndDrawPolyline(order);
        }
      });
    }
    return order;
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, handle appropriately.
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return;
    }

    if (mounted) {
      setState(() {
        _myLocationEnabled = true;
      });
    }
  }



  void _initializeWebSocket() {
    final urlString = '$webSocketUrl/ws/track/${widget.orderId}/';
    print('Connecting to WebSocket: $urlString');
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(urlString));
      print('WebSocket channel created successfully');
      
      // Add a small delay to ensure connection is established
      Future.delayed(Duration(milliseconds: 500), () {
        if (_channel != null) {
          print('WebSocket connection status check: Channel exists');
        } else {
          print('WebSocket connection status check: Channel is null');
        }
      });

      _channel!.stream.listen(
        (data) {
          if (!mounted) return;
          print('WebSocket received: $data');
          
          try {
            final decodedData = jsonDecode(data);
            print('Decoded data: $decodedData');
            
            // Check if this is a direct location update (not wrapped in 'message')
            if (decodedData is Map<String, dynamic> && 
                decodedData['latitude'] != null && 
                decodedData['longitude'] != null) {
              print('Direct location update received');
              final lat = decodedData['latitude'].toDouble();
              final lng = decodedData['longitude'].toDouble();
              print('Updating rider position to: ($lat, $lng)');
              _animateRiderMarker(LatLng(lat, lng));
              return;
            }
            
            final message = decodedData['message'];
            if (message is! Map<String, dynamic>) {
              print('Invalid message format: $message');
              return;
            }
            print('Message content: $message');

            if (message['latitude'] != null && message['longitude'] != null) {
              final lat = message['latitude'].toDouble();
              final lng = message['longitude'].toDouble();
              print('Updating rider position to: ($lat, $lng)');
              _animateRiderMarker(LatLng(lat, lng));
            }

            if (message['status'] != null && _lastStatus != message['status']) {
              if (mounted) {
                setState(() {
                  _currentStatus = message['status'];
                  _lastStatus = message['status'];
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Order status: ${message['status']}')),
                );
              }
            }
          } catch (e) {
            print('Error processing WebSocket message: $e');
            print('Error type: ${e.runtimeType}');
          }
        },
        onDone: () {
          print('WebSocket connection closed.');
          print('Connection closed at: ${DateTime.now()}');
          _scheduleReconnect();
        },
        onError: (error) {
          print('WebSocket error: $error');
          print('Error occurred at: ${DateTime.now()}');
          print('Error type: ${error.runtimeType}');
          // Add more detailed error information
          if (error is WebSocketChannelException) {
            print('WebSocketChannelException details: ${error.message}');
          }
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
      print('WebSocket stream listener attached');
      print('WebSocket connection initiated at: ${DateTime.now()}');
      
      // Add a timeout to detect if connection fails to establish
      Future.delayed(const Duration(seconds: 15), () {
        if (_channel != null) {
          print('WebSocket connection verification: Still active');
        }
      });
    } catch (e) {
      print('Error initializing WebSocket: $e');
      print('Error occurred at: ${DateTime.now()}');
      print('Error type: ${e.runtimeType}');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _initializeWebSocket();
    });
  }

  void _animateRiderMarker(LatLng newPos) async {
    if (!mounted) return;

    await _setRiderMarker(newPos); // Ensure the marker is updated before redrawing

    if (mounted) {
      setState(() {
        // The _markers set is now updated, just trigger a rebuild and zoom.
        _autoZoom();
      });
    }
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  Future<void> _setRiderMarker(LatLng position) async {
    // This function just updates the marker data set. It does not call setState itself.
    _markers.removeWhere((m) => m.markerId.value == 'rider');
    
        final Uint8List markerIcon = await getBytesFromAsset('assets/images/rider_marker.png', 100);

    _markers.add(
      Marker(
        markerId: const MarkerId('rider'),
        position: position,
        icon: BitmapDescriptor.fromBytes(markerIcon),
        infoWindow: const InfoWindow(title: 'Rider'),
      ),
    );
  }

  void _autoZoom() async {
    // Always try to auto-zoom, even with a single marker
    if (_markers.isEmpty) return;
    
    try {
      final GoogleMapController controller = await _mapController.future;
      
      if (_markers.length == 1) {
        // If there's only one marker, just center on it
        final marker = _markers.first;
        controller.animateCamera(CameraUpdate.newLatLng(marker.position));
      } else {
        // If there are multiple markers, fit them all in view
        LatLngBounds bounds = _computeBounds(_markers.map((m) => m.position).toList());
        controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      }
    } catch (e) {
      print('Error in _autoZoom: $e');
    }
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
    print('Setting markers for Order ID: ${order.id}');
    print('Restaurant Coords: (${order.restaurantLat}, ${order.restaurantLng})');
    print('Customer Coords: (${order.customerLat}, ${order.customerLng})');
    final restaurantPosition = LatLng(order.restaurantLat!, order.restaurantLng!); 
    final customerPosition = LatLng(order.customerLat!, order.customerLng!);

    _markers.add(Marker(
      markerId: const MarkerId('restaurant'),
      position: restaurantPosition,
      infoWindow: const InfoWindow(title: 'Restaurant'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
    ));

    _markers.add(Marker(
      markerId: const MarkerId('customer'),
      position: customerPosition,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(title: 'Your Location'),
    ));

    // Set the initial rider position
    _setRiderMarker(restaurantPosition);
  }

  void _getRouteAndDrawPolyline(Order order) async {
    if (order.restaurantLat == null ||
        order.restaurantLng == null ||
        order.customerLat == null ||
        order.customerLng == null) {
      return;
    }

    final restaurantPosition = PointLatLng(order.restaurantLat!, order.restaurantLng!); 
    final customerPosition = PointLatLng(order.customerLat!, order.customerLng!);

    PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: googleMapsApiKey,
      request: PolylineRequest(
        origin: restaurantPosition,
        destination: customerPosition,
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
                    target: LatLng(
                      (order.restaurantLat! + order.customerLat!) / 2,
                      (order.restaurantLng! + order.customerLng!) / 2,
                    ),
                    zoom: 12.5,
                  ),
                                    myLocationEnabled: _myLocationEnabled,
                  myLocationButtonEnabled: true, // Keep the button always visible for now
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
