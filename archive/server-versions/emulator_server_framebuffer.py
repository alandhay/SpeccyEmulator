#!/usr/bin/env python3
"""
ZX Spectrum Emulator Server - Framebuffer Edition
Eliminates window positioning issues with direct framebuffer capture
"""

import asyncio
import websockets
import json
import subprocess
import threading
import time
import os
import signal
import sys
import logging
from aiohttp import web
import boto3
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class FramebufferEmulatorServer:
    def __init__(self):
        self.websocket_clients = set()
        self.emulator_process = None
        self.xvfb_process = None
        self.pulseaudio_process = None
        self.ffmpeg_hls_process = None
        self.ffmpeg_youtube_process = None
        self.s3_client = None
        self.upload_thread = None
        self.running = True
        
        # Environment configuration
        self.stream_bucket = os.getenv('STREAM_BUCKET', 'spectrum-emulator-stream-dev-043309319786')
        self.youtube_key = os.getenv('YOUTUBE_STREAM_KEY', '')
        self.version = os.getenv('VERSION', '1.0.0-framebuffer-test')
        self.build_time = os.getenv('BUILD_TIME', '2025-08-03T08:00:00Z')
        
        # Framebuffer configuration
        self.display_size = "256x192"  # Exact ZX Spectrum resolution
        self.capture_size = "256x192"  # Capture exactly what we create
        self.output_size = "512x384"   # 2x scaling for web display
        
        logger.info("Starting Framebuffer ZX Spectrum Emulator Server")
        logger.info(f"Version: {self.version}")
        logger.info(f"Build Time: {self.build_time}")
        logger.info(f"Display Size: {self.display_size}")
        logger.info(f"Capture Size: {self.capture_size}")
        logger.info(f"Output Size: {self.output_size}")

    def setup_s3_client(self):
        """Initialize S3 client for HLS uploads"""
        try:
            self.s3_client = boto3.client('s3')
            logger.info("S3 client initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize S3 client: {e}")

    def start_xvfb(self):
        """Start virtual framebuffer with exact dimensions"""
        try:
            logger.info("Starting Xvfb virtual framebuffer...")
            logger.info(f"Creating framebuffer with exact resolution: {self.display_size}x24")
            
            # Create virtual framebuffer with exact ZX Spectrum dimensions
            self.xvfb_process = subprocess.Popen([
                'Xvfb', ':99',
                '-screen', '0', f'{self.display_size}x24',
                '-ac',
                '+extension', 'GLX',
                '-fbdir', '/tmp'  # Store framebuffer files in /tmp
            ])
            
            # Wait for Xvfb to start
            time.sleep(3)
            
            # Verify display is available
            result = subprocess.run(['xdpyinfo', '-display', ':99'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                logger.info("Xvfb started successfully on display :99")
                logger.info(f"Display info: {result.stdout.split('dimensions:')[1].split('pixels')[0].strip()} pixels")
            else:
                raise Exception("Xvfb failed to start properly")
                
        except Exception as e:
            logger.error(f"Failed to start Xvfb: {e}")
            raise

    def start_pulseaudio(self):
        """Start PulseAudio for audio processing"""
        try:
            logger.info("Starting PulseAudio...")
            
            # Start PulseAudio in daemon mode
            self.pulseaudio_process = subprocess.Popen([
                'pulseaudio', '--start', '--exit-idle-time=-1'
            ])
            
            time.sleep(2)
            logger.info("PulseAudio started successfully")
            
        except Exception as e:
            logger.error(f"Failed to start PulseAudio: {e}")
            raise

    def start_ffmpeg_hls(self):
        """Start FFmpeg for HLS streaming with framebuffer capture"""
        try:
            logger.info("Starting FFmpeg HLS with framebuffer capture...")
            logger.info(f"Capture: {self.capture_size}, Output: {self.output_size}")
            
            # Framebuffer-optimized FFmpeg command
            ffmpeg_cmd = [
                'ffmpeg',
                # Input: X11 grab with exact dimensions
                '-f', 'x11grab',
                '-video_size', self.capture_size,
                '-framerate', '25',
                '-draw_mouse', '0',  # Hide cursor
                '-i', ':99.0+0,0',   # Capture from exact top-left
                # Audio input
                '-f', 'pulse',
                '-i', 'default',
                # Video processing: Simple 2x scaling
                '-vf', f'scale={self.output_size.replace("x", ":")}:flags=neighbor',
                # Video encoding
                '-c:v', 'libx264',
                '-preset', 'ultrafast',
                '-tune', 'zerolatency',
                '-pix_fmt', 'yuv420p',
                # Audio encoding
                '-c:a', 'aac',
                '-b:a', '128k',
                # HLS output
                '-f', 'hls',
                '-hls_time', '2',
                '-hls_list_size', '5',
                '-hls_flags', 'delete_segments',
                '-hls_segment_filename', '/tmp/stream/stream%d.ts',
                '/tmp/stream/stream.m3u8'
            ]
            
            logger.info(f"FFmpeg HLS command: {' '.join(ffmpeg_cmd)}")
            
            self.ffmpeg_hls_process = subprocess.Popen(
                ffmpeg_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            time.sleep(3)
            
            if self.ffmpeg_hls_process.poll() is None:
                logger.info("✅ FFmpeg HLS started successfully with framebuffer capture")
            else:
                raise Exception("FFmpeg HLS failed to start")
                
        except Exception as e:
            logger.error(f"Failed to start FFmpeg HLS: {e}")
            raise

    def start_ffmpeg_youtube(self):
        """Start FFmpeg for YouTube RTMP streaming"""
        if not self.youtube_key:
            logger.info("No YouTube key provided, skipping RTMP stream")
            return
            
        try:
            logger.info("Starting YouTube RTMP stream with framebuffer capture...")
            
            youtube_cmd = [
                'ffmpeg', '-y',
                # Input: Same framebuffer capture
                '-f', 'x11grab',
                '-video_size', self.capture_size,
                '-framerate', '25',
                '-draw_mouse', '0',
                '-i', ':99.0+0,0',
                # Audio input
                '-f', 'pulse',
                '-i', 'default',
                # Video processing
                '-vf', f'scale={self.output_size.replace("x", ":")}:flags=neighbor',
                # Video encoding for streaming
                '-c:v', 'libx264',
                '-preset', 'veryfast',
                '-tune', 'zerolatency',
                '-g', '50',
                '-keyint_min', '25',
                '-sc_threshold', '0',
                '-b:v', '2500k',
                '-maxrate', '3000k',
                '-bufsize', '6000k',
                '-pix_fmt', 'yuv420p',
                # Audio encoding
                '-c:a', 'aac',
                '-b:a', '128k',
                '-ar', '44100',
                # RTMP output
                '-f', 'flv',
                f'rtmp://a.rtmp.youtube.com/live2/{self.youtube_key}'
            ]
            
            logger.info(f"YouTube FFmpeg command: {' '.join(youtube_cmd)}")
            
            self.ffmpeg_youtube_process = subprocess.Popen(
                youtube_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            time.sleep(3)
            
            if self.ffmpeg_youtube_process.poll() is None:
                logger.info("✅ YouTube RTMP streaming started successfully")
            else:
                logger.warning("YouTube RTMP stream failed to start")
                
        except Exception as e:
            logger.error(f"Failed to start YouTube stream: {e}")

    def start_emulator(self):
        """Start FUSE emulator in fullscreen framebuffer mode"""
        try:
            logger.info("Starting FUSE emulator in framebuffer mode...")
            
            # Launch FUSE in fullscreen mode for deterministic sizing
            emulator_cmd = [
                'fuse-sdl',
                '--machine', '48',           # ZX Spectrum 48K
                '--graphics-filter', 'none', # No filtering for pixel-perfect
                '--fullscreen',              # Force fullscreen for exact sizing
                '--no-sound'                 # Audio handled by PulseAudio
            ]
            
            logger.info(f"FUSE command: {' '.join(emulator_cmd)}")
            
            # Set environment for framebuffer mode
            env = os.environ.copy()
            env['DISPLAY'] = ':99'
            env['SDL_VIDEODRIVER'] = 'x11'
            
            self.emulator_process = subprocess.Popen(
                emulator_cmd,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            # Wait for emulator to initialize
            time.sleep(5)
            
            if self.emulator_process.poll() is None:
                logger.info("✅ FUSE emulator started successfully in framebuffer mode")
                
                # Verify window is exactly where expected
                self.validate_framebuffer_setup()
            else:
                raise Exception("FUSE emulator failed to start")
                
        except Exception as e:
            logger.error(f"Failed to start FUSE emulator: {e}")
            raise

    def validate_framebuffer_setup(self):
        """Validate that framebuffer is set up correctly"""
        try:
            # Check display dimensions
            result = subprocess.run(['xdpyinfo', '-display', ':99'], 
                                  capture_output=True, text=True)
            if 'dimensions:    256x192 pixels' in result.stdout:
                logger.info("✅ Framebuffer validated: Exact 256x192 dimensions")
            else:
                logger.warning(f"Framebuffer dimensions may be incorrect: {result.stdout}")
                
            # Check for FUSE window
            result = subprocess.run(['xdotool', 'search', '--name', 'Fuse'], 
                                  capture_output=True, text=True, env={'DISPLAY': ':99'})
            if result.returncode == 0:
                window_id = result.stdout.strip()
                logger.info(f"✅ FUSE window found: ID {window_id}")
                
                # Get window geometry
                result = subprocess.run(['xdotool', 'getwindowgeometry', window_id], 
                                      capture_output=True, text=True, env={'DISPLAY': ':99'})
                logger.info(f"Window geometry: {result.stdout}")
            else:
                logger.warning("FUSE window not found")
                
        except Exception as e:
            logger.warning(f"Framebuffer validation failed: {e}")

    def start_s3_upload_thread(self):
        """Start background thread for S3 uploads"""
        if not self.s3_client:
            logger.warning("S3 client not available, skipping uploads")
            return
            
        def upload_worker():
            logger.info("S3 upload thread started")
            while self.running:
                try:
                    # Upload HLS manifest
                    if os.path.exists('/tmp/stream/stream.m3u8'):
                        self.s3_client.upload_file(
                            '/tmp/stream/stream.m3u8',
                            self.stream_bucket,
                            'hls/stream.m3u8',
                            ExtraArgs={'ContentType': 'application/vnd.apple.mpegurl'}
                        )
                    
                    # Upload TS segments
                    for file in os.listdir('/tmp/stream'):
                        if file.endswith('.ts'):
                            local_path = f'/tmp/stream/{file}'
                            s3_key = f'hls/{file}'
                            
                            self.s3_client.upload_file(
                                local_path,
                                self.stream_bucket,
                                s3_key,
                                ExtraArgs={'ContentType': 'video/mp2t'}
                            )
                            
                except Exception as e:
                    logger.error(f"S3 upload error: {e}")
                    
                time.sleep(2)
        
        self.upload_thread = threading.Thread(target=upload_worker, daemon=True)
        self.upload_thread.start()

    async def handle_websocket(self, websocket, path):
        """Handle WebSocket connections"""
        logger.info("WebSocket connection established")
        self.websocket_clients.add(websocket)
        
        try:
            await websocket.send(json.dumps({
                'type': 'connected',
                'version': self.version,
                'emulator_running': self.emulator_process is not None,
                'framebuffer_mode': True
            }))
            
            async for message in websocket:
                try:
                    data = json.loads(message)
                    logger.info(f"📨 Received message: {data}")
                    
                    if data.get('type') == 'status':
                        await websocket.send(json.dumps({
                            'type': 'status_response',
                            'emulator_running': self.emulator_process is not None,
                            'version': self.version,
                            'framebuffer_mode': True,
                            'display_size': self.display_size,
                            'capture_size': self.capture_size,
                            'output_size': self.output_size
                        }))
                        
                except json.JSONDecodeError:
                    logger.error("Invalid JSON received")
                except Exception as e:
                    logger.error(f"Error handling message: {e}")
                    
        except websockets.exceptions.ConnectionClosed:
            logger.info("WebSocket connection closed")
        finally:
            self.websocket_clients.discard(websocket)

    async def health_check(self, request):
        """Health check endpoint"""
        status = {
            'status': 'healthy',
            'version': self.version,
            'framebuffer_mode': True,
            'services': {
                'xvfb': self.xvfb_process is not None and self.xvfb_process.poll() is None,
                'emulator': self.emulator_process is not None and self.emulator_process.poll() is None,
                'ffmpeg_hls': self.ffmpeg_hls_process is not None and self.ffmpeg_hls_process.poll() is None,
                'ffmpeg_youtube': self.ffmpeg_youtube_process is not None and self.ffmpeg_youtube_process.poll() is None,
            }
        }
        
        return web.json_response(status)

    def cleanup(self):
        """Clean up all processes"""
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

    async def start_server(self):
        """Start all services"""
        try:
            # Initialize S3
            self.setup_s3_client()
            
            # Start core services
            self.start_xvfb()
            self.start_pulseaudio()
            
            # Start video processing
            self.start_ffmpeg_hls()
            self.start_ffmpeg_youtube()
            
            # Start S3 uploads
            self.start_s3_upload_thread()
            
            # Start emulator
            self.start_emulator()
            
            # Start HTTP server for health checks
            app = web.Application()
            app.router.add_get('/health', self.health_check)
            runner = web.AppRunner(app)
            await runner.setup()
            site = web.TCPSite(runner, '0.0.0.0', 8080)
            await site.start()
            logger.info("Health check server started on port 8080")
            
            # Start WebSocket server
            start_server = websockets.serve(
                self.handle_websocket, '0.0.0.0', 8765
            )
            websocket_server = await start_server
            logger.info("WebSocket server started on port 8765")
            
            logger.info("🎮 All services started! Framebuffer ZX Spectrum Emulator ready!")
            logger.info(f"📺 Framebuffer Mode: {self.display_size} → {self.output_size}")
            
            # Keep server running indefinitely
            await websocket_server.wait_closed()
            
        except Exception as e:
            logger.error(f"Failed to start server: {e}")
            self.cleanup()
            raise

def signal_handler(signum, frame):
    """Handle shutdown signals"""
    logger.info("Received shutdown signal")
    sys.exit(0)

if __name__ == "__main__":
    # Set up signal handlers
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    # Print startup banner
    print("=" * 60)
    print("🎮 ZX Spectrum Emulator Server - Framebuffer Edition")
    print("📺 Deterministic capture with pixel-perfect positioning")
    print("=" * 60)
    
    server = FramebufferEmulatorServer()
    
    try:
        asyncio.run(server.start_server())
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
    except Exception as e:
        logger.error(f"Server error: {e}")
    finally:
        server.cleanup()
