import requests

# Test the GCS configuration endpoint
url = "https://food-delivery-backend-2mcb.onrender.com/api/configure-gcs/"

# First get admin token
login_url = "https://food-delivery-backend-2mcb.onrender.com/api/login/"
login_data = {
    'username': 'admin',  # Use admin credentials
    'password': 'admin123'
}

print("Getting admin token...")
login_response = requests.post(login_url, data=login_data)
print(f"Login Status Code: {login_response.status_code}")

if login_response.status_code == 200:
    token_data = login_response.json()
    access_token = token_data.get('token')
    print(f"Got admin token: {access_token[:20]}...")
    
    # Call GCS configuration endpoint
    headers = {'Authorization': f'Token {access_token}'}
    print("Configuring GCS bucket...")
    
    config_response = requests.post(url, headers=headers)
    print(f"Config Status Code: {config_response.status_code}")
    print(f"Config Response: {config_response.text}")
    
else:
    print(f"Login failed: {login_response.text}")
    print("Trying with different admin credentials...")
    
    # Try with different admin credentials
    login_data = {
        'username': 'admin',
        'password': 'password123'
    }
    
    login_response = requests.post(login_url, data=login_data)
    if login_response.status_code == 200:
        token_data = login_response.json()
        access_token = token_data.get('token')
        print(f"Got admin token: {access_token[:20]}...")
        
        headers = {'Authorization': f'Token {access_token}'}
        config_response = requests.post(url, headers=headers)
        print(f"Config Status Code: {config_response.status_code}")
        print(f"Config Response: {config_response.text}")
    else:
        print("Could not authenticate as admin")
