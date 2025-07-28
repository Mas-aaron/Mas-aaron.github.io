import asyncio
import websockets
import json

def get_tracking_url(order_id, host='10.5.55.169', port=8000):
    return f"ws://{host}:{port}/ws/track/{order_id}/"

async def test_websocket_connection(order_id):
    url = get_tracking_url(order_id)
    print(f"Connecting to: {url}")
    
    try:
        async with websockets.connect(url) as websocket:
            print("Connected successfully!")
            print("Waiting for messages...")
            
            # Listen for messages for 30 seconds
            for i in range(30):
                try:
                    message = await asyncio.wait_for(websocket.recv(), timeout=1.0)
                    print(f"Received: {message}")
                    
                    # Try to decode the message
                    try:
                        data = json.loads(message)
                        print(f"Decoded: {data}")
                    except json.JSONDecodeError as e:
                        print(f"Failed to decode JSON: {e}")
                except asyncio.TimeoutError:
                    print("No message received in 1 second")
                    
    except Exception as e:
        print(f"Connection failed: {e}")

if __name__ == "__main__":
    # Test with order #11
    asyncio.run(test_websocket_connection(11))
