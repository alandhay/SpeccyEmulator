#!/usr/bin/env python3

import asyncio
import websockets
import json
import subprocess
import time
import signal
import sys
import os
import threading
import logging
from aiohttp import web
import boto3
from botocore.exceptions import NoCredentialsError

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class ZXSpectrumEmulatorServer:
    def __init__(self):
        self.server_start_time = time.time()
        self.connected_clients = set()
        self.emulator_process = None
        self.ffmpeg_process = None
        self.youtube_ffmpeg_process = None
        self.xvfb_process = None
        self.pulseaudio_process = None
        self.emulator_running = False
        self.s3_upload_thread = None
        self.s3_client = None
        
        # Environment variables
        self.stream_bucket = os.getenv('STREAM_BUCKET', 'spectrum-emulator-stream-dev-043309319786')
        self.youtube_stream_key = os.getenv('YOUTUBE_STREAM_KEY', '')
        self.capture_size = os.getenv('CAPTURE_SIZE', '256x192')
        self.display_size = os.getenv('DISPLAY_SIZE', '256x192')  # Match capture size for proper scaling
        self.capture_offset = os.getenv('CAPTURE_OFFSET', '0,0')
        self.scale_factor = int(os.getenv('SCALE_FACTOR', '2'))  # Explicit scaling factor
        
        # Key mapping for ZX Spectrum with improved coverage
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
        """Set up Xvfb virtual display"""
        try:
            logger.info("Starting Xvfb virtual display...")
            # Use native ZX Spectrum resolution for the virtual display
            display_resolution = f"{self.display_size}x24"
            logger.info(f"Setting up virtual display with resolution: {display_resolution}")
            
            self.xvfb_process = subprocess.Popen([
                'Xvfb', ':99', 
                '-screen', '0', display_resolution,
                '-ac', '+extension', 'GLX'
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            # Wait a moment for Xvfb to start
            time.sleep(3)
            
            # Verify display is working
            result = subprocess.run(['xdpyinfo', '-display', ':99'], 
                                  capture_output=True, text=True, env={'DISPLAY': ':99'})
            if result.returncode == 0:
                logger.info("Xvfb started successfully on display :99")
                display_info = result.stdout.split('\n')[:3]
                logger.info(f"Display info: {display_info}")
                return True
            else:
                logger.error(f"Failed to verify Xvfb display: {result.stderr}")
                return False
                
        except Exception as e:
            logger.error(f"Failed to start Xvfb: {e}")
            return False

    def setup_pulseaudio(self):
        """Set up PulseAudio for audio"""
        try:
            logger.info("Starting PulseAudio...")
            # Create pulse runtime directory
            os.makedirs('/tmp/pulse', exist_ok=True)
            
            # Start PulseAudio in daemon mode
            self.pulseaudio_process = subprocess.Popen([
                'pulseaudio', '--start', '--exit-idle-time=-1',
                '--system=false', '--disallow-exit'
            ], env={'PULSE_RUNTIME_PATH': '/tmp/pulse'})
            
            time.sleep(2)
            logger.info("PulseAudio started successfully")
            return True
            
        except Exception as e:
            logger.error(f"Failed to start PulseAudio: {e}")
            return False

    def send_mouse_click_to_emulator(self, button, x=None, y=None):
        """Send mouse click to emulator using xdotool"""
        if not self.emulator_running:
            return False, "Emulator not running"
        
        try:
            # Map button names to xdotool button numbers
            button_map = {
                'left': '1',
                'middle': '2', 
                'right': '3',
                'scroll_up': '4',
                'scroll_down': '5'
            }
            
            if button.lower() not in button_map:
                return False, f"Invalid mouse button: {button}"
            
            button_num = button_map[button.lower()]
            
            # Build xdotool command
            cmd = ['xdotool']
            
            # If coordinates provided, move mouse first
            if x is not None and y is not None:
                # Ensure coordinates are within emulator bounds (256x192)
                x = max(0, min(255, int(x)))
                y = max(0, min(191, int(y)))
                cmd.extend(['mousemove', '--window', f'$(xdotool search --name "Fuse")', str(x), str(y)])
                cmd.append('&&')
                cmd.extend(['xdotool'])
            
            # Add click command
            if x is not None and y is not None:
                cmd.extend(['click', '--window', f'$(xdotool search --name "Fuse")', button_num])
            else:
                cmd.extend(['click', button_num])
            
            # Execute command
            result = subprocess.run(
                ' '.join(cmd), 
                shell=True,
                env={'DISPLAY': ':99'}, 
                capture_output=True, 
                text=True,
                timeout=2
            )
            
            if result.returncode == 0:
                coord_info = f" at ({x},{y})" if x is not None and y is not None else ""
                logger.info(f"✅ Mouse {button} click{coord_info} sent successfully")
                return True, f"Mouse {button} click{coord_info} processed successfully"
            else:
                error_msg = f"xdotool mouse click failed: {result.stderr}"
                logger.error(f"❌ {error_msg}")
                return False, error_msg
                
        except subprocess.TimeoutExpired:
            error_msg = "Mouse click command timed out"
            logger.error(f"❌ {error_msg}")
            return False, error_msg
        except Exception as e:
            error_msg = f"Mouse click error: {str(e)}"
            logger.error(f"❌ {error_msg}")
            return False, error_msg

    def send_key_to_emulator(self, key):
        """Send key press to FUSE emulator using xdotool with improved feedback"""
        try:
            if not self.emulator_running:
                logger.warning(f"Emulator not running, ignoring key: {key}")
                return False, "Emulator not running"
                
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

    def send_key_release_to_emulator(self, key):
        """Send key release to FUSE emulator using xdotool"""
        try:
            if not self.emulator_running:
                logger.warning(f"Emulator not running, ignoring key release: {key}")
                return False, "Emulator not running"
                
            # Map the key to X11 key name
            x11_key = self.key_mapping.get(key, key.lower())
            
            # Use xdotool to send key release to the FUSE window
            result = subprocess.run([
                'xdotool', 
                'search', '--name', 'Fuse',
                'windowfocus',
                'keyup', x11_key
            ], env={'DISPLAY': ':99'}, capture_output=True, text=True)
            
            if result.returncode == 0:
                logger.info(f"✅ Successfully sent key release '{key}' (mapped to '{x11_key}') to FUSE emulator")
                return True, f"Key '{key}' release sent successfully"
            else:
                logger.error(f"❌ Failed to send key release '{key}': {result.stderr}")
                return False, f"xdotool error: {result.stderr.strip()}"
                
        except Exception as e:
            logger.error(f"❌ Exception sending key release '{key}' to emulator: {e}")
            return False, f"Exception: {str(e)}"

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

            # Start FUSE emulator with better settings for precise capture
            self.emulator_process = subprocess.Popen([
                'fuse-sdl',
                '--machine', '48',
                '--no-sound',  # Disable sound for now to avoid conflicts
                '--graphics-filter', 'none',
                # Remove --full-screen to allow precise window sizing
            ], env={
                'DISPLAY': ':99',
                'SDL_VIDEODRIVER': 'x11',
                'SDL_AUDIODRIVER': 'pulse'
            }, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

            # Wait for emulator to start
            time.sleep(5)
            
            # Check if emulator is still running
            if self.emulator_process.poll() is None:
                logger.info("FUSE emulator started successfully")
                self.emulator_running = True
                
                # Wait a bit more and check for window
                time.sleep(3)
                self.check_emulator_window()
                
                return True
            else:
                logger.error("FUSE emulator failed to start or exited immediately")
                self.emulator_running = False
                return False

        except Exception as e:
            logger.error(f'Failed to start FUSE emulator: {e}')
            self.emulator_running = False
            return False

    def check_emulator_window(self):
        """Check if FUSE emulator window is available"""
        try:
            # Get window tree to see what's available
            result = subprocess.run(['xwininfo', '-tree', '-root'], 
                                  env={'DISPLAY': ':99'}, capture_output=True, text=True)
            if result.returncode == 0:
                logger.info("X11 window tree:")
                logger.info(result.stdout)
                
                # Check if FUSE window exists
                if 'Fuse' in result.stdout:
                    logger.info("FUSE emulator window detected on display")
                    return True
                else:
                    logger.warning("FUSE emulator window not found in X11 tree")
                    return False
            else:
                logger.error(f"Failed to get window tree: {result.stderr}")
                return False
                
        except Exception as e:
            logger.error(f"Error checking emulator window: {e}")
            return False

    def stop_emulator(self):
        """Stop the FUSE emulator"""
        if self.emulator_process:
            try:
                self.emulator_process.terminate()
                self.emulator_process.wait(timeout=5)
                logger.info("FUSE emulator stopped")
            except Exception as e:
                logger.error(f"Error stopping emulator: {e}")
        self.emulator_running = False

    def start_ffmpeg_stream(self):
        """Start FFmpeg for video capture and streaming"""
        try:
            logger.info("Starting FFmpeg with improved capture settings...")
            
            # Calculate scaled output size for web display
            capture_width, capture_height = map(int, self.capture_size.split('x'))
            output_width = capture_width * self.scale_factor
            output_height = capture_height * self.scale_factor
            
            logger.info(f"Capture size: {self.capture_size}, Output size: {output_width}x{output_height}")
            
            # FFmpeg command for HLS streaming with proper scaling
            ffmpeg_cmd = [
                'ffmpeg',
                '-f', 'x11grab',
                '-video_size', self.capture_size,  # Exact capture size
                '-framerate', '25',
                '-draw_mouse', '0',  # Hide mouse cursor from capture
                '-i', f':99.0+{self.capture_offset}',  # Capture from exact position
                '-f', 'pulse',
                '-i', 'default',
                # Video filters: scale to 2x size with nearest neighbor for pixel-perfect scaling
                '-vf', f"scale={output_width}:{output_height}:flags=neighbor",
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
            
            logger.info(f"FFmpeg command: {' '.join(ffmpeg_cmd)}")
            
            # Create stream directory
            os.makedirs('/tmp/stream', exist_ok=True)
            
            # Start FFmpeg
            self.ffmpeg_process = subprocess.Popen(
                ffmpeg_cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            
            # Wait a moment and check if it's running
            time.sleep(3)
            if self.ffmpeg_process.poll() is None:
                logger.info("FFmpeg started successfully with improved capture")
                return True
            else:
                logger.error("FFmpeg failed to start")
                return False
                
        except Exception as e:
            logger.error(f"Failed to start FFmpeg: {e}")
            return False

    def start_youtube_stream(self):
        """Start YouTube RTMP streaming"""
        if not self.youtube_stream_key:
            logger.info('No YouTube stream key provided, skipping YouTube streaming')
            return False
            
        try:
            # Calculate scaled output size for YouTube
            capture_width, capture_height = map(int, self.capture_size.split('x'))
            output_width = capture_width * self.scale_factor
            output_height = capture_height * self.scale_factor
            
            logger.info(f'Starting YouTube RTMP stream at {output_width}x{output_height}')
            
            # YouTube FFmpeg command with proper scaling
            youtube_cmd = [
                'ffmpeg', '-y',
                '-f', 'x11grab',
                '-video_size', self.capture_size,  # Capture native resolution
                '-framerate', '25',
                '-draw_mouse', '0',  # Hide mouse cursor from capture
                '-i', f':99.0+{self.capture_offset}',
                '-f', 'pulse',
                '-i', 'default',
                # Scale for YouTube with nearest neighbor for pixel-perfect scaling
                '-vf', f'scale={output_width}:{output_height}:flags=neighbor',
                '-c:v', 'libx264',
                '-preset', 'veryfast',
                '-tune', 'zerolatency',
                '-g', '50',
                '-keyint_min', '25',
                '-sc_threshold', '0',
                '-b:v', '2500k',  # Higher bitrate for YouTube
                '-maxrate', '3000k',
                '-bufsize', '6000k',
                '-pix_fmt', 'yuv420p',
                '-c:a', 'aac',
                '-b:a', '128k',
                '-ar', '44100',
                '-f', 'flv',
                f'rtmp://a.rtmp.youtube.com/live2/{self.youtube_stream_key}'
            ]
            
            logger.info(f"YouTube FFmpeg command: {' '.join(youtube_cmd)}")
            
            # Start YouTube FFmpeg process
            self.youtube_ffmpeg_process = subprocess.Popen(
                youtube_cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            
            # Wait a moment and check if it's running
            time.sleep(3)
            if self.youtube_ffmpeg_process.poll() is None:
                logger.info("✅ YouTube RTMP streaming started successfully")
                return True
            else:
                logger.error("❌ YouTube FFmpeg failed to start")
                return False
                
        except Exception as e:
            logger.error(f"Failed to start YouTube stream: {e}")
            return False

    def start_s3_upload_thread(self):
        """Start background thread for S3 uploads"""
        if not self.s3_client:
            logger.warning("S3 client not available, skipping S3 uploads")
            return
            
        def upload_loop():
            while True:
                try:
                    # Upload HLS files to S3
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
                            self.s3_client.upload_file(
                                f'/tmp/stream/{file}',
                                self.stream_bucket,
                                f'hls/{file}',
                                ExtraArgs={'ContentType': 'video/mp2t'}
                            )
                    
                    time.sleep(2)
                except Exception as e:
                    logger.error(f"S3 upload error: {e}")
                    time.sleep(5)
        
        self.s3_upload_thread = threading.Thread(target=upload_loop, daemon=True)
        self.s3_upload_thread.start()
        logger.info("S3 upload thread started")

    async def handle_websocket(self, websocket, path=None):
        """Handle WebSocket connections with improved key event feedback"""
        self.connected_clients.add(websocket)
        logger.info('connection open')
        
        # Send initial status
        await websocket.send(json.dumps({
            'type': 'connected',
            'emulator_running': self.emulator_running,
            'server_version': '1.0.0-fixed-v5',
            'features': ['interactive_keys', 'real_time_feedback', 'key_press_and_release']
        }))
        
        try:
            async for message in websocket:
                try:
                    data = json.loads(message)
                    logger.info(f'📨 Received message: {data}')
                    
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
                        
                        if key:
                            if action == 'press':
                                # Process key press
                                success, message = self.send_key_to_emulator(key)
                                await websocket.send(json.dumps({
                                    'type': 'key_response',
                                    'key': key,
                                    'action': action,
                                    'processed': success,
                                    'emulator_running': self.emulator_running,
                                    'message': message,
                                    'timestamp': time.time()
                                }))
                                
                            elif action == 'release':
                                # Process key release
                                success, message = self.send_key_release_to_emulator(key)
                                await websocket.send(json.dumps({
                                    'type': 'key_response',
                                    'key': key,
                                    'action': action,
                                    'processed': success,
                                    'emulator_running': self.emulator_running,
                                    'message': message,
                                    'timestamp': time.time()
                                }))
                        else:
                            await websocket.send(json.dumps({
                                'type': 'key_response',
                                'key': key,
                                'action': action,
                                'processed': False,
                                'emulator_running': self.emulator_running,
                                'message': 'Invalid key - key name is empty or null',
                                'timestamp': time.time()
                            }))
                    
                    elif data.get('type') == 'mouse_click':
                        button = data.get('button', 'left')  # Default to left click
                        x = data.get('x')  # Optional coordinates
                        y = data.get('y')
                        
                        # Process mouse click
                        success, message = self.send_mouse_click_to_emulator(button, x, y)
                        await websocket.send(json.dumps({
                            'type': 'mouse_response',
                            'button': button,
                            'x': x,
                            'y': y,
                            'processed': success,
                            'emulator_running': self.emulator_running,
                            'message': message,
                            'timestamp': time.time()
                        }))
                    
                    elif data.get('type') == 'status':
                        await websocket.send(json.dumps({
                            'type': 'status_response',
                            'emulator_running': self.emulator_running,
                            'uptime': time.time() - self.server_start_time,
                            'connected_clients': len(self.connected_clients),
                            'server_version': '1.0.0-fixed-v5'
                        }))
                    
                    elif data.get('type') == 'ping':
                        await websocket.send(json.dumps({
                            'type': 'pong',
                            'timestamp': time.time()
                        }))
                    
                    else:
                        await websocket.send(json.dumps({
                            'type': 'error',
                            'message': f'Unknown message type: {data.get("type")}',
                            'timestamp': time.time()
                        }))
                        
                except json.JSONDecodeError:
                    await websocket.send(json.dumps({
                        'type': 'error',
                        'message': 'Invalid JSON format',
                        'timestamp': time.time()
                    }))
                except Exception as e:
                    logger.error(f'Error processing message: {e}')
                    await websocket.send(json.dumps({
                        'type': 'error',
                        'message': f'Server error: {str(e)}',
                        'timestamp': time.time()
                    }))
                    
        except websockets.exceptions.ConnectionClosed:
            logger.info('WebSocket connection closed')
        except Exception as e:
            logger.error(f'WebSocket error: {e}')
        finally:
            self.connected_clients.discard(websocket)
            logger.info('connection closed')

    async def health_check(self, request):
        """Health check endpoint with enhanced status"""
        # Check YouTube streaming status
        youtube_streaming = (self.youtube_ffmpeg_process is not None and 
                           self.youtube_ffmpeg_process.poll() is None)
        
        features = ['interactive_keys', 'real_time_feedback', 'key_press_and_release', 'mouse_support']
        if youtube_streaming:
            features.append('youtube_streaming')
        
        return web.json_response({
            'status': 'OK',
            'version': {
                'version': '1.0.0-v7-complete',
                'build_time': '2025-08-02T19:00:00Z',
                'build_hash': 'v7-mouse-cursor-keyboard-fixes',
                'uptime': time.time() - self.server_start_time
            },
            'emulator_running': self.emulator_running,
            'connected_clients': len(self.connected_clients),
            'youtube_streaming': youtube_streaming,
            'features': features,
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
        logger.info("Version: 1.0.0-fixed-v5")
        logger.info("Build Time: 2025-08-02T19:30:00Z")
        logger.info("Build Hash: fixed-v5-enhanced-feedback")
        logger.info("Features: Interactive keys with real-time feedback")
        
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
        
        # Start YouTube streaming
        if self.youtube_stream_key:
            if not self.start_youtube_stream():
                logger.warning("YouTube streaming failed to start, continuing without it")
        else:
            logger.info("No YouTube stream key provided, skipping YouTube streaming")
        
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
            # Use the corrected handler without path parameter
            server = await websockets.serve(self.handle_websocket, '0.0.0.0', 8765)
            logger.info("server listening on 0.0.0.0:8765")
            logger.info("All services started. Server ready! Version: 1.0.0-fixed-v5")
            
            # Auto-start emulator after everything is ready
            logger.info("Auto-starting FUSE emulator with enhanced key feedback...")
            success = self.start_emulator()
            if success:
                logger.info("✅ FUSE emulator auto-started successfully - Enhanced interactive keys enabled!")
            else:
                logger.error("❌ FUSE emulator auto-start failed")
        
        # Run the event loop
        try:
            asyncio.get_event_loop().run_until_complete(start_servers())
            asyncio.get_event_loop().run_forever()
        except KeyboardInterrupt:
            logger.info("Server stopped by user")
        except Exception as e:
            logger.error(f"Server error: {e}")
        finally:
            self.cleanup()

if __name__ == '__main__':
    server = ZXSpectrumEmulatorServer()
    server.run()
