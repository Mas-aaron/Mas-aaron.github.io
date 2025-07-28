import asyncio
import websockets
import json

def format_message(message):
    # Add timestamp and separator for readability
    return f"[{asyncio.get_event_loop().time():.3f}] {message}"

async def test_websocket():
    uri = "ws://10.5.55.169:8000/ws/track/21/"
    print(format_message(f"Attempting to connect to {uri}"))
    
    try:
        async with websockets.connect(uri) as websocket:
            print(format_message("Connected successfully!"))
            print(format_message("Waiting for messages... (Press Ctrl+C to stop)"))
            
            try:
                while True:
                    message = await websocket.recv()
                    print(format_message(f"Received: {message}"))
                    
                    # Try to parse as JSON
                    try:
                        data = json.loads(message)
                        print(format_message(f"Parsed data: {data}"))
                    except json.JSONDecodeError as e:
                        print(format_message(f"Failed to parse JSON: {e}"))
                        
            except websockets.exceptions.ConnectionClosed:
                print(format_message("Connection closed by server"))
                
    except Exception as e:
        print(format_message(f"Failed to connect: {e}"))
        print(format_message(f"Error type: {type(e)}"))

if __name__ == "__main__":
    print(format_message("Starting WebSocket test"))
    try:
        asyncio.run(test_websocket())
    except KeyboardInterrupt:
        print(format_message("Test interrupted by user"))
