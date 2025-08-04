#!/usr/bin/env python3
"""
Debug Current Deployment - Check what's actually running in production
"""

import asyncio
import websockets
import json
import time

async def test_current_deployment():
    """Test the current production deployment"""
    
    print("🔍 DEBUGGING CURRENT PRODUCTION DEPLOYMENT")
    print("=" * 50)
    
    # Test WebSocket connection
    uri = "wss://d112s3ps8xh739.cloudfront.net/ws/"
    
    try:
        print(f"📡 Connecting to: {uri}")
        async with websockets.connect(uri) as websocket:
            print("✅ WebSocket connection established")
            
            # Test status request
            print("\n📊 Testing status request...")
            status_msg = {"type": "status"}
            await websocket.send(json.dumps(status_msg))
            
            response = await websocket.recv()
            status_data = json.loads(response)
            print(f"📋 Status response: {json.dumps(status_data, indent=2)}")
            
            # Test key press
            print("\n⌨️  Testing key press...")
            key_msg = {"type": "key_press", "key": "A"}
            await websocket.send(json.dumps(key_msg))
            
            response = await websocket.recv()
            key_data = json.loads(response)
            print(f"🔑 Key response: {json.dumps(key_data, indent=2)}")
            
            # Test another key
            print("\n⌨️  Testing SPACE key...")
            space_msg = {"type": "key_press", "key": "SPACE"}
            await websocket.send(json.dumps(space_msg))
            
            response = await websocket.recv()
            space_data = json.loads(response)
            print(f"🚀 Space response: {json.dumps(space_data, indent=2)}")
            
            print("\n✅ WebSocket communication test complete")
            
    except Exception as e:
        print(f"❌ WebSocket test failed: {e}")

if __name__ == "__main__":
    asyncio.run(test_current_deployment())
