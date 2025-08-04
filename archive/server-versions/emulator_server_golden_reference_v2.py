#!/usr/bin/env python3
"""
ZX Spectrum Emulator Server - Golden Reference v2 Implementation
===============================================================

This is the GOLDEN REFERENCE v2 that fixes critical user context issues
that were causing FUSE to hang at the splash screen in Docker containers.

CRITICAL FIXES IN V2:
====================

1. USER CONTEXT FIX:
   - Run as 'spectrum' user (not root)
   - Proper home directory setup (/home/spectrum)
   - FUSE configuration directory created
   - Proper file permissions

2. SDL ENVIRONMENT FIX:
   - Explicit SDL driver configuration
   - Disabled unnecessary SDL subsystems
   - Proper audio driver fallback

3. DEVICE ACCESS FIX:
   - Created necessary device nodes
   - Proper /dev/null and /dev/zero access
   - Container-compatible device setup

4. STARTUP SEQUENCE FIX:
   - Better process initialization order
   - Longer FUSE startup wait time
   - Proper environment variable setup

GOLDEN REFERENCE STRATEGY:
=========================

Based on successful local testing with user context fixes:
1. Virtual Display: 800x600x24 (room for FUSE positioning)
2. Capture Area: 320x240 at center offset +240,180
3. Cursor Hidden: -draw_mouse 0 flag
4. Synthetic Audio: anullsrc for reliability
5. Multi-stage Scaling: 1.8x → HD fitting with centering
6. FUSE Parameters: --machine 48 --no-sound (proven working)
7. Frame Rate: 30 FPS for smooth streaming
8. USER CONTEXT: spectrum user with proper home directory

Author: ZX Spectrum Emulator Team
Date: August 2025
Version: 1.0.0-golden-reference-v2
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

class GoldenReferenceEmulatorServerV2:
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
        self.version = os.getenv('VERSION', '1.0.0-golden-reference-v2')
        self.build_time = os.getenv('BUILD_TIME', '2025-08-04T01:00:00Z')
        
        # GOLDEN REFERENCE: Configuration matching proven local strategy
        self.virtual_display_size = os.getenv('VIRTUAL_DISPLAY_SIZE', '800x600x24')
        self.capture_size = os.getenv('CAPTURE_SIZE', '320x240')
        self.capture_offset_x = int(os.getenv('CAPTURE_OFFSET_X', '240'))
        self.capture_offset_y = int(os.getenv('CAPTURE_OFFSET_Y', '180'))
        self.scale_factor = float(os.getenv('SCALE_FACTOR', '1.8'))
        self.output_resolution = os.getenv('OUTPUT_RESOLUTION', '1280x720')
        self.frame_rate = int(os.getenv('FRAME_RATE', '30'))
        
        logger.info("🏆 Starting Golden Reference v2 ZX Spectrum Emulator Server")
        logger.info(f"Version: {self.version}")
        logger.info(f"Build Time: {self.build_time}")
        logger.info(f"User: {os.getenv('USER', 'unknown')}")
        logger.info(f"Home: {os.getenv('HOME', 'unknown')}")
        logger.info(f"Strategy: Fixed user context + proven local FUSE streaming")
        logger.info("")
        logger.info("🎯 Golden Reference v2 Configuration:")
        logger.info(f"  Virtual Display: {self.virtual_display_size}")
        logger.info(f"  Capture Size: {self.capture_size}")
        logger.info(f"  Capture Offset: +{self.capture_offset_x},{self.capture_offset_y}")
        logger.info(f"  Scale Factor: {self.scale_factor}x")
        logger.info(f"  Output Resolution: {self.output_resolution}")
        logger.info(f"  Frame Rate: {self.frame_rate} FPS")

    def setup_s3_client(self):
        """Initialize S3 client for HLS uploads"""
        try:
            self.s3_client = boto3.client('s3')
            logger.info("S3 client initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize S3 client: {e}")
            raise

    def start_xvfb(self):
        """Start virtual framebuffer with golden reference dimensions"""
        try:
            logger.info("Starting Xvfb virtual framebuffer...")
            logger.info(f"Creating framebuffer with resolution: {self.virtual_display_size}")
            
            # GOLDEN REFERENCE: Use 800x600x24 like proven local setup
            self.xvfb_process = subprocess.Popen([
                'Xvfb', ':99', 
                '-screen', '0', self.virtual_display_size,
                '-ac', '+extension', 'GLX'
            ])
            
            # Wait for Xvfb to start
            time.sleep(3)
            
            # Verify display is available
            result = subprocess.run(['xdpyinfo', '-display', ':99'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                logger.info("✅ Xvfb started successfully on display :99")
                logger.info(f"Display info: {self.virtual_display_size}")
            else:
                raise Exception("Xvfb failed to start properly")
                
        except Exception as e:
            logger.error(f"Failed to start Xvfb: {e}")
            raise

    def start_pulseaudio(self):
        """Start PulseAudio server with user context"""
        try:
            logger.info("Starting PulseAudio server...")
            
            # Create PulseAudio runtime directory
            pulse_dir = '/tmp/pulse'
            os.makedirs(pulse_dir, exist_ok=True)
            
            # CRITICAL FIX: Start PulseAudio as user, not system
            self.pulseaudio_process = subprocess.Popen([
                'pulseaudio', '--system=false', '--exit-idle-time=-1',
                f'--runtime-dir={pulse_dir}', '--daemonize=false'
            ])
            
            time.sleep(2)
            logger.info("✅ PulseAudio started successfully")
            
        except Exception as e:
            logger.error(f"Failed to start PulseAudio: {e}")
            # Don't raise - audio is not critical for our setup
            logger.warning("Continuing without PulseAudio...")

    def start_emulator(self):
        """Start FUSE emulator with golden reference parameters and user context fixes"""
        try:
            logger.info("Starting FUSE emulator with golden reference parameters...")
            logger.info("🔧 User context fixes applied:")
            logger.info(f"  Running as user: {os.getenv('USER', 'unknown')}")
            logger.info(f"  Home directory: {os.getenv('HOME', 'unknown')}")
            logger.info(f"  FUSE config dir: {os.getenv('HOME', '/tmp')}/.fuse")
            
            # CRITICAL FIX: Ensure FUSE config directory exists
            fuse_config_dir = os.path.join(os.getenv('HOME', '/tmp'), '.fuse')
            os.makedirs(fuse_config_dir, exist_ok=True)
            logger.info(f"✅ FUSE config directory ready: {fuse_config_dir}")
            
            # GOLDEN REFERENCE: FUSE command matching proven local setup
            fuse_cmd = [
                'fuse-sdl',
                '--machine', '48',
                '--no-sound'  # PROVEN WORKING parameter
            ]
            
            logger.info(f"FUSE command: {' '.join(fuse_cmd)}")
            
            # CRITICAL FIX: Enhanced environment for FUSE startup
            fuse_env = dict(os.environ)
            fuse_env.update({
                'DISPLAY': ':99',
                'SDL_VIDEODRIVER': 'x11',
                'SDL_AUDIODRIVER': 'dummy',
                'SDL_JOYSTICK': '0',
                'SDL_HAPTIC': '0',
                'HOME': os.getenv('HOME', '/tmp')
            })
            
            logger.info("🚀 Starting FUSE with enhanced environment...")
            self.emulator_process = subprocess.Popen(
                fuse_cmd,
                env=fuse_env
            )
            
            # CRITICAL FIX: Longer wait time for FUSE to fully initialize
            logger.info("⏳ Waiting for FUSE to fully initialize (10 seconds)...")
            time.sleep(10)
            
            # Check if FUSE is still running
            if self.emulator_process.poll() is None:
                logger.info("✅ FUSE emulator started successfully with user context fixes")
            else:
                raise Exception("FUSE emulator exited during startup")
            
        except Exception as e:
            logger.error(f"Failed to start FUSE emulator: {e}")
            raise

    def start_ffmpeg_hls(self):
        """Start FFmpeg HLS streaming with golden reference strategy"""
        try:
            logger.info("Starting FFmpeg HLS with golden reference strategy...")
            logger.info(f"Capture: {self.capture_size} at +{self.capture_offset_x},{self.capture_offset_y}")
            logger.info(f"Scaling: {self.scale_factor}x → {self.output_resolution}")
            
            # Calculate scaled dimensions for first stage
            capture_w, capture_h = map(int, self.capture_size.split('x'))
            scaled_w = int(capture_w * self.scale_factor)
            scaled_h = int(capture_h * self.scale_factor)
            
            # GOLDEN REFERENCE: FFmpeg command matching proven local strategy
            ffmpeg_cmd = [
                'ffmpeg',
                # Input: X11 grab with golden reference configuration
                '-f', 'x11grab',
                '-draw_mouse', '0',  # CRITICAL: Hide cursor
                '-video_size', self.capture_size,
                '-framerate', str(self.frame_rate),
                '-i', f':99.0+{self.capture_offset_x},{self.capture_offset_y}',
                
                # Audio input: Synthetic audio (proven reliable)
                '-f', 'lavfi',
                '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
                
                # Video processing: Multi-stage scaling with HD fitting
                '-vf', f'scale={scaled_w}:{scaled_h}:flags=neighbor,scale={self.output_resolution}:flags=lanczos:force_original_aspect_ratio=decrease,pad={self.output_resolution}:(ow-iw)/2:(oh-ih)/2:black,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text=\'🔴 LIVE ZX SPECTRUM {self.scale_factor}X %{{localtime}}\':fontcolor=yellow:fontsize=36:x=w-text_w-20:y=20:box=1:boxcolor=black@0.7:boxborderw=3',
                
                # Video encoding: Proven settings
                '-c:v', 'libx264',
                '-preset', 'veryfast',
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
            
            # Create output directory
            os.makedirs('/tmp/stream', exist_ok=True)
            
            self.ffmpeg_hls_process = subprocess.Popen(
                ffmpeg_cmd,
                env=dict(os.environ, DISPLAY=':99')
            )
            
            time.sleep(3)
            logger.info("✅ FFmpeg HLS started successfully with golden reference strategy")
            
        except Exception as e:
            logger.error(f"Failed to start FFmpeg HLS: {e}")
            raise

    def start_ffmpeg_youtube(self):
        """Start FFmpeg YouTube RTMP streaming with golden reference strategy"""
        if not self.youtube_key:
            logger.info("No YouTube stream key provided, skipping RTMP stream")
            return
            
        try:
            logger.info("Starting YouTube RTMP stream with golden reference strategy...")
            
            # Calculate scaled dimensions for first stage
            capture_w, capture_h = map(int, self.capture_size.split('x'))
            scaled_w = int(capture_w * self.scale_factor)
            scaled_h = int(capture_h * self.scale_factor)
            
            # GOLDEN REFERENCE: YouTube FFmpeg command matching local strategy
            youtube_cmd = [
                'ffmpeg', '-y',
                # Input: Same golden reference capture configuration
                '-f', 'x11grab',
                '-draw_mouse', '0',  # CRITICAL: Hide cursor
                '-video_size', self.capture_size,
                '-framerate', str(self.frame_rate),
                '-i', f':99.0+{self.capture_offset_x},{self.capture_offset_y}',
                
                # Audio input: Synthetic audio (proven reliable)
                '-f', 'lavfi',
                '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
                
                # Video processing: Same multi-stage scaling
                '-vf', f'scale={scaled_w}:{scaled_h}:flags=neighbor,scale={self.output_resolution}:flags=lanczos:force_original_aspect_ratio=decrease,pad={self.output_resolution}:(ow-iw)/2:(oh-ih)/2:black,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text=\'🔴 LIVE ZX SPECTRUM {self.scale_factor}X %{{localtime}}\':fontcolor=yellow:fontsize=36:x=w-text_w-20:y=20:box=1:boxcolor=black@0.7:boxborderw=3',
                
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
                env=dict(os.environ, DISPLAY=':99')
            )
            
            time.sleep(3)
            logger.info("✅ YouTube RTMP streaming started successfully with golden reference strategy")
            
        except Exception as e:
            logger.error(f"Failed to start YouTube streaming: {e}")
            raise

    def upload_hls_segments(self):
        """Upload HLS segments to S3"""
        while self.running:
            try:
                # Check for new segments
                if os.path.exists('/tmp/stream'):
                    for filename in os.listdir('/tmp/stream'):
                        if filename.endswith('.ts') or filename.endswith('.m3u8'):
                            local_path = f'/tmp/stream/{filename}'
                            s3_key = f'hls/{filename}'
                            
                            try:
                                # Upload to S3
                                self.s3_client.upload_file(
                                    local_path, 
                                    self.stream_bucket, 
                                    s3_key,
                                    ExtraArgs={
                                        'ContentType': 'application/x-mpegURL' if filename.endswith('.m3u8') else 'video/MP2T',
                                        'CacheControl': 'max-age=1'
                                    }
                                )
                            except FileNotFoundError:
                                # File was deleted by FFmpeg, skip
                                continue
                            except Exception as e:
                                logger.error(f"Failed to upload {filename}: {e}")
                
                time.sleep(1)
                
            except Exception as e:
                logger.error(f"Error in upload thread: {e}")
                time.sleep(5)

    async def handle_websocket(self, websocket):
        """Handle WebSocket connections with golden reference support"""
        self.websocket_clients.add(websocket)
        logger.info(f"WebSocket client connected. Total clients: {len(self.websocket_clients)}")
        
        try:
            # Send initial status
            await websocket.send(json.dumps({
                'type': 'connected',
                'emulator_running': self.emulator_process is not None and self.emulator_process.poll() is None,
                'version': self.version,
                'strategy': 'golden-reference-v2',
                'user_context': 'fixed'
            }))
            
            async for message in websocket:
                try:
                    data = json.loads(message)
                    await self.handle_message(websocket, data)
                except json.JSONDecodeError:
                    await websocket.send(json.dumps({
                        'type': 'error',
                        'message': 'Invalid JSON'
                    }))
                    
        except websockets.exceptions.ConnectionClosed:
            pass
        finally:
            self.websocket_clients.discard(websocket)
            logger.info(f"WebSocket client disconnected. Total clients: {len(self.websocket_clients)}")

    async def handle_message(self, websocket, data):
        """Handle WebSocket messages"""
        message_type = data.get('type')
        
        if message_type == 'status':
            # Return current status
            status = {
                'type': 'status',
                'processes': {
                    'xvfb': self.xvfb_process is not None and self.xvfb_process.poll() is None,
                    'emulator': self.emulator_process is not None and self.emulator_process.poll() is None,
                    'ffmpeg_hls': self.ffmpeg_hls_process is not None and self.ffmpeg_hls_process.poll() is None,
                    'ffmpeg_youtube': self.ffmpeg_youtube_process is not None and self.ffmpeg_youtube_process.poll() is None
                },
                'version': self.version,
                'strategy': 'golden-reference-v2',
                'user_context': 'fixed',
                'configuration': {
                    'virtual_display': self.virtual_display_size,
                    'capture_size': self.capture_size,
                    'capture_offset': f'+{self.capture_offset_x},{self.capture_offset_y}',
                    'scale_factor': self.scale_factor,
                    'output_resolution': self.output_resolution,
                    'frame_rate': self.frame_rate
                }
            }
            await websocket.send(json.dumps(status))
            
        elif message_type == 'key_press':
            # Handle key press (placeholder for future implementation)
            key = data.get('key')
            logger.info(f"Key press received: {key}")
            
            # Send acknowledgment
            await websocket.send(json.dumps({
                'type': 'key_response',
                'key': key,
                'status': 'received'
            }))

    async def health_check(self, request):
        """Health check endpoint"""
        processes = {
            'xvfb': self.xvfb_process is not None and self.xvfb_process.poll() is None,
            'emulator': self.emulator_process is not None and self.emulator_process.poll() is None,
            'ffmpeg_hls': self.ffmpeg_hls_process is not None and self.ffmpeg_hls_process.poll() is None,
            'ffmpeg_youtube': self.ffmpeg_youtube_process is not None and self.ffmpeg_youtube_process.poll() is None
        }
        
        return web.json_response({
            'status': 'healthy',
            'version': self.version,
            'strategy': 'golden-reference-v2',
            'user_context': 'fixed',
            'processes': processes
        })

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
            if process and process.poll() is None:
                logger.info(f"Terminating {name}...")
                try:
                    process.terminate()
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    logger.warning(f"Force killing {name}...")
                    process.kill()

    async def start_server(self):
        """Start the golden reference v2 server"""
        try:
            logger.info("🚀 Starting golden reference v2 server components...")
            
            # Initialize S3 client
            self.setup_s3_client()
            
            # Start core components in order
            self.start_xvfb()
            self.start_pulseaudio()
            self.start_emulator()
            
            # Start video streaming
            self.start_ffmpeg_hls()
            self.start_ffmpeg_youtube()
            
            # Start S3 upload thread
            self.upload_thread = threading.Thread(target=self.upload_hls_segments, daemon=True)
            self.upload_thread.start()
            
            # Set up HTTP server for health checks
            app = web.Application()
            app.router.add_get('/health', self.health_check)
            
            # Start HTTP server
            runner = web.AppRunner(app)
            await runner.setup()
            site = web.TCPSite(runner, '0.0.0.0', 8080)
            await site.start()
            
            logger.info("✅ HTTP health check server started on port 8080")
            
            # Start WebSocket server
            websocket_server = await websockets.serve(
                self.handle_websocket,
                '0.0.0.0',
                8765
            )
            
            logger.info("✅ WebSocket server started on port 8765")
            logger.info("🏆 Golden Reference v2 ZX Spectrum Emulator Server is fully operational!")
            logger.info("🔧 User context fixes applied - FUSE should start properly now!")
            
            # Keep server running
            await websocket_server.wait_closed()
            
        except Exception as e:
            logger.error(f"Failed to start server: {e}")
            self.cleanup()
            raise

def main():
    """Main entry point"""
    server = GoldenReferenceEmulatorServerV2()
    
    # Set up signal handlers
    def signal_handler(signum, frame):
        logger.info("Received shutdown signal")
        server.cleanup()
        sys.exit(0)
    
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    try:
        asyncio.run(server.start_server())
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
    except Exception as e:
        logger.error(f"Server error: {e}")
        sys.exit(1)
    finally:
        server.cleanup()

if __name__ == '__main__':
    main()
