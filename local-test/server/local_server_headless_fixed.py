#!/usr/bin/env python3
"""
Local ZX Spectrum Emulator Server for Headless Testing - Fixed Ports
====================================================================

Uses different ports to avoid conflicts with production services:
- Web: 8001 (instead of 8000)
- Health: 8081 (instead of 8080) 
- WebSocket: 8766 (instead of 8765)
"""

import asyncio
import websockets
import json
import subprocess
import logging
import signal
import sys
import os
import time
import threading
from aiohttp import web
import http.server
import socketserver
from pathlib import Path

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class HeadlessZXSpectrumEmulatorServer:
    def __init__(self):
        self.websocket_clients = set()
        self.emulator_process = None
        self.ffmpeg_hls_process = None
        self.ffmpeg_youtube_process = None
        self.xvfb_process = None
        self.running = False
        
        # Local paths
        self.base_path = Path(__file__).parent.parent
        self.stream_path = self.base_path / "stream" / "hls"
        self.web_path = self.base_path / "web"
        self.logs_path = self.base_path / "logs"
        
        # Ensure directories exist
        self.stream_path.mkdir(parents=True, exist_ok=True)
        self.logs_path.mkdir(parents=True, exist_ok=True)
        
        # Configuration - using different ports to avoid conflicts
        self.websocket_port = 8766
        self.health_port = 8081
        self.web_port = 8001
        self.display = ":99"
        self.youtube_stream_key = os.getenv('YOUTUBE_STREAM_KEY', '')
        
        logger.info(f"Headless local server initialized with ports: web={self.web_port}, health={self.health_port}, ws={self.websocket_port}")

    def check_dependencies(self):
        """Check if required dependencies are available"""
        dependencies = ['fuse-sdl', 'ffmpeg', 'xdotool', 'Xvfb']
        missing = []
        
        for dep in dependencies:
            try:
                subprocess.run(['which', dep], check=True, capture_output=True)
                logger.info(f"✓ {dep} is available")
            except subprocess.CalledProcessError:
                missing.append(dep)
                logger.error(f"✗ {dep} is missing")
        
        if missing:
            logger.error(f"Missing dependencies: {', '.join(missing)}")
            return False
        
        return True

    def start_virtual_display(self):
        """Start Xvfb virtual display"""
        try:
            cmd = [
                'Xvfb', self.display,
                '-screen', '0', '320x240x24',
                '-ac', '+extension', 'GLX'
            ]
            
            logger.info(f"Starting virtual display: {' '.join(cmd)}")
            self.xvfb_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            time.sleep(2)
            
            if self.xvfb_process.poll() is None:
                logger.info(f"✓ Virtual display started on {self.display}")
                os.environ['DISPLAY'] = self.display
                
                try:
                    subprocess.run(['xdpyinfo'], check=True, capture_output=True, 
                                 env={'DISPLAY': self.display})
                    logger.info("✓ Virtual display is accessible")
                    return True
                except subprocess.CalledProcessError:
                    logger.error("✗ Virtual display is not accessible")
                    return False
            else:
                logger.error("✗ Virtual display failed to start")
                return False
                
        except Exception as e:
            logger.error(f"Failed to start virtual display: {e}")
            return False

    def start_web_server(self):
        """Start local web server for testing"""
        try:
            os.chdir(self.web_path)
            handler = http.server.SimpleHTTPRequestHandler
            httpd = socketserver.TCPServer(("", self.web_port), handler)
            
            def serve():
                logger.info(f"Web server started on http://localhost:{self.web_port}")
                httpd.serve_forever()
            
            web_thread = threading.Thread(target=serve, daemon=True)
            web_thread.start()
            
            return httpd
            
        except Exception as e:
            logger.error(f"Failed to start web server: {e}")
            return None

    def start_emulator(self):
        """Start FUSE emulator on virtual display"""
        try:
            env = os.environ.copy()
            env['DISPLAY'] = self.display
            env['SDL_VIDEODRIVER'] = 'x11'
            
            cmd = [
                'fuse-sdl',
                '--machine', '48',
                '--graphics-filter', 'none',
                '--no-sound'
            ]
            
            logger.info(f"Starting FUSE emulator: {' '.join(cmd)}")
            self.emulator_process = subprocess.Popen(
                cmd,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            time.sleep(3)
            
            if self.emulator_process.poll() is None:
                logger.info("✓ FUSE emulator started successfully")
                return True
            else:
                stdout, stderr = self.emulator_process.communicate()
                logger.error(f"✗ FUSE emulator failed to start")
                logger.error(f"stdout: {stdout.decode()}")
                logger.error(f"stderr: {stderr.decode()}")
                return False
                
        except Exception as e:
            logger.error(f"Failed to start emulator: {e}")
            return False

    def start_hls_streaming(self):
        """Start HLS video streaming from virtual display"""
        try:
            cmd = [
                'ffmpeg',
                '-f', 'x11grab',
                '-i', f'{self.display}.0+0,0',
                '-s', '320x240',
                '-r', '25',
                '-c:v', 'libx264',
                '-preset', 'ultrafast',
                '-tune', 'zerolatency',
                '-f', 'hls',
                '-hls_time', '2',
                '-hls_list_size', '5',
                '-hls_segment_filename', f'{self.stream_path}/stream%d.ts',
                f'{self.stream_path}/stream.m3u8'
            ]
            
            logger.info(f"Starting HLS streaming")
            self.ffmpeg_hls_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            time.sleep(5)
            
            if self.ffmpeg_hls_process.poll() is None:
                logger.info("✓ HLS streaming started successfully")
                return True
            else:
                stdout, stderr = self.ffmpeg_hls_process.communicate()
                logger.error("✗ HLS streaming failed to start")
                logger.error(f"stderr: {stderr.decode()}")
                return False
                
        except Exception as e:
            logger.error(f"Failed to start HLS streaming: {e}")
            return False

    def start_youtube_streaming(self):
        """Start YouTube RTMP streaming (optional)"""
        if not self.youtube_stream_key:
            logger.info("No YouTube stream key provided, skipping YouTube streaming")
            return True
            
        try:
            cmd = [
                'ffmpeg',
                '-f', 'x11grab',
                '-i', f'{self.display}.0+0,0',
                '-s', '320x240',
                '-r', '25',
                '-c:v', 'libx264',
                '-preset', 'fast',
                '-b:v', '2500k',
                '-maxrate', '2500k',
                '-bufsize', '5000k',
                '-f', 'flv',
                f'rtmp://a.rtmp.youtube.com/live2/{self.youtube_stream_key}'
            ]
            
            logger.info("Starting YouTube RTMP streaming")
            self.ffmpeg_youtube_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            time.sleep(3)
            
            if self.ffmpeg_youtube_process.poll() is None:
                logger.info("✓ YouTube streaming started successfully")
                return True
            else:
                logger.error("✗ YouTube streaming failed to start")
                return False
                
        except Exception as e:
            logger.error(f"Failed to start YouTube streaming: {e}")
            return False

    def send_key_to_emulator(self, key):
        """Send key press to FUSE emulator using xdotool"""
        try:
            key_mapping = {
                'SPACE': 'space',
                'ENTER': 'Return',
                'SHIFT': 'Shift_L',
                'CTRL': 'Control_L',
                'ALT': 'Alt_L',
                'BACKSPACE': 'BackSpace',
                'TAB': 'Tab',
                'ESCAPE': 'Escape',
                'UP': 'Up',
                'DOWN': 'Down',
                'LEFT': 'Left',
                'RIGHT': 'Right',
                'Q': 'q', 'A': 'a', 'O': 'o', 'P': 'p',
            }
            
            x11_key = key_mapping.get(key.upper(), key.lower())
            
            env = os.environ.copy()
            env['DISPLAY'] = self.display
            
            # Focus FUSE window first
            subprocess.run(['xdotool', 'search', '--name', 'Fuse', 'windowactivate'], 
                         check=False, capture_output=True, env=env)
            
            # Send key press
            result = subprocess.run(['xdotool', 'key', x11_key], 
                                  check=True, capture_output=True, env=env)
            
            logger.info(f"✓ Key '{key}' sent to emulator successfully")
            return True
            
        except subprocess.CalledProcessError as e:
            logger.error(f"✗ Failed to send key '{key}': {e}")
            return False
        except Exception as e:
            logger.error(f"✗ Error sending key '{key}': {e}")
            return False

    async def handle_websocket(self, websocket):
        """Handle WebSocket connections"""
        self.websocket_clients.add(websocket)
        logger.info("WebSocket connection established")
        
        # Send welcome message
        await websocket.send(json.dumps({
            'type': 'connected',
            'emulator_running': self.emulator_process is not None and self.emulator_process.poll() is None,
            'hls_streaming': self.ffmpeg_hls_process is not None and self.ffmpeg_hls_process.poll() is None,
            'youtube_streaming': self.ffmpeg_youtube_process is not None and self.ffmpeg_youtube_process.poll() is None
        }))
        
        try:
            async for message in websocket:
                try:
                    data = json.loads(message)
                    await self.handle_message(websocket, data)
                except json.JSONDecodeError:
                    logger.error(f"Invalid JSON received: {message}")
                except Exception as e:
                    logger.error(f"Error handling message: {e}")
        
        except websockets.exceptions.ConnectionClosed:
            logger.info("WebSocket connection closed")
        finally:
            self.websocket_clients.discard(websocket)

    async def handle_message(self, websocket, data):
        """Handle incoming WebSocket messages"""
        message_type = data.get('type')
        
        if message_type == 'key_press':
            key = data.get('key')
            if key:
                success = self.send_key_to_emulator(key)
                await websocket.send(json.dumps({
                    'type': 'key_response',
                    'key': key,
                    'success': success
                }))
        
        elif message_type == 'start_emulator':
            if not self.emulator_process or self.emulator_process.poll() is not None:
                success = self.start_emulator()
                await websocket.send(json.dumps({
                    'type': 'emulator_status',
                    'running': success,
                    'message': 'Emulator started' if success else 'Failed to start emulator'
                }))
        
        elif message_type == 'status':
            await websocket.send(json.dumps({
                'type': 'status_response',
                'emulator_running': self.emulator_process is not None and self.emulator_process.poll() is None,
                'hls_streaming': self.ffmpeg_hls_process is not None and self.ffmpeg_hls_process.poll() is None,
                'youtube_streaming': self.ffmpeg_youtube_process is not None and self.ffmpeg_youtube_process.poll() is None
            }))

    async def health_check(self, request):
        """Health check endpoint"""
        status = {
            'status': 'healthy',
            'emulator_running': self.emulator_process is not None and self.emulator_process.poll() is None,
            'hls_streaming': self.ffmpeg_hls_process is not None and self.ffmpeg_hls_process.poll() is None,
            'youtube_streaming': self.ffmpeg_youtube_process is not None and self.ffmpeg_youtube_process.poll() is None,
            'websocket_clients': len(self.websocket_clients),
            'display': self.display
        }
        return web.json_response(status)

    async def start_health_server(self):
        """Start health check HTTP server"""
        app = web.Application()
        app.router.add_get('/health', self.health_check)
        
        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, 'localhost', self.health_port)
        await site.start()
        
        logger.info(f"Health server started on http://localhost:{self.health_port}/health")

    def cleanup(self):
        """Clean up all processes"""
        logger.info("Cleaning up processes...")
        
        processes = [
            ('Emulator', self.emulator_process),
            ('HLS FFmpeg', self.ffmpeg_hls_process),
            ('YouTube FFmpeg', self.ffmpeg_youtube_process),
            ('Xvfb', self.xvfb_process),
        ]
        
        for name, process in processes:
            if process and process.poll() is None:
                logger.info(f"Terminating {name}...")
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    logger.warning(f"Force killing {name}...")
                    process.kill()

    async def run(self):
        """Main run method"""
        logger.info("Starting Headless Local ZX Spectrum Emulator Server")
        
        if not self.check_dependencies():
            return False
        
        if not self.start_virtual_display():
            logger.error("Failed to start virtual display")
            return False
        
        web_server = self.start_web_server()
        await self.start_health_server()
        
        if not self.start_emulator():
            logger.error("Failed to start emulator")
            return False
        
        if not self.start_hls_streaming():
            logger.error("Failed to start HLS streaming")
            return False
        
        self.start_youtube_streaming()
        
        logger.info(f"Starting WebSocket server on ws://localhost:{self.websocket_port}")
        
        self.running = True
        
        try:
            async with websockets.serve(self.handle_websocket, "localhost", self.websocket_port):
                logger.info("🎮 Headless Local ZX Spectrum Emulator Server is running!")
                logger.info(f"📺 Web interface: http://localhost:{self.web_port}")
                logger.info(f"🔌 WebSocket: ws://localhost:{self.websocket_port}")
                logger.info(f"❤️  Health check: http://localhost:{self.health_port}/health")
                logger.info(f"📹 HLS stream: http://localhost:{self.web_port}/stream/hls/stream.m3u8")
                logger.info(f"🖥️  Virtual display: {self.display}")
                
                while self.running:
                    await asyncio.sleep(1)
                    
        except KeyboardInterrupt:
            logger.info("Received interrupt signal")
        finally:
            self.cleanup()

if __name__ == "__main__":
    server = HeadlessZXSpectrumEmulatorServer()
    try:
        asyncio.run(server.run())
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
    except Exception as e:
        logger.error(f"Server error: {e}")
        sys.exit(1)
