#!/usr/bin/env python3
"""
Minimal WebSocket Server Test - Focus on key forwarding only
"""

import asyncio
import websockets
import json
import subprocess
import logging
import time

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class MinimalKeyServer:
    def __init__(self):
        self.connected_clients = set()
        
        # Key mapping for ZX Spectrum
        self.key_mapping = {
            'A': 'a', 'B': 'b', 'C': 'c', 'D': 'd', 'E': 'e', 'F': 'f', 'G': 'g', 'H': 'h',
            'I': 'i', 'J': 'j', 'K': 'k', 'L': 'l', 'M': 'm', 'N': 'n', 'O': 'o', 'P': 'p',
            'Q': 'q', 'R': 'r', 'S': 's', 'T': 't', 'U': 'u', 'V': 'v', 'W': 'w', 'X': 'x',
            'Y': 'y', 'Z': 'z',
            '0': '0', '1': '1', '2': '2', '3': '3', '4': '4', '5': '5', '6': '6', '7': '7', '8': '8', '9': '9',
            'SPACE': 'space',
            'ENTER': 'Return',
        }

    def send_key_to_emulator(self, key):
        """Send key press to FUSE emulator using xdotool"""
        try:
            # Map the key to X11 key name
            x11_key = self.key_mapping.get(key, key.lower())
            
            # Use xdotool to send key to the FUSE window
            result = subprocess.run([
                'xdotool', 
                'search', '--name', 'Fuse',
                'windowfocus',
                'key', x11_key
            ], env={'DISPLAY': ':99'}, capture_output=True, text=True)
            
            if result.returncode == 0:
                logger.info(f"✅ Successfully sent key '{key}' (mapped to '{x11_key}') to FUSE emulator")
                return True, f"Key '{key}' sent successfully"
            else:
                logger.error(f"❌ Failed to send key '{key}': {result.stderr}")
                return False, f"xdotool error: {result.stderr.strip()}"
                
        except Exception as e:
            logger.error(f"❌ Exception sending key '{key}' to emulator: {e}")
            return False, f"Exception: {str(e)}"

    async def handle_client(self, websocket, path):
        """Handle WebSocket client connections"""
        self.connected_clients.add(websocket)
        logger.info(f"Client connected. Total clients: {len(self.connected_clients)}")
        
        try:
            # Send welcome message
            welcome_msg = {
                "type": "connected",
                "message": "Minimal key server ready",
                "timestamp": time.time()
            }
            await websocket.send(json.dumps(welcome_msg))
            
            async for message in websocket:
                try:
                    data = json.loads(message)
                    logger.info(f"Received message: {data}")
                    
                    if data.get('type') == 'key_press':
                        key = data.get('key', '').upper()
                        
                        if key:
                            success, message = self.send_key_to_emulator(key)
                            
                            response = {
                                "type": "key_response",
                                "key": key,
                                "success": success,
                                "message": message,
                                "timestamp": time.time()
                            }
                            
                            await websocket.send(json.dumps(response))
                        else:
                            error_response = {
                                "type": "error",
                                "message": "No key specified",
                                "timestamp": time.time()
                            }
                            await websocket.send(json.dumps(error_response))
                    
                    elif data.get('type') == 'ping':
                        pong_response = {
                            "type": "pong",
                            "timestamp": time.time()
                        }
                        await websocket.send(json.dumps(pong_response))
                    
                    else:
                        error_response = {
                            "type": "error",
                            "message": f"Unknown message type: {data.get('type')}",
                            "timestamp": time.time()
                        }
                        await websocket.send(json.dumps(error_response))
                        
                except json.JSONDecodeError:
                    error_response = {
                        "type": "error",
                        "message": "Invalid JSON",
                        "timestamp": time.time()
                    }
                    await websocket.send(json.dumps(error_response))
                    
                except Exception as e:
                    logger.error(f"Error handling message: {e}")
                    error_response = {
                        "type": "error",
                        "message": str(e),
                        "timestamp": time.time()
                    }
                    await websocket.send(json.dumps(error_response))
                    
        except websockets.exceptions.ConnectionClosed:
            logger.info("Client disconnected")
        except Exception as e:
            logger.error(f"Client handler error: {e}")
        finally:
            self.connected_clients.discard(websocket)
            logger.info(f"Client removed. Total clients: {len(self.connected_clients)}")

    async def start_server(self):
        """Start the WebSocket server"""
        logger.info("Starting minimal WebSocket key server on port 8765")
        
        server = await websockets.serve(
            self.handle_client,
            "localhost",
            8765
        )
        
        logger.info("✅ WebSocket server started on ws://localhost:8765")
        logger.info("Ready to receive key press commands!")
        
        # Keep the server running
        await server.wait_closed()

if __name__ == "__main__":
    server = MinimalKeyServer()
    
    try:
        asyncio.run(server.start_server())
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
    except Exception as e:
        logger.error(f"Server error: {e}")
