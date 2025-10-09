
const String googleMapsApiKey = 'AIzaSyB2_rwYdL9Tr_LWV7PDfn83n8-2_6KVahs'; // Replace with your key

// --- RENDER PRODUCTION (ACTIVE) --- 
// Using Render hosted backend
const String baseUrl = 'https://food-delivery-backend-2mcb.onrender.com/api';
const String baseWebsocketUrl = 'wss://food-delivery-backend-2mcb.onrender.com';
const String websocketUrl = '$baseWebsocketUrl/ws/notifications/';

// --- LOCAL DEVELOPMENT (COMMENTED OUT) --- 
// const String baseUrl = 'http://127.0.0.1:8000/api';
// const String baseWebsocketUrl = 'ws://127.0.0.1:8000';
// const String websocketUrl = '$baseWebsocketUrl/ws/notifications/';

// Alternative HTTP endpoint for testing if HTTPS fails
// const String baseUrlHttp = 'http://10.5.55.106:8000/api';