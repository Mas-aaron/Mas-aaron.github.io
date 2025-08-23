print("--- Test script starting ---")
import requests
import json
import os

# Configuration
BASE_URL = "http://localhost:8001/api"

# --- User Credentials ---
# Replace with actual user credentials for an authenticated rider
RIDER_USERNAME = "aaronmasendi@gmail.com"
RIDER_PASSWORD = "password123"

# --- Order and Location Data ---
# Replace with a valid, in-progress order ID assigned to the rider
ORDER_ID = 1 

# Simulated rider location data (latitude, longitude)
APPROACHING_LOCATION = (0.6549, 30.2794) # Exact customer location from logs
ARRIVAL_LOCATION = (0.6549, 30.2794) # Exact customer location from logs


def get_auth_token(username, password):
    """Authenticate and retrieve an auth token."""
    url = f"{BASE_URL}/login/"
    try:
        response = requests.post(url, data={'username': username, 'password': password})
        response.raise_for_status() # Raise an exception for bad status codes
        return response.json().get('token')
    except requests.exceptions.RequestException as e:
        print(f"Error getting auth token: {e}")
        return None


def update_rider_location(token, order_id, lat, lng):
    """Simulate a rider location update."""
    url = f"{BASE_URL}/rider-orders/{order_id}/location-update/"
    headers = {'Authorization': f'Token {token}', 'Content-Type': 'application/json'}
    data = {'latitude': lat, 'longitude': lng}
    try:
        response = requests.post(url, headers=headers, data=json.dumps(data), timeout=10)
        response.raise_for_status()
        print(f"Location update successful: {response.status_code}")
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error updating location: {e}")
        return None

def notify_arrival(token, order_id, lat, lng):
    """Simulate a rider arrival notification."""
    url = f"{BASE_URL}/rider-orders/{order_id}/arrival/"
    headers = {'Authorization': f'Token {token}', 'Content-Type': 'application/json'}
    data = {'latitude': lat, 'longitude': lng}
    try:
        response = requests.post(url, headers=headers, data=json.dumps(data), timeout=10)
        response.raise_for_status()
        print(f"Arrival notification successful: {response.status_code}")
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error notifying arrival: {e}")
        return None

if __name__ == "__main__":
    # 1. Get auth token for the rider
    rider_token = get_auth_token(RIDER_USERNAME, RIDER_PASSWORD)

    if rider_token:
        # 2. Simulate rider approaching
        print("\n--- Simulating Rider Approaching ---")
        update_rider_location(rider_token, ORDER_ID, APPROACHING_LOCATION[0], APPROACHING_LOCATION[1])

        # 3. Simulate rider arrival
        print("\n--- Simulating Rider Arrival ---")
        notify_arrival(rider_token, ORDER_ID, ARRIVAL_LOCATION[0], ARRIVAL_LOCATION[1])
