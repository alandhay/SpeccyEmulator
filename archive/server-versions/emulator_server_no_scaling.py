#!/usr/bin/env python3
"""
ZX Spectrum Emulator Server - No Scaling Version
================================================

This version removes all scaling and shows the native ZX Spectrum resolution
(320x240) centered in the HD frame without any upscaling.

CONFIGURATION:
- Native capture: 320x240
- No scaling applied
- Direct centering in 1280x720 frame
- Cursor hidden
- Synthetic audio
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

class NoScalingEmulatorServer:
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
        self.version = os.getenv('VERSION', '1.0.0-no-scaling')
        self.build_time = os.getenv('BUILD_TIME', '2025-08-04T01:30:00Z')
        
        # NO SCALING: Native resolution configuration
        self.virtual_display_size = os.getenv('VIRTUAL_DISPLAY_SIZE', '800x600x24')
        self.capture_size = os.getenv('CAPTURE_SIZE', '320x240')
        self.capture_offset_x = int(os.getenv('CAPTURE_OFFSET_X', '240'))
        self.capture_offset_y = int(os.getenv('CAPTURE_OFFSET_Y', '180'))
        self.output_resolution = os.getenv('OUTPUT_RESOLUTION', '1280x720')
        self.frame_rate = int(os.getenv('FRAME_RATE', '30'))
        
        logger.info("🎮 Starting No Scaling ZX Spectrum Emulator Server")
        logger.info(f"Version: {self.version}")
        logger.info(f"Strategy: Native resolution, no scaling, centered in HD")
        logger.info("")
        logger.info("🎯 No Scaling Configuration:")
        logger.info(f"  Virtual Display: {self.virtual_display_size}")
        logger.info(f"  Capture Size: {self.capture_size} (NATIVE)")
        logger.info(f"  Capture Offset: +{self.capture_offset_x},{self.capture_offset_y}")
        logger.info(f"  Output Resolution: {self.output_resolution}")
        logger.info(f"  Frame Rate: {self.frame_rate} FPS")
        logger.info(f"  Scaling: NONE - Native 320x240")

    def setup_s3_client(self):
        """Initialize S3 client for HLS uploads"""
        try:
            self.s3_client = boto3.client('s3')
            logger.info("S3 client initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize S3 client: {e}")
            raise

    def start_xvfb(self):
        """Start virtual framebuffer"""
        try:
            logger.info("Starting Xvfb virtual framebuffer...")
            
            self.xvfb_process = subprocess.Popen([
                'Xvfb', ':99', 
                '-screen', '0', self.virtual_display_size,
                '-ac', '+extension', 'GLX'
            ])
            
            time.sleep(3)
            
            result = subprocess.run(['xdpyinfo', '-display', ':99'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                logger.info("✅ Xvfb started successfully on display :99")
            else:
                raise Exception("Xvfb failed to start properly")
                
        except Exception as e:
            logger.error(f"Failed to start Xvfb: {e}")
            raise

    def start_pulseaudio(self):
        """Start PulseAudio server"""
        try:
            logger.info("Starting PulseAudio server...")
            
            os.makedirs('/tmp/pulse', exist_ok=True)
            
            self.pulseaudio_process = subprocess.Popen([
                'pulseaudio', '--system=false', '--exit-idle-time=-1',
                '--daemonize=false'
            ])
            
            time.sleep(2)
            logger.info("✅ PulseAudio started successfully")
            
        except Exception as e:
            logger.error(f"Failed to start PulseAudio: {e}")
            logger.warning("Continuing without PulseAudio...")

    def start_emulator(self):
        """Start FUSE emulator"""
        try:
            logger.info("Starting FUSE emulator...")
            
            fuse_config_dir = os.path.join(os.getenv('HOME', '/tmp'), '.fuse')
            os.makedirs(fuse_config_dir, exist_ok=True)
            
            fuse_cmd = [
                'fuse-sdl',
                '--machine', '48',
                '--no-sound'
            ]
            
            fuse_env = dict(os.environ)
            fuse_env.update({
                'DISPLAY': ':99',
                'SDL_VIDEODRIVER': 'x11',
                'SDL_AUDIODRIVER': 'dummy',
                'SDL_JOYSTICK': '0',
                'SDL_HAPTIC': '0',
                'HOME': os.getenv('HOME', '/tmp')
            })
            
            self.emulator_process = subprocess.Popen(
                fuse_cmd,
                env=fuse_env
            )
            
            time.sleep(10)
            
            if self.emulator_process.poll() is None:
                logger.info("✅ FUSE emulator started successfully")
            else:
                raise Exception("FUSE emulator exited during startup")
            
        except Exception as e:
            logger.error(f"Failed to start FUSE emulator: {e}")
            raise

    def start_ffmpeg_hls(self):
        """Start FFmpeg HLS streaming with NO SCALING"""
        try:
            logger.info("Starting FFmpeg HLS with NO SCALING...")
            logger.info(f"Native capture: {self.capture_size} → centered in {self.output_resolution}")
            
            # NO SCALING: Direct capture to HD frame with centering only
            ffmpeg_cmd = [
                'ffmpeg',
                # Input: X11 grab
                '-f', 'x11grab',
                '-draw_mouse', '0',  # Hide cursor
                '-video_size', self.capture_size,
                '-framerate', str(self.frame_rate),
                '-i', f':99.0+{self.capture_offset_x},{self.capture_offset_y}',
                
                # Audio input: Synthetic audio
                '-f', 'lavfi',
                '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
                
                # NO SCALING: Just center the native resolution in HD frame
                '-vf', f'scale={self.output_resolution}:flags=lanczos:force_original_aspect_ratio=decrease,pad={self.output_resolution}:(ow-iw)/2:(oh-ih)/2:black,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text=\'🔴 LIVE ZX SPECTRUM NATIVE %{{localtime}}\':fontcolor=yellow:fontsize=24:x=w-text_w-20:y=20:box=1:boxcolor=black@0.7:boxborderw=3',
                
                # Video encoding
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
            
            logger.info(f"NO SCALING FFmpeg HLS command: {' '.join(ffmpeg_cmd)}")
            
            os.makedirs('/tmp/stream', exist_ok=True)
            
            self.ffmpeg_hls_process = subprocess.Popen(
                ffmpeg_cmd,
                env=dict(os.environ, DISPLAY=':99')
            )
            
            time.sleep(3)
            logger.info("✅ FFmpeg HLS started successfully with NO SCALING")
            
        except Exception as e:
            logger.error(f"Failed to start FFmpeg HLS: {e}")
            raise

    def start_ffmpeg_youtube(self):
        """Start FFmpeg YouTube RTMP streaming with NO SCALING"""
        if not self.youtube_key:
            logger.info("No YouTube stream key provided, skipping RTMP stream")
            return
            
        try:
            logger.info("Starting YouTube RTMP stream with NO SCALING...")
            
            # NO SCALING: YouTube command with native resolution
            youtube_cmd = [
                'ffmpeg', '-y',
                # Input: Same capture configuration
                '-f', 'x11grab',
                '-draw_mouse', '0',
                '-video_size', self.capture_size,
                '-framerate', str(self.frame_rate),
                '-i', f':99.0+{self.capture_offset_x},{self.capture_offset_y}',
                
                # Audio input: Synthetic audio
                '-f', 'lavfi',
                '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
                
                # NO SCALING: Just center in HD frame
                '-vf', f'scale={self.output_resolution}:flags=lanczos:force_original_aspect_ratio=decrease,pad={self.output_resolution}:(ow-iw)/2:(oh-ih)/2:black,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text=\'🔴 LIVE ZX SPECTRUM NATIVE %{{localtime}}\':fontcolor=yellow:fontsize=24:x=w-text_w-20:y=20:box=1:boxcolor=black@0.7:boxborderw=3',
                
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
            
            logger.info(f"NO SCALING YouTube FFmpeg command: {' '.join(youtube_cmd)}")
            
            self.ffmpeg_youtube_process = subprocess.Popen(
                youtube_cmd,
                env=dict(os.environ, DISPLAY=':99')
            )
            
            time.sleep(3)
            logger.info("✅ YouTube RTMP streaming started successfully with NO SCALING")
            
        except Exception as e:
            logger.error(f"Failed to start YouTube streaming: {e}")
            raise

    def upload_hls_segments(self):
        """Upload HLS segments to S3"""
        while self.running:
            try:
                if os.path.exists('/tmp/stream'):
                    for filename in os.listdir('/tmp/stream'):
                        if filename.endswith('.ts') or filename.endswith('.m3u8'):
                            local_path = f'/tmp/stream/{filename}'
                            s3_key = f'hls/{filename}'
                            
                            try:
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
                                continue
                            except Exception as e:
                                logger.error(f"Failed to upload {filename}: {e}")
                
                time.sleep(1)
                
            except Exception as e:
                logger.error(f"Error in upload thread: {e}")
                time.sleep(5)

    async def handle_websocket(self, websocket):
        """Handle WebSocket connections"""
        self.websocket_clients.add(websocket)
        logger.info(f"WebSocket client connected. Total clients: {len(self.websocket_clients)}")
        
        try:
            await websocket.send(json.dumps({
                'type': 'connected',
                'emulator_running': self.emulator_process is not None and self.emulator_process.poll() is None,
                'version': self.version,
                'strategy': 'no-scaling',
                'resolution': 'native-320x240'
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
            status = {
                'type': 'status',
                'processes': {
                    'xvfb': self.xvfb_process is not None and self.xvfb_process.poll() is None,
                    'emulator': self.emulator_process is not None and self.emulator_process.poll() is None,
                    'ffmpeg_hls': self.ffmpeg_hls_process is not None and self.ffmpeg_hls_process.poll() is None,
                    'ffmpeg_youtube': self.ffmpeg_youtube_process is not None and self.ffmpeg_youtube_process.poll() is None
                },
                'version': self.version,
                'strategy': 'no-scaling',
                'resolution': 'native-320x240'
            }
            await websocket.send(json.dumps(status))

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
            'strategy': 'no-scaling',
            'resolution': 'native-320x240',
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
        """Start the no scaling server"""
        try:
            logger.info("🚀 Starting no scaling server components...")
            
            self.setup_s3_client()
            self.start_xvfb()
            self.start_pulseaudio()
            self.start_emulator()
            self.start_ffmpeg_hls()
            self.start_ffmpeg_youtube()
            
            self.upload_thread = threading.Thread(target=self.upload_hls_segments, daemon=True)
            self.upload_thread.start()
            
            # Set up HTTP server for health checks
            app = web.Application()
            app.router.add_get('/health', self.health_check)
            
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
            logger.info("🎮 No Scaling ZX Spectrum Emulator Server is fully operational!")
            logger.info("📺 Native 320x240 resolution, centered in HD frame")
            
            await websocket_server.wait_closed()
            
        except Exception as e:
            logger.error(f"Failed to start server: {e}")
            self.cleanup()
            raise

def main():
    """Main entry point"""
    server = NoScalingEmulatorServer()
    
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
