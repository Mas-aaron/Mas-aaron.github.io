
const String googleMapsApiKey = 'AIzaSyB2_rwYdL9Tr_LWV7PDfn83n8-2_6KVahs'; // Replace with your key

// --- RAILWAY PRODUCTION (ACTIVE) --- 
// Using Railway hosted backend
const String baseUrl = 'https://mas-aarongithubio-production.up.railway.app/api';
const String baseWebsocketUrl = 'wss://mas-aarongithubio-production.up.railway.app';
const String websocketUrl = '$baseWebsocketUrl/ws/notifications/';

// --- LOCAL DEVELOPMENT (COMMENTED OUT) --- 
// const String baseUrl = 'http://10.116.248.2:8000/api';
// const String baseWebsocketUrl = 'ws://10.116.248.2:8000';
// const String websocketUrl = '$baseWebsocketUrl/ws/notifications/';

// Alternative HTTP endpoint for testing if HTTPS fails
// const String baseUrlHttp = 'http://10.5.55.106:8000/api';