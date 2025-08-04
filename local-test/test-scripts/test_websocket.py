#!/usr/bin/env python3
"""
WebSocket Connection Test
========================

Tests WebSocket connectivity and message handling for the local emulator server.
"""

import asyncio
import websockets
import json
import sys
import time

class WebSocketTester:
    def __init__(self, url="ws://localhost:8765"):
        self.url = url
        self.websocket = None
        self.tests_passed = 0
        self.tests_failed = 0
    
    async def connect(self):
        """Test WebSocket connection"""
        print(f"🔌 Testing WebSocket connection to {self.url}")
        try:
            self.websocket = await websockets.connect(self.url)
            print("✅ WebSocket connection successful")
            self.tests_passed += 1
            return True
        except Exception as e:
            print(f"❌ WebSocket connection failed: {e}")
            self.tests_failed += 1
            return False
    
    async def test_welcome_message(self):
        """Test that server sends welcome message"""
        print("📨 Testing welcome message...")
        try:
            # Wait for welcome message
            message = await asyncio.wait_for(self.websocket.recv(), timeout=5.0)
            data = json.loads(message)
            
            if data.get('type') == 'connected':
                print("✅ Welcome message received")
                print(f"   Emulator running: {data.get('emulator_running')}")
                print(f"   HLS streaming: {data.get('hls_streaming')}")
                print(f"   YouTube streaming: {data.get('youtube_streaming')}")
                self.tests_passed += 1
                return True
            else:
                print(f"❌ Unexpected welcome message: {data}")
                self.tests_failed += 1
                return False
                
        except asyncio.TimeoutError:
            print("❌ No welcome message received within timeout")
            self.tests_failed += 1
            return False
        except Exception as e:
            print(f"❌ Error receiving welcome message: {e}")
            self.tests_failed += 1
            return False
    
    async def test_key_press(self, key="SPACE"):
        """Test key press message"""
        print(f"⌨️ Testing key press: {key}")
        try:
            # Send key press
            message = {
                "type": "key_press",
                "key": key
            }
            await self.websocket.send(json.dumps(message))
            print(f"📤 Sent key press: {key}")
            
            # Wait for response
            response = await asyncio.wait_for(self.websocket.recv(), timeout=5.0)
            data = json.loads(response)
            
            if data.get('type') == 'key_response' and data.get('key') == key:
                success = data.get('success', False)
                if success:
                    print(f"✅ Key press '{key}' successful")
                    self.tests_passed += 1
                else:
                    print(f"⚠️ Key press '{key}' sent but not successful (emulator may not be running)")
                    self.tests_passed += 1  # Still counts as communication success
                return True
            else:
                print(f"❌ Unexpected key response: {data}")
                self.tests_failed += 1
                return False
                
        except asyncio.TimeoutError:
            print(f"❌ No response to key press '{key}' within timeout")
            self.tests_failed += 1
            return False
        except Exception as e:
            print(f"❌ Error testing key press: {e}")
            self.tests_failed += 1
            return False
    
    async def test_status_request(self):
        """Test status request"""
        print("📊 Testing status request...")
        try:
            # Send status request
            message = {"type": "status"}
            await self.websocket.send(json.dumps(message))
            print("📤 Sent status request")
            
            # Wait for response
            response = await asyncio.wait_for(self.websocket.recv(), timeout=5.0)
            data = json.loads(response)
            
            if data.get('type') == 'status_response':
                print("✅ Status response received")
                print(f"   Emulator running: {data.get('emulator_running')}")
                print(f"   HLS streaming: {data.get('hls_streaming')}")
                print(f"   YouTube streaming: {data.get('youtube_streaming')}")
                self.tests_passed += 1
                return True
            else:
                print(f"❌ Unexpected status response: {data}")
                self.tests_failed += 1
                return False
                
        except asyncio.TimeoutError:
            print("❌ No status response within timeout")
            self.tests_failed += 1
            return False
        except Exception as e:
            print(f"❌ Error testing status request: {e}")
            self.tests_failed += 1
            return False
    
    async def test_start_emulator(self):
        """Test start emulator command"""
        print("🎮 Testing start emulator command...")
        try:
            # Send start emulator command
            message = {"type": "start_emulator"}
            await self.websocket.send(json.dumps(message))
            print("📤 Sent start emulator command")
            
            # Wait for response
            response = await asyncio.wait_for(self.websocket.recv(), timeout=10.0)
            data = json.loads(response)
            
            if data.get('type') == 'emulator_status':
                running = data.get('running', False)
                message_text = data.get('message', '')
                
                if running:
                    print(f"✅ Emulator started successfully: {message_text}")
                else:
                    print(f"⚠️ Emulator start attempted: {message_text}")
                
                self.tests_passed += 1
                return True
            else:
                print(f"❌ Unexpected emulator response: {data}")
                self.tests_failed += 1
                return False
                
        except asyncio.TimeoutError:
            print("❌ No emulator response within timeout")
            self.tests_failed += 1
            return False
        except Exception as e:
            print(f"❌ Error testing start emulator: {e}")
            self.tests_failed += 1
            return False
    
    async def run_all_tests(self):
        """Run all WebSocket tests"""
        print("🧪 Starting WebSocket Tests")
        print("=" * 40)
        
        # Test connection
        if not await self.connect():
            print("❌ Cannot proceed without WebSocket connection")
            return False
        
        # Run tests
        await self.test_welcome_message()
        await self.test_status_request()
        await self.test_start_emulator()
        await self.test_key_press("SPACE")
        await self.test_key_press("Q")
        await self.test_key_press("ENTER")
        
        # Close connection
        if self.websocket:
            await self.websocket.close()
            print("🔌 WebSocket connection closed")
        
        # Print results
        print("\n" + "=" * 40)
        print("🧪 WebSocket Test Results")
        print("=" * 40)
        print(f"✅ Tests passed: {self.tests_passed}")
        print(f"❌ Tests failed: {self.tests_failed}")
        print(f"📊 Success rate: {self.tests_passed/(self.tests_passed + self.tests_failed)*100:.1f}%")
        
        return self.tests_failed == 0

async def main():
    """Main test function"""
    if len(sys.argv) > 1:
        url = sys.argv[1]
    else:
        url = "ws://localhost:8765"
    
    tester = WebSocketTester(url)
    success = await tester.run_all_tests()
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    asyncio.run(main())
