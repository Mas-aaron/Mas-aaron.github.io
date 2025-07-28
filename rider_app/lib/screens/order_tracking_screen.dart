import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:convert';

import 'package:rider_app/models/order.dart';
import 'package:rider_app/services/api_service.dart';
import 'package:rider_app/constants.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class OrderTrackingScreen extends StatefulWidget {
    final Order order;
  final ApiService apiService;

    const OrderTrackingScreen({super.key, required this.order, required this.apiService});

  @override
  _OrderTrackingScreenState createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _polylineCoordinates = [];
  final PolylinePoints _polylinePoints = PolylinePoints();
  WebSocketChannel? _channel;
  Timer? _broadcastTimer;
  Timer? _reconnectTimer;
  bool _wsConnected = false;
  bool _showWsError = false;

  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  LocationData? _currentLocation;

  @override
  void initState() {
    super.initState();
    _setMarkers();
    _initializeLocation();
    _getRouteAndDrawPolyline();
    _initializeWebSocket();
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

    void _initializeWebSocket() async {
    final token = await widget.apiService.getToken();
    if (token == null) {
      print('Error: Auth token is null. Cannot connect to WebSocket.');
      setState(() {
        _showWsError = true; // Show an error state on the UI
      });
      return;
    }
        final wsUrl = Uri.parse('$websocketUrl/ws/track/${widget.order.id}/?token=$token');
  _showWsError = false;
  _wsConnected = false;
  _channel = WebSocketChannel.connect(wsUrl);
  _wsConnected = true;
  setState(() {});

  _channel!.stream.listen(
    (event) {
      _wsConnected = true;
      _showWsError = false;
      setState(() {});
    },
    onDone: _scheduleReconnect,
    onError: (_) {
      _showWsError = true;
      _wsConnected = false;
      setState(() {});
      _scheduleReconnect();
    },
    cancelOnError: true,
  );
}

void _scheduleReconnect() {
  _reconnectTimer?.cancel();
  _reconnectTimer = Timer(const Duration(seconds: 3), () {
    if (mounted) _initializeWebSocket();
  });
}

void _sendLocationData(LocationData locationData) {
  if (!_wsConnected || _channel == null || locationData.latitude == null || locationData.longitude == null) {
    return;
  }
  if (!_shouldBroadcast()) {
    return;
  }
  final data = jsonEncode({
    'latitude': locationData.latitude,
    'longitude': locationData.longitude,
  });
  try {
    _channel!.sink.add(data);
  } catch (_) {
    _showWsError = true;
    setState(() {});
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
      return;
    }

    PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: googleMapsApiKey,
        request: PolylineRequest(
            origin: PointLatLng(restaurantLat, restaurantLng),
            destination: PointLatLng(customerLat, customerLng),
            mode: TravelMode.driving));

    if (result.points.isNotEmpty) {
      for (var point in result.points) {
        _polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }
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

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }


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
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
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
  @override
  void dispose() {
    _locationSubscription?.cancel();
    _broadcastTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Default to a central location if no coordinates are available yet
    final initialLat = widget.order.restaurantLat ?? 37.422;
    final initialLng = widget.order.restaurantLng ?? -122.084;

    final CameraPosition initialCameraPosition = CameraPosition(
      target: LatLng(initialLat, initialLng),
      zoom: 12,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Delivery Route'),
        actions: [
          IconButton(
            icon: Icon(Icons.my_location),
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
    );
  }
}
