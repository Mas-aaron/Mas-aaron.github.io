import requests
import os

# First, get a fresh authentication token
login_url = "https://food-delivery-backend-2mcb.onrender.com/api/login/"
login_data = {
    'username': 'bettybinega@yahoo.com',
    'password': '@a22%17#'
}

print("Getting fresh authentication token...")
login_response = requests.post(login_url, data=login_data)
print(f"Login Status Code: {login_response.status_code}")

if login_response.status_code == 200:
    token_data = login_response.json()
    access_token = token_data.get('token')  # Auth token endpoint returns 'token', not 'access'
    print(f"Got fresh token: {access_token[:50]}...")
    
    # Test image upload to debug the issue
    url = "https://food-delivery-backend-2mcb.onrender.com/api/menu-items/1/"
    headers = {
        'Authorization': f'Token {access_token}'  # Use Token instead of Bearer
    }
else:
    print(f"Login failed: {login_response.text}")
    exit(1)

# Prepare the data
data = {
    'name': 'Test Chicken Debug',
    'description': 'Debug test upload',
    'price': '15000',
    'category': '1'  # Add the required category field
}

# Check if image file exists
image_path = 'images (1).jpg'
if os.path.exists(image_path):
    with open(image_path, 'rb') as image_file:
        files = {'image': image_file}
        
        print(f"Uploading image: {image_path}")
        print(f"File size: {os.path.getsize(image_path)} bytes")
        
        response = requests.put(url, headers=headers, data=data, files=files)
        
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
else:
    print(f"Image file not found: {image_path}")
