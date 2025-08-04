#!/usr/bin/env python3
"""
Debug script to test key injection functionality
"""
import asyncio
import websockets
import json
import sys

async def test_key_injection():
    uri = "wss://d112s3ps8xh739.cloudfront.net/ws/"
    
    try:
        print(f"🔌 Connecting to {uri}")
        async with websockets.connect(uri) as websocket:
            print("✅ Connected to WebSocket")
            
            # Send a test key press
            test_message = {
                "type": "key_press",
                "key": "A"
            }
            
            print(f"📤 Sending: {test_message}")
            await websocket.send(json.dumps(test_message))
            
            # Wait for response
            try:
                response = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                print(f"📥 Received: {response}")
            except asyncio.TimeoutError:
                print("⏰ No response received within 5 seconds")
                
            # Send another test
            test_message2 = {
                "type": "key_press", 
                "key": "SPACE"
            }
            
            print(f"📤 Sending: {test_message2}")
            await websocket.send(json.dumps(test_message2))
            
            try:
                response2 = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                print(f"📥 Received: {response2}")
            except asyncio.TimeoutError:
                print("⏰ No response received within 5 seconds")
                
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    asyncio.run(test_key_injection())
