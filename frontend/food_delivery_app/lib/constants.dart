import 'package:flutter/foundation.dart' show kIsWeb;

const String googleMapsApiKey = 'AIzaSyB2_rwYdL9Tr_LWV7PDfn83n8-2_6KVahs'; // Replace with your key

// --- LOCAL DEVELOPMENT --- 
// Use '10.4.45.171' for physical device, 10.0.2.2 for Android Emulator
// IMPORTANT: Replace with your computer's local IP address for physical device/emulator testing.
// Find it by running 'ipconfig' (Windows) or 'ifconfig' (macOS/Linux) in your terminal.
const String _localIpAddress = kIsWeb ? '127.0.0.1' : '10.32.142.80';

const String baseUrl = 'http://10.32.142.80:8000/api';
const String baseWebsocketUrl = 'ws://10.32.142.80:8000';
const String websocketUrl = '$baseWebsocketUrl/ws/notifications/';