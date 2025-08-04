#!/usr/bin/env python3
"""
ZX Spectrum Emulator Server - Fixed Version v2
Fixes:
1. WebSocket handler signature bug
2. FUSE emulator startup issues
3. Better error handling and logging
"""

import asyncio
import json
import logging
import os
import subprocess
import time
import threading
import signal
import sys
from aiohttp import web
import websockets
import boto3
from botocore.exceptions import NoCredentialsError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class FixedSpectrumEmulator:
    def __init__(self):
        self.emulator_process = None
        self.ffmpeg_process = None
        self.youtube_ffmpeg_process = None
        self.xvfb_process = None
        self.pulseaudio_process = None
        self.connected_clients = set()
        self.s3_client = None
        self.stream_bucket = os.environ.get('STREAM_BUCKET', 'spectrum-emulator-stream-dev-043309319786')
        self.youtube_stream_key = os.environ.get('YOUTUBE_STREAM_KEY', '')
        self.emulator_running = False
        self.server_start_time = time.time()
        
        # Initialize S3 client
        try:
            self.s3_client = boto3.client('s3', region_name='us-east-1')
            logger.info("S3 client initialized successfully")
        except NoCredentialsError:
            logger.error("AWS credentials not found")
        except Exception as e:
            logger.error(f"Failed to initialize S3 client: {e}")

    def setup_virtual_display(self):
        """Set up Xvfb virtual display"""
        try:
            logger.info("Starting Xvfb virtual display...")
            self.xvfb_process = subprocess.Popen([
                'Xvfb', ':99', 
                '-screen', '0', '512x384x24',
                '-ac', '+extension', 'GLX'
            ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            time.sleep(3)  # Give Xvfb time to start
            
            # Test if display is working
            result = subprocess.run(['xdpyinfo', '-display', ':99'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                logger.info("Xvfb started successfully on display :99")
                return True
            else:
                logger.error(f"Xvfb test failed: {result.stderr}")
                return False
                
        except Exception as e:
            logger.error(f"Failed to start Xvfb: {e}")
            return False

    def setup_pulseaudio(self):
        """Set up PulseAudio for audio"""
        try:
            logger.info("Starting PulseAudio...")
            self.pulseaudio_process = subprocess.Popen([
                'pulseaudio', '--start', '--exit-idle-time=-1', 
                '--system=false', '--disallow-exit'
            ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            time.sleep(2)  # Give PulseAudio time to start
            logger.info("PulseAudio started successfully")
            return True
            
        except Exception as e:
            logger.error(f"Failed to start PulseAudio: {e}")
            return False

    def start_emulator(self):
        """Start the FUSE ZX Spectrum emulator"""
        try:
            if self.emulator_process and self.emulator_process.poll() is None:
                logger.info("Emulator is already running")
                return True

            # Check if FUSE is available
            result = subprocess.run(['which', 'fuse-sdl'], capture_output=True, text=True)
            if result.returncode != 0:
                logger.error('FUSE emulator not found - please install fuse-emulator-sdl')
                return False

            logger.info(f'FUSE emulator found at: {result.stdout.strip()}')
            logger.info('Starting FUSE ZX Spectrum emulator...')
            
            # Set up environment for FUSE
            fuse_env = os.environ.copy()
            fuse_env.update({
                'DISPLAY': ':99',
                'SDL_VIDEODRIVER': 'x11',
                'SDL_AUDIODRIVER': 'pulse',
                'PULSE_RUNTIME_PATH': '/tmp/pulse'
            })
            
            # Start FUSE emulator
            self.emulator_process = subprocess.Popen([
                'fuse-sdl', 
                '--machine', '48',  # ZX Spectrum 48K
                '--graphics-filter', 'none',
                '--no-sound',  # Disable sound for now to avoid issues
                '--no-confirm-actions'
            ], env=fuse_env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            # Wait and check if FUSE started successfully
            time.sleep(5)
            
            if self.emulator_process.poll() is not None:
                # Process terminated
                stdout, stderr = self.emulator_process.communicate()
                logger.error('FUSE emulator failed to start:')
                logger.error(f'STDOUT: {stdout.decode()}')
                logger.error(f'STDERR: {stderr.decode()}')
                self.emulator_running = False
                return False
            else:
                logger.info('FUSE emulator started successfully')
                self.emulator_running = True
                time.sleep(2)  # Give it time to initialize display
                return True
                
        except Exception as e:
            logger.error(f'Error starting emulator: {e}')
            self.emulator_running = False
            return False

    def start_ffmpeg_stream(self):
        """Start FFmpeg for HLS streaming"""
        try:
            logger.info("Starting FFmpeg with version overlays...")
            
            # Create stream directory
            os.makedirs('/tmp/stream', exist_ok=True)
            
            # FFmpeg command with text overlays
            ffmpeg_cmd = [
                'ffmpeg', '-f', 'x11grab', 
                '-video_size', '256x192',
                '-framerate', '25',
                '-i', ':99.0+0,0',
                '-f', 'pulse', '-i', 'default',
                '-vf', 
                "drawtext=text='v1.0.0-fixed-v2':fontcolor=yellow:fontsize=12:x=5:y=5:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf,"
                "drawtext=text='RETROBOT':fontcolor=white:fontsize=14:x=w-tw-5:y=h-th-5:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                '-c:v', 'libx264', '-preset', 'ultrafast', '-tune', 'zerolatency',
                '-pix_fmt', 'yuv420p',
                '-c:a', 'aac', '-b:a', '128k',
                '-f', 'hls', '-hls_time', '2', '-hls_list_size', '5',
                '-hls_flags', 'delete_segments',
                '-hls_segment_filename', '/tmp/stream/stream%d.ts',
                '/tmp/stream/stream.m3u8'
            ]
            
            logger.info(f"FFmpeg command: {' '.join(ffmpeg_cmd)}")
            
            self.ffmpeg_process = subprocess.Popen(
                ffmpeg_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            time.sleep(3)  # Give FFmpeg time to start
            
            if self.ffmpeg_process.poll() is not None:
                stdout, stderr = self.ffmpeg_process.communicate()
                logger.error('FFmpeg failed to start:')
                logger.error(f'STDERR: {stderr.decode()}')
                return False
            else:
                logger.info("FFmpeg started successfully with version overlays")
                return True
                
        except Exception as e:
            logger.error(f'Error starting FFmpeg: {e}')
            return False

    def start_s3_upload_thread(self):
        """Start thread to upload HLS segments to S3"""
        def upload_loop():
            while True:
                try:
                    # Upload m3u8 playlist
                    if os.path.exists('/tmp/stream/stream.m3u8'):
                        self.s3_client.upload_file(
                            '/tmp/stream/stream.m3u8',
                            self.stream_bucket,
                            'hls/stream.m3u8',
                            ExtraArgs={'ContentType': 'application/vnd.apple.mpegurl'}
                        )
                    
                    # Upload .ts segments
                    for file in os.listdir('/tmp/stream'):
                        if file.endswith('.ts'):
                            local_path = f'/tmp/stream/{file}'
                            s3_key = f'hls/{file}'
                            
                            try:
                                self.s3_client.upload_file(
                                    local_path,
                                    self.stream_bucket,
                                    s3_key,
                                    ExtraArgs={'ContentType': 'video/mp2t'}
                                )
                            except Exception as e:
                                logger.debug(f'Upload error for {file}: {e}')
                    
                    time.sleep(1)  # Upload every second
                    
                except Exception as e:
                    logger.error(f'S3 upload error: {e}')
                    time.sleep(5)
        
        if self.s3_client:
            upload_thread = threading.Thread(target=upload_loop, daemon=True)
            upload_thread.start()
            logger.info("S3 upload thread started")

    def stop_emulator(self):
        """Stop the emulator and all processes"""
        try:
            if self.emulator_process:
                self.emulator_process.terminate()
                self.emulator_process.wait(timeout=5)
                self.emulator_process = None
                self.emulator_running = False
                logger.info('Emulator stopped')
        except Exception as e:
            logger.error(f'Error stopping emulator: {e}')

    # FIXED: WebSocket handler signature - removed 'path' parameter
    async def handle_websocket(self, websocket):
        """Handle WebSocket connections - FIXED VERSION"""
        self.connected_clients.add(websocket)
        logger.info('connection open')
        
        try:
            # Send initial status
            await websocket.send(json.dumps({
                'type': 'connected',
                'emulator_running': self.emulator_running,
                'message': 'Connected to ZX Spectrum Emulator'
            }))
            
            async for message in websocket:
                try:
                    data = json.loads(message)
                    logger.info(f'Received message: {data}')
                    
                    if data.get('type') == 'start_emulator':
                        success = self.start_emulator()
                        await websocket.send(json.dumps({
                            'type': 'emulator_status',
                            'running': success,
                            'message': 'Emulator started' if success else 'Failed to start emulator'
                        }))
                    
                    elif data.get('type') == 'stop_emulator':
                        self.stop_emulator()
                        await websocket.send(json.dumps({
                            'type': 'emulator_status',
                            'running': False,
                            'message': 'Emulator stopped'
                        }))
                    
                    elif data.get('type') == 'key_press':
                        key = data.get('key')
                        if key and self.emulator_running:
                            # TODO: Implement key forwarding to FUSE
                            logger.info(f'Key press: {key}')
                            await websocket.send(json.dumps({
                                'type': 'key_response',
                                'key': key,
                                'processed': True
                            }))
                    
                    elif data.get('type') == 'status':
                        await websocket.send(json.dumps({
                            'type': 'status_response',
                            'emulator_running': self.emulator_running,
                            'uptime': time.time() - self.server_start_time
                        }))
                        
                except json.JSONDecodeError:
                    logger.error(f'Invalid JSON received: {message}')
                except Exception as e:
                    logger.error(f'Error handling message: {e}')
                    
        except websockets.exceptions.ConnectionClosed:
            logger.info('WebSocket connection closed')
        except Exception as e:
            logger.error(f'WebSocket error: {e}')
        finally:
            self.connected_clients.discard(websocket)
            logger.info('connection closed')

    async def health_check(self, request):
        """Health check endpoint"""
        return web.json_response({
            'status': 'OK',
            'version': {
                'version': '1.0.0-fixed-v2',
                'build_time': '2025-08-02T17:50:00Z',
                'build_hash': 'fixed-v2-websocket-emulator',
                'uptime': time.time() - self.server_start_time
            },
            'emulator_running': self.emulator_running,
            'timestamp': time.strftime('%Y-%m-%dT%H:%M:%S.%fZ')
        })

    def cleanup(self):
        """Clean up all processes"""
        logger.info("Cleaning up processes...")
        
        processes = [
            ('Emulator', self.emulator_process),
            ('FFmpeg', self.ffmpeg_process),
            ('YouTube FFmpeg', self.youtube_ffmpeg_process),
            ('Xvfb', self.xvfb_process),
            ('PulseAudio', self.pulseaudio_process)
        ]
        
        for name, process in processes:
            if process:
                try:
                    process.terminate()
                    process.wait(timeout=5)
                    logger.info(f"{name} stopped")
                except Exception as e:
                    logger.error(f"Error stopping {name}: {e}")

    def run(self):
        """Main run method"""
        logger.info("Starting ZX Spectrum Emulator Server")
        logger.info("Version: 1.0.0-fixed-v2")
        logger.info("Build Time: 2025-08-02T17:50:00Z")
        logger.info("Build Hash: fixed-v2-websocket-emulator")
        
        # Set up signal handlers
        def signal_handler(signum, frame):
            logger.info(f"Received signal {signum}, shutting down...")
            self.cleanup()
            sys.exit(0)
        
        signal.signal(signal.SIGTERM, signal_handler)
        signal.signal(signal.SIGINT, signal_handler)
        
        # Start virtual display
        if not self.setup_virtual_display():
            logger.error("Failed to start virtual display")
            return
        
        # Start PulseAudio
        self.setup_pulseaudio()
        
        # Start FFmpeg streaming
        if not self.start_ffmpeg_stream():
            logger.error("Failed to start FFmpeg")
            return
        
        # Start S3 upload thread
        self.start_s3_upload_thread()
        
        # Start HTTP server for health checks
        async def init_app():
            app = web.Application()
            app.router.add_get('/health', self.health_check)
            runner = web.AppRunner(app)
            await runner.setup()
            site = web.TCPSite(runner, '0.0.0.0', 8080)
            await site.start()
            logger.info("Health check server started on port 8080")
        
        # Start WebSocket server
        async def start_servers():
            await init_app()
            # FIXED: Use the corrected handler without path parameter
            server = await websockets.serve(self.handle_websocket, '0.0.0.0', 8765)
            logger.info("server listening on 0.0.0.0:8765")
            logger.info("All services started. Server ready! Version: 1.0.0-fixed-v2")
            
            # Auto-start emulator after everything is ready
            logger.info("Auto-starting FUSE emulator...")
            success = self.start_emulator()
            if success:
                logger.info("FUSE emulator auto-started successfully")
            else:
                logger.error("FUSE emulator auto-start failed")
        
        # Run the event loop
        try:
            loop = asyncio.get_event_loop()
            loop.run_until_complete(start_servers())
            loop.run_forever()
        except KeyboardInterrupt:
            logger.info("Received keyboard interrupt")
        finally:
            self.cleanup()

if __name__ == '__main__':
    emulator = FixedSpectrumEmulator()
    emulator.run()
