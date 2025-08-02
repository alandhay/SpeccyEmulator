#!/usr/bin/env python3
"""
ZX Spectrum Emulator Server with Version Tracking and Visual Overlays
Version: 1.0.0-asyncio-fixed
Build: 2025-08-02T17:15:00Z
"""

import asyncio
import websockets
import json
import logging
import subprocess
import os
import signal
import time
import threading
import sys
from aiohttp import web, web_runner
import boto3
from botocore.exceptions import ClientError
import tempfile
import shutil
from pathlib import Path
from datetime import datetime

# Version Information
VERSION = "1.0.0-asyncio-fixed"
BUILD_TIME = "2025-08-02T17:15:00Z"
BUILD_HASH = "rev25-asyncio-fixed"

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class VersionedSpectrumEmulator:
    def __init__(self):
        self.version = VERSION
        self.build_time = BUILD_TIME
        self.build_hash = BUILD_HASH
        
        self.xvfb_process = None
        self.pulseaudio_process = None
        self.ffmpeg_process = None
        self.emulator_process = None
        self.clients = set()
        self.emulator_running = False
        self.s3_client = None
        self.upload_thread = None
        self.health_app = None
        self.health_runner = None
        
        # Environment configuration
        self.stream_bucket = os.environ.get('STREAM_BUCKET', 'spectrum-emulator-stream-dev-043309319786')
        self.youtube_key = os.environ.get('YOUTUBE_STREAM_KEY', '')
        
        # Log version information
        logger.info(f"Starting ZX Spectrum Emulator Server")
        logger.info(f"Version: {self.version}")
        logger.info(f"Build Time: {self.build_time}")
        logger.info(f"Build Hash: {self.build_hash}")
        
        # Setup S3 client
        try:
            self.s3_client = boto3.client('s3')
            logger.info("S3 client initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize S3 client: {e}")

    def get_version_info(self):
        """Return version information"""
        return {
            "version": self.version,
            "build_time": self.build_time,
            "build_hash": self.build_hash,
            "uptime": time.time() - self.start_time if hasattr(self, 'start_time') else 0
        }

    def start_xvfb(self):
        """Start Xvfb virtual display server"""
        try:
            logger.info("Starting Xvfb virtual display...")
            self.xvfb_process = subprocess.Popen([
                'Xvfb', ':99', 
                '-screen', '0', '512x384x24',
                '-ac', '+extension', 'GLX'
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            # Wait a moment for Xvfb to start
            time.sleep(2)
            
            if self.xvfb_process.poll() is None:
                logger.info("Xvfb started successfully on display :99")
                return True
            else:
                logger.error("Xvfb failed to start")
                return False
                
        except Exception as e:
            logger.error(f"Failed to start Xvfb: {e}")
            return False

    def start_pulseaudio(self):
        """Start PulseAudio server"""
        try:
            logger.info("Starting PulseAudio...")
            
            # Create pulse runtime directory
            os.makedirs('/tmp/pulse', exist_ok=True)
            
            # Start PulseAudio in daemon mode
            self.pulseaudio_process = subprocess.Popen([
                'pulseaudio', '--system=false', '--daemonize=false',
                '--disable-shm', '--exit-idle-time=-1'
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            time.sleep(2)
            
            if self.pulseaudio_process.poll() is None:
                logger.info("PulseAudio started successfully")
                return True
            else:
                logger.error("PulseAudio failed to start")
                return False
                
        except Exception as e:
            logger.error(f"Failed to start PulseAudio: {e}")
            return False

    def start_ffmpeg_with_overlays(self):
        """Start FFmpeg with version and branding overlays"""
        try:
            logger.info("Starting FFmpeg with version overlays...")
            
            # Create stream directory
            os.makedirs('/tmp/stream', exist_ok=True)
            
            # FFmpeg command with text overlays
            ffmpeg_cmd = [
                'ffmpeg',
                '-f', 'x11grab',
                '-video_size', '256x192',
                '-framerate', '25',
                '-i', ':99.0+0,0',
                '-f', 'pulse',
                '-i', 'default',
                '-vf', f"drawtext=text='v{self.version}':fontcolor=yellow:fontsize=12:x=5:y=5:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf,drawtext=text='RETROBOT':fontcolor=white:fontsize=14:x=w-tw-5:y=h-th-5:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                '-c:v', 'libx264',
                '-preset', 'ultrafast',
                '-tune', 'zerolatency',
                '-pix_fmt', 'yuv420p',
                '-c:a', 'aac',
                '-b:a', '128k',
                '-f', 'hls',
                '-hls_time', '2',
                '-hls_list_size', '5',
                '-hls_flags', 'delete_segments',
                '-hls_segment_filename', '/tmp/stream/stream%d.ts',
                '/tmp/stream/stream.m3u8'
            ]
            
            logger.info(f"FFmpeg command with overlays: {' '.join(ffmpeg_cmd)}")
            
            self.ffmpeg_process = subprocess.Popen(
                ffmpeg_cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            
            time.sleep(3)
            
            if self.ffmpeg_process.poll() is None:
                logger.info("FFmpeg started successfully with version overlays")
                return True
            else:
                logger.error("FFmpeg failed to start")
                return False
                
        except Exception as e:
            logger.error(f"Failed to start FFmpeg: {e}")
            return False

    def start_emulator(self):
        """Start FUSE ZX Spectrum emulator"""
        try:
            logger.info("Starting FUSE ZX Spectrum emulator...")
            
            # FUSE emulator command
            emulator_cmd = [
                'fuse-sdl',
                '--machine', '48',
                '--no-sound',
                '--graphics-filter', 'none'
            ]
            
            # Set environment for emulator
            env = os.environ.copy()
            env['DISPLAY'] = ':99'
            env['SDL_VIDEODRIVER'] = 'x11'
            
            self.emulator_process = subprocess.Popen(
                emulator_cmd,
                env=env,
                stdin=subprocess.PIPE,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            
            time.sleep(2)
            
            if self.emulator_process.poll() is None:
                logger.info("FUSE emulator started successfully")
                self.emulator_running = True
                return True
            else:
                logger.error("FUSE emulator failed to start")
                return False
                
        except Exception as e:
            logger.error(f"Failed to start FUSE emulator: {e}")
            return False

    def send_key_to_emulator(self, key):
        """Send key press to FUSE emulator"""
        if not self.emulator_running or not self.emulator_process:
            logger.warning("Emulator not running, cannot send key")
            return False
            
        try:
            # Map web keys to FUSE key codes
            key_mapping = {
                # Numbers
                '1': '1', '2': '2', '3': '3', '4': '4', '5': '5',
                '6': '6', '7': '7', '8': '8', '9': '9', '0': '0',
                
                # Letters
                'Q': 'q', 'W': 'w', 'E': 'e', 'R': 'r', 'T': 't',
                'Y': 'y', 'U': 'u', 'I': 'i', 'O': 'o', 'P': 'p',
                'A': 'a', 'S': 's', 'D': 'd', 'F': 'f', 'G': 'g',
                'H': 'h', 'J': 'j', 'K': 'k', 'L': 'l',
                'Z': 'z', 'X': 'x', 'C': 'c', 'V': 'v', 'B': 'b',
                'N': 'n', 'M': 'm',
                
                # Special keys
                'SPACE': ' ',
                'ENTER': '\n',
                'SHIFT': 'shift',
                'SYMBOL': 'ctrl',
                'DELETE': '\b',
            }
            
            fuse_key = key_mapping.get(key, key.lower())
            
            # Send key to emulator stdin
            if self.emulator_process.stdin:
                self.emulator_process.stdin.write(fuse_key.encode())
                self.emulator_process.stdin.flush()
                logger.info(f"Sent key to emulator: {key} -> {fuse_key}")
                return True
            
        except Exception as e:
            logger.error(f"Failed to send key to emulator: {e}")
            return False
            
        return False

    def start_upload_thread(self):
        """Start thread to upload HLS segments to S3"""
        def upload_segments():
            bucket = self.stream_bucket
            
            while True:
                try:
                    # Upload stream files to S3
                    if os.path.exists('/tmp/stream/stream.m3u8'):
                        subprocess.run([
                            'aws', 's3', 'cp', '/tmp/stream/stream.m3u8',
                            f's3://{bucket}/hls/stream.m3u8',
                            '--content-type', 'application/vnd.apple.mpegurl'
                        ], check=False)
                    
                    # Upload segment files
                    for segment_file in Path('/tmp/stream').glob('stream*.ts'):
                        subprocess.run([
                            'aws', 's3', 'cp', str(segment_file),
                            f's3://{bucket}/hls/{segment_file.name}',
                            '--content-type', 'video/mp2t'
                        ], check=False)
                    
                    time.sleep(1)
                    
                except Exception as e:
                    logger.error(f"S3 upload error: {e}")
                    time.sleep(5)
        
        self.upload_thread = threading.Thread(target=upload_segments, daemon=True)
        self.upload_thread.start()
        logger.info("S3 upload thread started")

    async def health_check_handler(self, request):
        """Health check endpoint with version info"""
        version_info = self.get_version_info()
        return web.json_response({
            "status": "OK",
            "version": version_info,
            "emulator_running": self.emulator_running,
            "timestamp": datetime.utcnow().isoformat()
        })

    async def version_handler(self, request):
        """Version endpoint"""
        return web.json_response(self.get_version_info())

    async def start_health_server(self):
        """Start health check server"""
        self.health_app = web.Application()
        self.health_app.router.add_get('/health', self.health_check_handler)
        self.health_app.router.add_get('/version', self.version_handler)
        self.health_app.router.add_get('/', self.health_check_handler)
        
        self.health_runner = web_runner.AppRunner(self.health_app)
        await self.health_runner.setup()
        
        site = web_runner.TCPSite(self.health_runner, '0.0.0.0', 8080)
        await site.start()
        logger.info("Health check server started on port 8080")

    async def handle_websocket(self, websocket, path):
        """Handle WebSocket connections"""
        self.clients.add(websocket)
        logger.info(f"Client connected. Total clients: {len(self.clients)}")
        
        try:
            # Send initial status with version
            await websocket.send(json.dumps({
                'type': 'connected',
                'emulator_running': self.emulator_running,
                'version': self.get_version_info()
            }))
            
            async for message in websocket:
                try:
                    data = json.loads(message)
                    await self.handle_message(websocket, data)
                except json.JSONDecodeError:
                    logger.error(f"Invalid JSON received: {message}")
                except Exception as e:
                    logger.error(f"Error handling message: {e}")
                    
        except websockets.exceptions.ConnectionClosed:
            logger.info("Client disconnected")
        finally:
            self.clients.discard(websocket)

    async def handle_message(self, websocket, data):
        """Handle WebSocket messages"""
        message_type = data.get('type')
        logger.info(f"Received message: {data}")
        
        if message_type == 'start_emulator':
            success = self.start_emulator()
            await websocket.send(json.dumps({
                'type': 'emulator_status',
                'running': success,
                'message': 'Emulator started' if success else 'Failed to start emulator',
                'version': self.get_version_info()
            }))
            
        elif message_type == 'key_press':
            key = data.get('key')
            if key and self.emulator_running:
                logger.info(f"Key press received: {key}")
                success = self.send_key_to_emulator(key)
                await websocket.send(json.dumps({
                    'type': 'key_acknowledged',
                    'key': key,
                    'success': success,
                    'version': self.get_version_info()
                }))
            elif key:
                logger.warning(f"Key press received but emulator not running: {key}")
                await websocket.send(json.dumps({
                    'type': 'key_acknowledged',
                    'key': key,
                    'success': False,
                    'error': 'Emulator not running',
                    'version': self.get_version_info()
                }))
            
        elif message_type == 'get_version':
            await websocket.send(json.dumps({
                'type': 'version_info',
                'version': self.get_version_info()
            }))
            
        elif message_type == 'status':
            await websocket.send(json.dumps({
                'type': 'status_response',
                'emulator_running': self.emulator_running,
                'xvfb_running': self.xvfb_process and self.xvfb_process.poll() is None,
                'ffmpeg_running': self.ffmpeg_process and self.ffmpeg_process.poll() is None,
                'version': self.get_version_info()
            }))

    def stop_all_processes(self):
        """Stop all running processes"""
        logger.info("Stopping all processes...")
        
        processes = [
            ('Emulator', self.emulator_process),
            ('FFmpeg', self.ffmpeg_process),
            ('PulseAudio', self.pulseaudio_process),
            ('Xvfb', self.xvfb_process)
        ]
        
        for name, process in processes:
            if process and process.poll() is None:
                try:
                    process.terminate()
                    process.wait(timeout=5)
                    logger.info(f"{name} stopped")
                except subprocess.TimeoutExpired:
                    process.kill()
                    logger.info(f"{name} killed")
                except Exception as e:
                    logger.error(f"Error stopping {name}: {e}")

    async def main(self):
        """Main async method with proper event loop handling"""
        self.start_time = time.time()
        logger.info(f"Starting ZX Spectrum Emulator Server v{self.version}")
        
        # Set up signal handlers
        def signal_handler():
            logger.info("Received shutdown signal")
            self.stop_all_processes()
        
        # Register signal handlers for graceful shutdown
        loop = asyncio.get_running_loop()
        for sig in (signal.SIGTERM, signal.SIGINT):
            loop.add_signal_handler(sig, signal_handler)
        
        # Start all services
        if not self.start_xvfb():
            logger.error("Failed to start Xvfb")
            return
        
        if not self.start_pulseaudio():
            logger.error("Failed to start PulseAudio")
            return
        
        if not self.start_ffmpeg_with_overlays():
            logger.error("Failed to start FFmpeg")
            return
        
        # Start S3 upload thread
        self.start_upload_thread()
        
        # Start health check server
        await self.start_health_server()
        
        # Start WebSocket server
        logger.info("Starting WebSocket server on port 8765...")
        start_server = websockets.serve(self.handle_websocket, '0.0.0.0', 8765)
        await start_server
        
        logger.info(f"All services started. Server ready! Version: {self.version}")
        
        # Keep the server running
        try:
            await asyncio.Future()  # Run forever
        except asyncio.CancelledError:
            logger.info("Shutting down...")
        finally:
            self.stop_all_processes()
            if self.health_runner:
                await self.health_runner.cleanup()

    def run(self):
        """Entry point with proper asyncio setup"""
        try:
            asyncio.run(self.main())
        except KeyboardInterrupt:
            logger.info("Received keyboard interrupt")
        except Exception as e:
            logger.error(f"Server error: {e}")
        finally:
            self.stop_all_processes()

if __name__ == '__main__':
    server = VersionedSpectrumEmulator()
    server.run()
