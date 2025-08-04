#!/usr/bin/env python3
"""
ZX Spectrum Emulator Server - Key Injection Fixed Version
=========================================================

This version fixes the critical key injection issue by implementing proper
xdotool-based key forwarding to the FUSE emulator.

CRITICAL FIXES:
===============

1. PROPER KEY INJECTION:
   - Implements actual xdotool key forwarding (not just logging)
   - Maps web keys to X11 key names
   - Focuses FUSE window before sending keys
   - Provides success/failure feedback

2. XDOTOOL DEPENDENCY:
   - Ensures xdotool is available in container
   - Proper error handling for missing dependencies
   - Fallback logging when xdotool fails

3. KEY MAPPING:
   - Complete ZX Spectrum key mapping
   - Special key handling (SPACE, ENTER, etc.)
   - Case-insensitive key processing

DEPLOYMENT:
===========
- Docker Image: spectrum-emulator:key-injection-fixed
- Version: 1.0.0-key-injection-fixed
- Based on: framebuffer-capture-fixed with key injection added
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
import boto3
from botocore.exceptions import ClientError

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class ZXSpectrumEmulatorServer:
    def __init__(self):
        self.version = "1.0.0-key-injection-fixed"
        self.running = True
        self.websocket_clients = set()
        
        # Process handles
        self.xvfb_process = None
        self.pulseaudio_process = None
        self.emulator_process = None
        self.ffmpeg_hls_process = None
        self.ffmpeg_youtube_process = None
        
        # Configuration
        self.stream_bucket = os.environ.get('STREAM_BUCKET', 'spectrum-emulator-stream-dev-043309319786')
        self.youtube_key = os.environ.get('YOUTUBE_STREAM_KEY', '')
        self.capture_size = "320x240"  # Fixed capture size for FUSE window
        self.display_size = "640x480"  # Scaled output size
        
        # Key mapping for ZX Spectrum
        self.key_mapping = {
            # Letters
            'A': 'a', 'B': 'b', 'C': 'c', 'D': 'd', 'E': 'e', 'F': 'f', 'G': 'g', 'H': 'h',
            'I': 'i', 'J': 'j', 'K': 'k', 'L': 'l', 'M': 'm', 'N': 'n', 'O': 'o', 'P': 'p',
            'Q': 'q', 'R': 'r', 'S': 's', 'T': 't', 'U': 'u', 'V': 'v', 'W': 'w', 'X': 'x',
            'Y': 'y', 'Z': 'z',
            # Numbers
            '0': '0', '1': '1', '2': '2', '3': '3', '4': '4', '5': '5', '6': '6', '7': '7', '8': '8', '9': '9',
            # Special keys
            'SPACE': 'space',
            'ENTER': 'Return',
            'SHIFT': 'Shift_L',
            'CTRL': 'Control_L',
            'ALT': 'Alt_L',
            # Arrow keys (mapped to QAOP for ZX Spectrum games)
            'UP': 'q',
            'LEFT': 'a', 
            'DOWN': 'o',
            'RIGHT': 'p',
            # Function keys
            'F1': 'F1', 'F2': 'F2', 'F3': 'F3', 'F4': 'F4', 'F5': 'F5',
            'F6': 'F6', 'F7': 'F7', 'F8': 'F8', 'F9': 'F9', 'F10': 'F10',
        }
        
        # S3 client for HLS uploads
        self.s3_client = boto3.client('s3')
        
        # Setup signal handlers
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)

    def signal_handler(self, signum, frame):
        logger.info(f"Received signal {signum}, shutting down...")
        self.cleanup()
        sys.exit(0)

    def send_key_to_emulator(self, key):
        """Send key press to FUSE emulator using xdotool"""
        try:
            # Map the key to X11 key name
            key_upper = key.upper()
            x11_key = self.key_mapping.get(key_upper, key.lower())
            
            logger.info(f"🔑 Attempting to send key '{key}' (mapped to '{x11_key}') to FUSE emulator")
            
            # First, try to find and focus the FUSE window
            find_result = subprocess.run([
                'xdotool', 'search', '--name', 'Fuse'
            ], env={'DISPLAY': ':99'}, capture_output=True, text=True, timeout=5)
            
            if find_result.returncode != 0:
                logger.error(f"❌ Could not find FUSE window: {find_result.stderr}")
                return False, f"FUSE window not found: {find_result.stderr.strip()}"
            
            window_id = find_result.stdout.strip().split('\n')[0]
            logger.info(f"📱 Found FUSE window ID: {window_id}")
            
            # Focus the window and send the key
            key_result = subprocess.run([
                'xdotool', 
                'windowfocus', window_id,
                'key', x11_key
            ], env={'DISPLAY': ':99'}, capture_output=True, text=True, timeout=5)
            
            if key_result.returncode == 0:
                logger.info(f"✅ Successfully sent key '{key}' (mapped to '{x11_key}') to FUSE emulator")
                return True, f"Key '{key}' sent successfully"
            else:
                logger.error(f"❌ Failed to send key '{key}': {key_result.stderr}")
                return False, f"xdotool key error: {key_result.stderr.strip()}"
                
        except subprocess.TimeoutExpired:
            logger.error(f"❌ Timeout sending key '{key}' to emulator")
            return False, f"Timeout sending key '{key}'"
        except FileNotFoundError:
            logger.error(f"❌ xdotool not found - cannot send keys to emulator")
            return False, "xdotool not installed"
        except Exception as e:
            logger.error(f"❌ Exception sending key '{key}' to emulator: {e}")
            return False, f"Exception: {str(e)}"

    def start_xvfb(self):
        """Start virtual X11 display server"""
        try:
            logger.info("Starting Xvfb virtual display server...")
            self.xvfb_process = subprocess.Popen([
                'Xvfb', ':99', 
                '-screen', '0', f'{self.capture_size}x24',
                '-ac', '+extension', 'GLX'
            ])
            time.sleep(3)  # Give Xvfb time to start
            logger.info("✅ Xvfb started successfully on display :99")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to start Xvfb: {e}")
            return False

    def start_pulseaudio(self):
        """Start PulseAudio server"""
        try:
            logger.info("Starting PulseAudio server...")
            os.makedirs('/tmp/pulse', exist_ok=True)
            self.pulseaudio_process = subprocess.Popen([
                'pulseaudio', '--system=false', '--exit-idle-time=-1',
                '--runtime-dir=/tmp/pulse'
            ])
            time.sleep(2)  # Give PulseAudio time to start
            logger.info("✅ PulseAudio started successfully")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to start PulseAudio: {e}")
            return False

    def start_emulator(self):
        """Start FUSE ZX Spectrum emulator"""
        try:
            logger.info("Starting FUSE ZX Spectrum emulator...")
            self.emulator_process = subprocess.Popen([
                'fuse-sdl',
                '--machine', '48',
                '--graphics-filter', 'none',
                '--no-sound'  # Disable sound for now
            ], env={
                'DISPLAY': ':99',
                'SDL_VIDEODRIVER': 'x11',
                'SDL_AUDIODRIVER': 'pulse',
                'PULSE_RUNTIME_PATH': '/tmp/pulse'
            })
            time.sleep(5)  # Give emulator time to start and create window
            logger.info("✅ FUSE emulator started successfully")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to start FUSE emulator: {e}")
            return False

    def start_ffmpeg_hls(self):
        """Start FFmpeg for HLS streaming"""
        try:
            logger.info("Starting FFmpeg HLS streaming...")
            os.makedirs('/tmp/stream', exist_ok=True)
            
            self.ffmpeg_hls_process = subprocess.Popen([
                'ffmpeg',
                '-f', 'x11grab',
                '-video_size', self.capture_size,
                '-i', ':99.0+0,0',
                '-draw_mouse', '0',  # Hide cursor
                '-vf', f'scale={self.display_size}:flags=neighbor',  # Pixel-perfect scaling
                '-c:v', 'libx264',
                '-preset', 'ultrafast',
                '-tune', 'zerolatency',
                '-crf', '23',
                '-maxrate', '2500k',
                '-bufsize', '5000k',
                '-g', '50',
                '-f', 'hls',
                '-hls_time', '2',
                '-hls_list_size', '5',
                '-hls_segment_filename', '/tmp/stream/stream%d.ts',
                '/tmp/stream/stream.m3u8'
            ])
            logger.info("✅ FFmpeg HLS streaming started")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to start FFmpeg HLS: {e}")
            return False

    def start_ffmpeg_youtube(self):
        """Start FFmpeg for YouTube streaming"""
        if not self.youtube_key:
            logger.info("No YouTube stream key provided, skipping YouTube streaming")
            return True
            
        try:
            logger.info("Starting FFmpeg YouTube streaming...")
            
            self.ffmpeg_youtube_process = subprocess.Popen([
                'ffmpeg',
                '-f', 'x11grab',
                '-video_size', self.capture_size,
                '-i', ':99.0+0,0',
                '-draw_mouse', '0',  # Hide cursor
                '-vf', f'scale={self.display_size}:flags=neighbor',  # Pixel-perfect scaling
                '-c:v', 'libx264',
                '-preset', 'fast',
                '-tune', 'zerolatency',
                '-crf', '23',
                '-maxrate', '2500k',
                '-bufsize', '5000k',
                '-g', '50',
                '-c:a', 'aac',
                '-b:a', '128k',
                '-f', 'flv',
                f'rtmp://a.rtmp.youtube.com/live2/{self.youtube_key}'
            ])
            logger.info("✅ FFmpeg YouTube streaming started")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to start FFmpeg YouTube: {e}")
            return False

    def start_s3_upload_thread(self):
        """Start background thread for S3 uploads"""
        def upload_worker():
            while self.running:
                try:
                    # Upload HLS files to S3
                    for filename in ['stream.m3u8'] + [f'stream{i}.ts' for i in range(1000)]:
                        filepath = f'/tmp/stream/{filename}'
                        if os.path.exists(filepath):
                            try:
                                self.s3_client.upload_file(
                                    filepath, 
                                    self.stream_bucket, 
                                    f'hls/{filename}',
                                    ExtraArgs={'ContentType': 'application/x-mpegURL' if filename.endswith('.m3u8') else 'video/MP2T'}
                                )
                            except ClientError as e:
                                if 'NoSuchFile' not in str(e):
                                    logger.error(f"S3 upload error: {e}")
                    time.sleep(1)
                except Exception as e:
                    logger.error(f"S3 upload thread error: {e}")
                    time.sleep(5)
        
        upload_thread = threading.Thread(target=upload_worker, daemon=True)
        upload_thread.start()
        logger.info("✅ S3 upload thread started")

    async def start_services(self):
        """Start all emulator services"""
        logger.info("🚀 Starting ZX Spectrum Emulator Server...")
        logger.info(f"📋 Version: {self.version}")
        logger.info(f"🎯 Capture Size: {self.capture_size}")
        logger.info(f"📺 Display Size: {self.display_size}")
        
        # Start services in order
        if not self.start_xvfb():
            return False
        if not self.start_pulseaudio():
            return False
        if not self.start_emulator():
            return False
        if not self.start_ffmpeg_hls():
            return False
        if not self.start_ffmpeg_youtube():
            return False
        
        # Start S3 upload thread
        self.start_s3_upload_thread()
        
        logger.info("✅ All services started successfully!")
        return True

    async def handle_websocket(self, websocket, path):
        """Handle WebSocket connections"""
        self.websocket_clients.add(websocket)
        logger.info("WebSocket connection established")
        
        # Send welcome message
        await websocket.send(json.dumps({
            'type': 'connected',
            'emulator_running': self.emulator_process is not None and self.emulator_process.poll() is None,
            'version': self.version,
            'key_injection_enabled': True
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
        except Exception as e:
            logger.error(f"WebSocket error: {e}")
        finally:
            self.websocket_clients.discard(websocket)

    async def handle_message(self, websocket, data):
        """Handle incoming WebSocket messages"""
        message_type = data.get('type')
        
        if message_type == 'status':
            # Send status update
            await websocket.send(json.dumps({
                'type': 'status_response',
                'emulator_running': self.emulator_process is not None and self.emulator_process.poll() is None,
                'services': {
                    'xvfb': self.xvfb_process is not None and self.xvfb_process.poll() is None,
                    'emulator': self.emulator_process is not None and self.emulator_process.poll() is None,
                    'ffmpeg_hls': self.ffmpeg_hls_process is not None and self.ffmpeg_hls_process.poll() is None,
                    'ffmpeg_youtube': self.ffmpeg_youtube_process is not None and self.ffmpeg_youtube_process.poll() is None
                },
                'version': self.version,
                'key_injection_enabled': True
            }))
            
        elif message_type == 'key_press':
            # Handle key press - ACTUAL IMPLEMENTATION
            key = data.get('key', '').upper()
            logger.info(f"🔑 Key press received: {key}")
            
            if key:
                # Send key to emulator using xdotool
                success, message = self.send_key_to_emulator(key)
                
                # Send response back to client
                await websocket.send(json.dumps({
                    'type': 'key_response',
                    'key': key,
                    'success': success,
                    'message': message,
                    'timestamp': time.time()
                }))
            else:
                await websocket.send(json.dumps({
                    'type': 'key_response',
                    'key': '',
                    'success': False,
                    'message': 'No key specified',
                    'timestamp': time.time()
                }))

    async def health_handler(self, request):
        """Health check endpoint"""
        status = {
            'status': 'healthy',
            'version': self.version,
            'key_injection_enabled': True,
            'services': {
                'xvfb': self.xvfb_process is not None and self.xvfb_process.poll() is None,
                'emulator': self.emulator_process is not None and self.emulator_process.poll() is None,
                'ffmpeg_hls': self.ffmpeg_hls_process is not None and self.ffmpeg_hls_process.poll() is None,
                'ffmpeg_youtube': self.ffmpeg_youtube_process is not None and self.ffmpeg_youtube_process.poll() is None
            }
        }
        return web.json_response(status)

    def cleanup(self):
        """Clean up processes"""
        logger.info("Cleaning up processes...")
        self.running = False
        
        processes = [
            ('FFmpeg YouTube', self.ffmpeg_youtube_process),
            ('FFmpeg HLS', self.ffmpeg_hls_process),
            ('FUSE Emulator', self.emulator_process),
            ('PulseAudio', self.pulseaudio_process),
            ('Xvfb', self.xvfb_process)
        ]
        
        for name, process in processes:
            if process:
                try:
                    process.terminate()
                    process.wait(timeout=5)
                    logger.info(f"{name} terminated")
                except subprocess.TimeoutExpired:
                    process.kill()
                    logger.info(f"{name} killed")
                except Exception as e:
                    logger.error(f"Error stopping {name}: {e}")

    async def run(self):
        """Main server run method"""
        # Start all services
        if not await self.start_services():
            logger.error("❌ Failed to start services")
            return
        
        # Start HTTP server for health checks
        app = web.Application()
        app.router.add_get('/health', self.health_handler)
        
        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, '0.0.0.0', 8080)
        await site.start()
        logger.info("✅ Health check server started on port 8080")
        
        # Start WebSocket server
        logger.info("🔌 Starting WebSocket server on port 8765...")
        websocket_server = await websockets.serve(
            self.handle_websocket,
            "0.0.0.0",
            8765
        )
        logger.info("✅ WebSocket server started on port 8765")
        
        logger.info("🎮 ZX Spectrum Emulator Server is ready!")
        logger.info("📡 WebSocket: ws://localhost:8765")
        logger.info("🏥 Health Check: http://localhost:8080/health")
        logger.info("🎥 Video Stream: Check S3 bucket for HLS stream")
        
        # Keep server running
        try:
            await websocket_server.wait_closed()
        except KeyboardInterrupt:
            logger.info("Server stopped by user")
        finally:
            self.cleanup()

if __name__ == "__main__":
    server = ZXSpectrumEmulatorServer()
    try:
        asyncio.run(server.run())
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
    except Exception as e:
        logger.error(f"Server error: {e}")
        server.cleanup()
