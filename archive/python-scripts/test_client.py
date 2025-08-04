#!/usr/bin/env python3

import asyncio
import websockets
import json
import time

async def interactive_test():
    """Interactive test client for key forwarding"""
    
    uri = "ws://localhost:8765"
    
    try:
        print("🔌 Connecting to local emulator server...")
        async with websockets.connect(uri) as websocket:
            print("✅ Connected! Waiting for initial message...")
            
            # Get initial connection message
            initial_msg = await websocket.recv()
            initial_data = json.loads(initial_msg)
            print(f"📨 Server says: {initial_data}")
            
            print("\n🎮 Interactive Key Test Mode")
            print("Commands:")
            print("  - Type a key (A, S, D, SPACE, etc.) to test")
            print("  - Type 'status' to check server status")
            print("  - Type 'quit' to exit")
            print("=" * 50)
            
            while True:
                try:
                    # Get user input
                    user_input = input("\n⌨️  Enter key to test (or command): ").strip().upper()
                    
                    if user_input == 'QUIT':
                        break
                    elif user_input == 'STATUS':
                        # Send status request
                        await websocket.send(json.dumps({'type': 'status'}))
                        response = await websocket.recv()
                        data = json.loads(response)
                        print(f"📊 Server Status: {data}")
                        continue
                    elif user_input == '':
                        continue
                    
                    # Test key press
                    print(f"🔄 Testing key: {user_input}")
                    
                    # Send key press
                    press_msg = {
                        'type': 'key_input',
                        'key': user_input,
                        'action': 'press',
                        'timestamp': time.time()
                    }
                    
                    await websocket.send(json.dumps(press_msg))
                    press_response = await websocket.recv()
                    press_data = json.loads(press_response)
                    
                    if press_data.get('processed'):
                        print(f"✅ PRESS SUCCESS: {press_data.get('message')}")
                    else:
                        print(f"❌ PRESS FAILED: {press_data.get('message')}")
                    
                    # Small delay
                    await asyncio.sleep(0.1)
                    
                    # Send key release
                    release_msg = {
                        'type': 'key_input',
                        'key': user_input,
                        'action': 'release',
                        'timestamp': time.time()
                    }
                    
                    await websocket.send(json.dumps(release_msg))
                    release_response = await websocket.recv()
                    release_data = json.loads(release_response)
                    
                    if release_data.get('processed'):
                        print(f"✅ RELEASE SUCCESS: {release_data.get('message')}")
                    else:
                        print(f"❌ RELEASE FAILED: {release_data.get('message')}")
                    
                except KeyboardInterrupt:
                    break
                except Exception as e:
                    print(f"❌ Error: {e}")
            
            print("\n👋 Goodbye!")
            
    except websockets.exceptions.ConnectionRefusedError:
        print("❌ Connection refused!")
        print("Make sure the server is running with: ./run_local_test.sh")
    except Exception as e:
        print(f"❌ Connection error: {e}")

if __name__ == '__main__':
    print("🧪 ZX Spectrum Emulator - Interactive Key Test Client")
    print("=" * 55)
    asyncio.run(interactive_test())
