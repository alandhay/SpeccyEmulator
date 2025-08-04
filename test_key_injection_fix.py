#!/usr/bin/env python3
"""
Test Key Injection Fix - Verify that keys are actually being sent to the emulator
"""

import asyncio
import websockets
import json
import time

async def test_key_injection():
    """Test the key injection fix"""
    
    print("🧪 TESTING KEY INJECTION FIX")
    print("=" * 40)
    
    # Test WebSocket connection
    uri = "wss://d112s3ps8xh739.cloudfront.net/ws/"
    
    try:
        print(f"📡 Connecting to: {uri}")
        async with websockets.connect(uri) as websocket:
            print("✅ WebSocket connection established")
            
            # Wait for welcome message
            welcome = await websocket.recv()
            welcome_data = json.loads(welcome)
            print(f"📋 Welcome message: {json.dumps(welcome_data, indent=2)}")
            
            # Check if key injection is enabled
            if welcome_data.get('key_injection_enabled'):
                print("✅ Key injection is ENABLED in the server")
            else:
                print("❌ Key injection is NOT enabled in the server")
            
            # Test status request
            print("\n📊 Testing status request...")
            status_msg = {"type": "status"}
            await websocket.send(json.dumps(status_msg))
            
            response = await websocket.recv()
            status_data = json.loads(response)
            print(f"📋 Status response: {json.dumps(status_data, indent=2)}")
            
            # Test key presses with different keys
            test_keys = ['A', 'SPACE', 'ENTER', 'Q', 'P']
            
            for key in test_keys:
                print(f"\n⌨️  Testing key: {key}")
                key_msg = {"type": "key_press", "key": key}
                await websocket.send(json.dumps(key_msg))
                
                response = await websocket.recv()
                key_data = json.loads(response)
                print(f"🔑 Key response: {json.dumps(key_data, indent=2)}")
                
                # Check if the response indicates success
                if key_data.get('success'):
                    print(f"✅ Key '{key}' was successfully sent to emulator!")
                else:
                    print(f"❌ Key '{key}' failed: {key_data.get('message', 'Unknown error')}")
                
                # Small delay between key presses
                await asyncio.sleep(0.5)
            
            print("\n🎯 KEY INJECTION TEST COMPLETE")
            print("Check the video stream to see if keys are affecting the emulator!")
            
    except Exception as e:
        print(f"❌ Test failed: {e}")

if __name__ == "__main__":
    asyncio.run(test_key_injection())
