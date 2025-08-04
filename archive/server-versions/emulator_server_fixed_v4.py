#!/usr/bin/env python3
"""
ZX Spectrum Emulator Server - Fixed Version v4
Fixes:
1. WebSocket handler signature bug
2. FUSE emulator startup issues
3. Better display window management
4. ACTUAL KEY FORWARDING TO FUSE EMULATOR
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

class InteractiveSpectrumEmulator:
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
            'SYMBOL': 'Alt_L',  # Symbol Shift on ZX Spectrum
            'DELETE': 'BackSpace',
            'BREAK': 'Escape',
            # Arrow keys (QAOP on ZX Spectrum)
            'UP': 'q',
            'LEFT': 'a', 
            'DOWN': 'o',
            'RIGHT': 'p'
        }
        
        # Initialize S3 client
        try:
            self.s3_client = boto3.client('s3', region_name='us-east-1')
            logger.info("S3 client initialized successfully")
        except NoCredentialsError:
            logger.error("AWS credentials not found")
        except Exception as e:
            logger.error(f"Failed to initialize S3 client: {e}")

    def setup_virtual_display(self):
        """Set up Xvfb virtual display with better configuration"""
        try:
            logger.info("Starting Xvfb virtual display...")
            self.xvfb_process = subprocess.Popen([
                'Xvfb', ':99', 
                '-screen', '0', '800x600x24',  # Larger screen for better compatibility
                '-ac', '+extension', 'GLX',
                '-dpi', '96',
                '-noreset'
            ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            time.sleep(3)  # Give Xvfb time to start
            
            # Test if display is working
            result = subprocess.run(['xdpyinfo', '-display', ':99'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                logger.info("Xvfb started successfully on display :99")
                logger.info(f"Display info: {result.stdout.split()[0:3]}")
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

    def send_key_to_emulator(self, key):
        """Send key press to FUSE emulator using xdotool"""
        try:
            if not self.emulator_running:
                logger.warning(f"Emulator not running, ignoring key: {key}")
                return False
                
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
                logger.info(f"Successfully sent key '{key}' (mapped to '{x11_key}') to FUSE emulator")
                return True
            else:
                logger.error(f"Failed to send key '{key}': {result.stderr}")
                return False
                
        except Exception as e:
            logger.error(f"Error sending key '{key}' to emulator: {e}")
            return False

    def start_emulator(self):
        """Start the FUSE ZX Spectrum emulator with improved configuration"""
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
            logger.info('Starting FUSE ZX Spectrum emulator with improved configuration...')
            
            # Set up environment for FUSE
            fuse_env = os.environ.copy()
            fuse_env.update({
                'DISPLAY': ':99',
                'SDL_VIDEODRIVER': 'x11',
                'SDL_AUDIODRIVER': 'pulse',
                'PULSE_RUNTIME_PATH': '/tmp/pulse',
                'SDL_VIDEO_WINDOW_POS': '0,0',  # Position window at top-left
                'SDL_VIDEO_CENTERED': '0'       # Don't center the window
            })
            
            # Start FUSE emulator with better parameters for headless operation
            self.emulator_process = subprocess.Popen([
                'fuse-sdl', 
                '--machine', '48',  # ZX Spectrum 48K
                '--graphics-filter', 'none',
                '--no-sound',  # Disable sound for now to avoid issues
                '--no-confirm-actions',
                '--full-screen',  # Force fullscreen to ensure visibility
                '--force-window-size', '256x192'  # Force specific window size
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
                
                # Try alternative approach without fullscreen
                logger.info('Retrying FUSE without fullscreen mode...')
                return self.start_emulator_fallback()
            else:
                logger.info('FUSE emulator started successfully')
                self.emulator_running = True
                
                # Give it more time to initialize and create window
                time.sleep(3)
                
                # Check if window is visible on display
                self.check_emulator_window()
                return True
                
        except Exception as e:
            logger.error(f'Error starting emulator: {e}')
            self.emulator_running = False
            return False

    def start_emulator_fallback(self):
        """Fallback method to start FUSE without fullscreen"""
        try:
            logger.info('Starting FUSE emulator in windowed mode...')
            
            fuse_env = os.environ.copy()
            fuse_env.update({
                'DISPLAY': ':99',
                'SDL_VIDEODRIVER': 'x11',
                'SDL_AUDIODRIVER': 'pulse',
                'PULSE_RUNTIME_PATH': '/tmp/pulse'
            })
            
            # Start FUSE emulator in windowed mode
            self.emulator_process = subprocess.Popen([
                'fuse-sdl', 
                '--machine', '48',
                '--graphics-filter', 'none',
                '--no-sound',
                '--no-confirm-actions'
                # No fullscreen or window size forcing
            ], env=fuse_env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            time.sleep(5)
            
            if self.emulator_process.poll() is not None:
                stdout, stderr = self.emulator_process.communicate()
                logger.error('FUSE emulator fallback also failed:')
                logger.error(f'STDOUT: {stdout.decode()}')
                logger.error(f'STDERR: {stderr.decode()}')
                self.emulator_running = False
                return False
            else:
                logger.info('FUSE emulator started successfully in windowed mode')
                self.emulator_running = True
                time.sleep(3)
                self.check_emulator_window()
                return True
                
        except Exception as e:
            logger.error(f'Error in emulator fallback: {e}')
            self.emulator_running = False
            return False

    def check_emulator_window(self):
        """Check if emulator window is visible on the display"""
        try:
            # Use xwininfo to check for windows on display :99
            result = subprocess.run(['xwininfo', '-display', ':99', '-root', '-tree'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                logger.info("X11 window tree:")
                logger.info(result.stdout)
                
                # Look for FUSE window
                if 'fuse' in result.stdout.lower() or 'spectrum' in result.stdout.lower():
                    logger.info("FUSE emulator window detected on display")
                else:
                    logger.warning("No FUSE window detected - emulator may not be visible")
            else:
                logger.warning(f"Could not check window tree: {result.stderr}")
                
        except Exception as e:
            logger.warning(f"Could not check emulator window: {e}")

    def start_ffmpeg_stream(self):
        """Start FFmpeg for HLS streaming with better capture settings"""
        try:
            logger.info("Starting FFmpeg with improved capture settings...")
            
            # Create stream directory
            os.makedirs('/tmp/stream', exist_ok=True)
            
            # FFmpeg command with better X11 capture
            ffmpeg_cmd = [
                'ffmpeg', '-f', 'x11grab', 
                '-video_size', '256x192',
                '-framerate', '25',
                '-i', ':99.0+0,0',  # Capture from top-left corner
                '-f', 'pulse', '-i', 'default',
                '-vf', 
                "drawtext=text='v1.0.0-fixed-v4':fontcolor=yellow:fontsize=12:x=5:y=5:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf,"
                "drawtext=text='RETROBOT':fontcolor=blue:fontsize=14:x=w-tw-5:y=h-th-5:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
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
                logger.info("FFmpeg started successfully with improved capture")
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
        """Handle WebSocket connections - FIXED VERSION WITH KEY FORWARDING"""
        self.connected_clients.add(websocket)
        logger.info('connection open')
        
        try:
            # Send initial status
            await websocket.send(json.dumps({
                'type': 'connected',
                'emulator_running': self.emulator_running,
                'message': 'Connected to ZX Spectrum Emulator v4 - Interactive Keys!'
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
                    
                    elif data.get('type') == 'key_press' or data.get('type') == 'key_input':
                        key = data.get('key')
                        action = data.get('action', 'press')  # Default to press if not specified
                        
                        if key and self.emulator_running:
                            # Only process key press events (ignore releases for now)
                            if action == 'press':
                                success = self.send_key_to_emulator(key)
                                await websocket.send(json.dumps({
                                    'type': 'key_response',
                                    'key': key,
                                    'action': action,
                                    'processed': success,
                                    'message': f'Key {key} {"sent" if success else "failed"}'
                                }))
                            else:
                                # Acknowledge key release but don't process
                                await websocket.send(json.dumps({
                                    'type': 'key_response',
                                    'key': key,
                                    'action': action,
                                    'processed': True,
                                    'message': f'Key {key} release acknowledged'
                                }))
                        else:
                            await websocket.send(json.dumps({
                                'type': 'key_response',
                                'key': key,
                                'action': action,
                                'processed': False,
                                'message': 'Emulator not running or invalid key'
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
                'version': '1.0.0-fixed-v4',
                'build_time': '2025-08-02T18:15:00Z',
                'build_hash': 'fixed-v4-interactive-keys',
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
        logger.info("Version: 1.0.0-fixed-v4")
        logger.info("Build Time: 2025-08-02T18:15:00Z")
        logger.info("Build Hash: fixed-v4-interactive-keys")
        
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
            logger.info("All services started. Server ready! Version: 1.0.0-fixed-v4")
            
            # Auto-start emulator after everything is ready
            logger.info("Auto-starting FUSE emulator with interactive key support...")
            success = self.start_emulator()
            if success:
                logger.info("FUSE emulator auto-started successfully - Interactive keys enabled!")
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
    emulator = InteractiveSpectrumEmulator()
    emulator.run()
