import asyncio
import websockets
import json

async def listen_to_order(order_id):
    # IMPORTANT: Make sure this IP address is your PC's local IP, the same one your Flutter app uses.
    # You can find it by running `ipconfig` in your command prompt.
    uri = f"ws://10.5.55.169:8000/ws/track/{order_id}/"
    print(f"Connecting to {uri}...")
    try:
        async with websockets.connect(uri) as websocket:
            print(f"Successfully connected to WebSocket for order {order_id}.")
            print("Waiting for location updates...")
            try:
                while True:
                    message = await websocket.recv()
                    data = json.loads(message)
                    print(f"Received location update: {data}")
            except websockets.exceptions.ConnectionClosed as e:
                print(f"Connection closed: {e}")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    # The order ID you want to track
    ORDER_ID_TO_TRACK = 21
    try:
        asyncio.run(listen_to_order(ORDER_ID_TO_TRACK))
    except KeyboardInterrupt:
        print("\nExiting.")
