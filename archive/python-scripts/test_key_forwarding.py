#!/usr/bin/env python3

import asyncio
import websockets
import json
import time

async def test_key_forwarding():
    """Test key forwarding with the emulator server"""
    
    # Connect to WebSocket server
    uri = "ws://localhost:8765"
    
    try:
        print("🔌 Connecting to WebSocket server...")
        async with websockets.connect(uri) as websocket:
            print("✅ Connected to WebSocket server")
            
            # Wait for initial connection message
            initial_msg = await websocket.recv()
            initial_data = json.loads(initial_msg)
            print(f"📨 Initial message: {initial_data}")
            
            # Test status request
            print("\n📊 Testing status request...")
            await websocket.send(json.dumps({'type': 'status'}))
            status_response = await websocket.recv()
            status_data = json.loads(status_response)
            print(f"📊 Status: {status_data}")
            
            # Test key presses
            test_keys = ['A', 'S', 'D', 'SPACE', 'Q', 'O', 'P']
            
            print(f"\n🎮 Testing key forwarding with keys: {test_keys}")
            print("=" * 60)
            
            for key in test_keys:
                print(f"\n⌨️  Testing key: {key}")
                
                # Send key press
                press_msg = {
                    'type': 'key_input',
                    'key': key,
                    'action': 'press',
                    'timestamp': time.time()
                }
                
                print(f"📤 Sending key press: {press_msg}")
                await websocket.send(json.dumps(press_msg))
                
                # Wait for response
                press_response = await websocket.recv()
                press_data = json.loads(press_response)
                
                if press_data.get('processed'):
                    print(f"✅ Key press SUCCESS: {press_data.get('message')}")
                else:
                    print(f"❌ Key press FAILED: {press_data.get('message')}")
                
                # Wait a moment
                await asyncio.sleep(0.1)
                
                # Send key release
                release_msg = {
                    'type': 'key_input',
                    'key': key,
                    'action': 'release',
                    'timestamp': time.time()
                }
                
                print(f"📤 Sending key release: {release_msg}")
                await websocket.send(json.dumps(release_msg))
                
                # Wait for response
                release_response = await websocket.recv()
                release_data = json.loads(release_response)
                
                if release_data.get('processed'):
                    print(f"✅ Key release SUCCESS: {release_data.get('message')}")
                else:
                    print(f"❌ Key release FAILED: {release_data.get('message')}")
                
                print("-" * 40)
                await asyncio.sleep(0.5)  # Wait between keys
            
            print("\n🎯 Key forwarding test completed!")
            
    except websockets.exceptions.ConnectionRefusedError:
        print("❌ Connection refused - make sure the server is running on localhost:8765")
    except Exception as e:
        print(f"❌ Test error: {e}")

async def test_health_endpoint():
    """Test the health endpoint"""
    import aiohttp
    
    try:
        print("🏥 Testing health endpoint...")
        async with aiohttp.ClientSession() as session:
            async with session.get('http://localhost:8080/health') as response:
                if response.status == 200:
                    health_data = await response.json()
                    print(f"✅ Health check SUCCESS: {health_data}")
                else:
                    print(f"❌ Health check FAILED: Status {response.status}")
    except Exception as e:
        print(f"❌ Health check error: {e}")

async def main():
    """Main test function"""
    print("🧪 ZX Spectrum Emulator Key Forwarding Test")
    print("=" * 50)
    
    # Test health endpoint first
    await test_health_endpoint()
    
    print("\n" + "=" * 50)
    
    # Test key forwarding
    await test_key_forwarding()

if __name__ == '__main__':
    asyncio.run(main())
