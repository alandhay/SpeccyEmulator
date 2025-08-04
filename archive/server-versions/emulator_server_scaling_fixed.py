#!/usr/bin/env python3

import asyncio
import websockets
import json
import logging
import subprocess
import threading
import time
import os
import signal
import boto3
from aiohttp import web
from pathlib import Path
from aiohttp.web import FileResponse

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SpectrumEmulator:
    def __init__(self):
        self.connected_clients = set()
        self.emulator_process = None
        self.web_stream_process = None
        self.youtube_stream_process = None
        self.s3_upload_process = None
        self.stream_dir = Path('/tmp/stream')
        self.stream_dir.mkdir(exist_ok=True)
        
        # Get configuration from environment
        self.capture_size = os.getenv('CAPTURE_SIZE', '256x192')
        self.capture_offset = os.getenv('CAPTURE_OFFSET', '0,0')
        self.display_size = os.getenv('DISPLAY_SIZE', '512x384')
        self.stream_bucket = os.getenv('STREAM_BUCKET', 'spectrum-emulator-stream-dev-043309319786')
        self.youtube_key = os.getenv('YOUTUBE_STREAM_KEY', '')
        
        # Enhanced streaming configuration
        self.output_resolution = '1280x720'  # HD output for better quality
        self.emulator_native_size = '256x192'  # ZX Spectrum native resolution
        
        # Initialize S3 client
        try:
            self.s3_client = boto3.client('s3')
            logger.info(f'S3 client initialized for bucket: {self.stream_bucket}')
        except Exception as e:
            logger.error(f'Failed to initialize S3 client: {e}')
            self.s3_client = None
        
        logger.info(f'Emulator config: display={self.display_size}, output={self.output_resolution}')

    def test_sdl_environment(self):
        """Test if SDL2 environment is properly configured"""
        try:
            logger.info('Testing SDL2 environment...')
            
            # Check environment variables
            display = os.getenv('DISPLAY')
            sdl_video = os.getenv('SDL_VIDEODRIVER')
            sdl_audio = os.getenv('SDL_AUDIODRIVER')
            
            logger.info(f'Environment: DISPLAY={display}, SDL_VIDEODRIVER={sdl_video}, SDL_AUDIODRIVER={sdl_audio}')
            
            # Test X11 connection
            result = subprocess.run(['xdpyinfo'], env={'DISPLAY': display}, 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                logger.info('X11 display test: SUCCESS')
            else:
                logger.warning(f'X11 display test failed: {result.stderr}')
                return False
            
            # Test FUSE availability
            result = subprocess.run(['which', 'fuse-sdl'], capture_output=True, text=True)
            if result.returncode == 0:
                logger.info(f'FUSE emulator found at: {result.stdout.strip()}')
            else:
                logger.error('FUSE emulator not found')
                return False
            
            return True
            
        except Exception as e:
            logger.error(f'SDL environment test failed: {e}')
            return False

    def start_emulator(self):
        try:
            if self.emulator_process:
                logger.info('Emulator already running')
                return True

            # Test SDL environment first
            if not self.test_sdl_environment():
                logger.error('SDL environment test failed, cannot start emulator')
                # Start streaming anyway with test pattern
                self.start_web_stream_with_test_pattern()
                self.start_youtube_stream()
                self.start_s3_upload()
                return False

            logger.info('Starting FUSE ZX Spectrum emulator with improved SDL configuration')
            
            # Enhanced environment for FUSE
            fuse_env = os.environ.copy()
            fuse_env.update({
                'DISPLAY': ':99',
                'SDL_VIDEODRIVER': 'x11',
                'SDL_AUDIODRIVER': 'pulse',
                'XAUTHORITY': '/tmp/.Xauth'
            })
            
            # Start FUSE with better error handling and proper window size
            self.emulator_process = subprocess.Popen([
                'fuse-sdl', 
                '--machine', '48', 
                '--graphics-filter', 'none', 
                '--sound', 
                '--no-confirm-actions',
                '--full-screen'  # This should make it use the full display
            ], env=fuse_env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            # Wait a bit and check if FUSE started successfully
            time.sleep(5)  # Give FUSE more time to initialize
            
            if self.emulator_process.poll() is not None:
                # Process has already terminated
                stdout, stderr = self.emulator_process.communicate()
                logger.error(f'FUSE emulator failed to start:')
                logger.error(f'STDOUT: {stdout.decode()}')
                logger.error(f'STDERR: {stderr.decode()}')
                self.emulator_process = None
                
                # Start streaming with test pattern instead
                logger.info('Starting streaming with test pattern due to FUSE failure')
                self.start_web_stream_with_test_pattern()
                self.start_youtube_stream()
                self.start_s3_upload()
                return False
            else:
                logger.info('FUSE emulator started successfully')
                time.sleep(3)  # Give it more time to initialize display
                
                # Start streaming with proper scaling
                self.start_web_stream_scaled()
                self.start_youtube_stream()
                self.start_s3_upload()
                logger.info('ZX Spectrum emulator started successfully with scaled streaming outputs')
                return True
            
        except Exception as e:
            logger.error(f'Failed to start emulator: {e}')
            self.stop_emulator()
            # Fallback to test pattern streaming
            self.start_web_stream_with_test_pattern()
            self.start_youtube_stream()
            self.start_s3_upload()
            return False

    def start_web_stream_scaled(self):
        """Start streaming with proper scaling from full display"""
        try:
            logger.info(f'Starting scaled web HLS stream: {self.display_size} -> {self.output_resolution}')
            stream_file = self.stream_dir / 'stream.m3u8'
            
            # Capture the full virtual display and scale it up with proper filtering
            self.web_stream_process = subprocess.Popen([
                'ffmpeg', '-y',
                '-f', 'x11grab',
                '-video_size', self.display_size,  # Capture full display (512x384)
                '-framerate', '25',
                '-i', ':99.0+0,0',  # Capture from top-left of full display
                '-f', 'pulse',
                '-i', 'default',
                # Video processing with scaling
                '-vf', f'scale={self.output_resolution}:flags=neighbor',  # Pixel-perfect scaling for retro look
                '-c:v', 'libx264',
                '-preset', 'fast',  # Better quality than ultrafast
                '-tune', 'zerolatency',
                '-g', '50',
                '-keyint_min', '25',
                '-sc_threshold', '0',
                '-b:v', '2000k',  # Higher bitrate for better quality
                '-maxrate', '2500k',
                '-bufsize', '5000k',
                '-pix_fmt', 'yuv420p',  # Ensure compatibility
                # Audio
                '-c:a', 'aac',
                '-b:a', '128k',
                '-ar', '44100',
                # HLS output
                '-f', 'hls',
                '-hls_time', '2',
                '-hls_list_size', '5',
                '-hls_flags', 'delete_segments',
                str(stream_file)
            ])
            logger.info(f'Scaled web HLS streaming started: {self.display_size} -> {self.output_resolution}')
            
        except Exception as e:
            logger.error(f'Failed to start scaled web stream: {e}')

    def start_web_stream_with_test_pattern(self):
        """Start streaming with a test pattern instead of emulator capture"""
        try:
            logger.info(f'Starting web HLS stream with scaled test pattern: {self.output_resolution}')
            stream_file = self.stream_dir / 'stream.m3u8'
            
            # Create test pattern with ZX Spectrum aspect ratio, scaled to HD
            self.web_stream_process = subprocess.Popen([
                'ffmpeg', '-y',
                '-f', 'lavfi',
                '-i', f'testsrc2=size={self.output_resolution}:rate=25:duration=0',
                '-f', 'lavfi', 
                '-i', 'sine=frequency=1000:duration=0',
                '-c:v', 'libx264',
                '-preset', 'fast',
                '-tune', 'zerolatency',
                '-g', '50',
                '-keyint_min', '25',
                '-sc_threshold', '0',
                '-b:v', '2000k',
                '-maxrate', '2500k',
                '-bufsize', '5000k',
                '-c:a', 'aac',
                '-b:a', '128k',
                '-ar', '44100',
                '-f', 'hls',
                '-hls_time', '2',
                '-hls_list_size', '5',
                '-hls_flags', 'delete_segments',
                str(stream_file)
            ])
            logger.info(f'Scaled test pattern streaming started at {self.output_resolution}')
            
        except Exception as e:
            logger.error(f'Failed to start web stream with test pattern: {e}')

    def start_youtube_stream(self):
        if not self.youtube_key:
            logger.info('No YouTube stream key provided, skipping YouTube streaming')
            return
            
        try:
            logger.info(f'Starting YouTube RTMP stream at {self.output_resolution}')
            
            # Use test pattern if emulator failed, otherwise use X11 capture
            if self.emulator_process is None:
                # Test pattern for YouTube
                input_args = [
                    '-f', 'lavfi',
                    '-i', f'testsrc2=size={self.output_resolution}:rate=25:duration=0',
                    '-f', 'lavfi', 
                    '-i', 'sine=frequency=1000:duration=0'
                ]
            else:
                # Scaled X11 capture for YouTube
                input_args = [
                    '-f', 'x11grab',
                    '-video_size', self.display_size,
                    '-framerate', '25',
                    '-i', ':99.0+0,0',
                    '-f', 'pulse',
                    '-i', 'default'
                ]
            
            # Build FFmpeg command with scaling
            ffmpeg_cmd = ['ffmpeg', '-y'] + input_args
            
            # Add scaling if capturing from X11
            if self.emulator_process is not None:
                ffmpeg_cmd.extend([
                    '-vf', f'scale={self.output_resolution}:flags=neighbor'
                ])
            
            # Add encoding settings
            ffmpeg_cmd.extend([
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
                f'rtmp://a.rtmp.youtube.com/live2/{self.youtube_key}'
            ])
            
            self.youtube_stream_process = subprocess.Popen(ffmpeg_cmd)
            logger.info(f'YouTube RTMP streaming started at {self.output_resolution}')
            
        except Exception as e:
            logger.error(f'Failed to start YouTube stream: {e}')

    def start_s3_upload(self):
        if not self.s3_client:
            logger.warning('S3 client not available, skipping S3 upload')
            return
            
        try:
            logger.info('Starting S3 upload process for HLS segments')
            
            def upload_worker():
                while True:
                    try:
                        # Upload HLS playlist
                        playlist_file = self.stream_dir / 'stream.m3u8'
                        if playlist_file.exists():
                            self.s3_client.upload_file(
                                str(playlist_file),
                                self.stream_bucket,
                                'hls/stream.m3u8',
                                ExtraArgs={'ContentType': 'application/vnd.apple.mpegurl', 'CacheControl': 'no-cache'}
                            )
                        
                        # Upload segment files
                        for segment_file in self.stream_dir.glob('*.ts'):
                            try:
                                self.s3_client.upload_file(
                                    str(segment_file),
                                    self.stream_bucket,
                                    f'hls/{segment_file.name}',
                                    ExtraArgs={'ContentType': 'video/mp2t', 'CacheControl': 'max-age=10'}
                                )
                            except Exception as e:
                                # Ignore individual segment upload errors
                                pass
                        
                        time.sleep(1)
                        
                    except Exception as e:
                        logger.error(f'S3 upload error: {e}')
                        time.sleep(5)
            
            upload_thread = threading.Thread(target=upload_worker, daemon=True)
            upload_thread.start()
            logger.info('S3 upload worker started')
            
        except Exception as e:
            logger.error(f'Failed to start S3 upload: {e}')

    def stop_emulator(self):
        try:
            processes = [
                ('emulator', self.emulator_process),
                ('web_stream', self.web_stream_process),
                ('youtube_stream', self.youtube_stream_process),
                ('s3_upload', self.s3_upload_process)
            ]
            
            for name, process in processes:
                if process:
                    try:
                        process.terminate()
                        process.wait(timeout=5)
                        logger.info(f'{name} process stopped')
                    except subprocess.TimeoutExpired:
                        process.kill()
                        logger.info(f'{name} process killed')
                    except Exception as e:
                        logger.error(f'Error stopping {name}: {e}')
            
            self.emulator_process = None
            self.web_stream_process = None
            self.youtube_stream_process = None
            self.s3_upload_process = None
            
        except Exception as e:
            logger.error(f'Error stopping emulator: {e}')

    async def handle_websocket(self, websocket, path):
        self.connected_clients.add(websocket)
        logger.info('New WebSocket client connected')
        
        try:
            # Send initial status
            await websocket.send(json.dumps({
                'type': 'connected',
                'emulator_running': self.emulator_process is not None,
                'output_resolution': self.output_resolution
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
                            'message': 'Emulator started successfully' if success else 'Emulator failed to start, using test pattern',
                            'output_resolution': self.output_resolution
                        }))
                    
                    elif data.get('type') == 'stop_emulator':
                        self.stop_emulator()
                        await websocket.send(json.dumps({
                            'type': 'emulator_status',
                            'running': False,
                            'message': 'Emulator stopped'
                        }))
                    
                    elif data.get('type') == 'status':
                        await websocket.send(json.dumps({
                            'type': 'emulator_status',
                            'running': self.emulator_process is not None,
                            'message': 'Status check',
                            'output_resolution': self.output_resolution
                        }))
                    
                    elif data.get('type') == 'key_press':
                        # Handle key press (to be implemented)
                        key = data.get('key')
                        logger.info(f'Key press: {key}')
                        
                except json.JSONDecodeError:
                    logger.error(f'Invalid JSON received: {message}')
                except Exception as e:
                    logger.error(f'Error handling message: {e}')
                    
        except websockets.exceptions.ConnectionClosed:
            logger.info('WebSocket client disconnected')
        finally:
            self.connected_clients.discard(websocket)

    async def health_check(self, request):
        return web.Response(text=f'OK - Emulator server running at {self.output_resolution}', status=200)

    async def start_streaming(self, request):
        success = self.start_emulator()
        return web.json_response({
            'success': success,
            'message': 'Streaming started' if success else 'Streaming started with test pattern',
            'output_resolution': self.output_resolution
        })

    def run(self):
        # Auto-start emulator
        logger.info('Auto-starting emulator with scaling...')
        success = self.start_emulator()
        if success:
            logger.info(f'Emulator auto-started successfully at {self.output_resolution}')
        else:
            logger.info(f'Emulator auto-start failed, using test pattern at {self.output_resolution}')
        
        # Start HTTP server for health checks
        app = web.Application()
        app.router.add_get('/health', self.health_check)
        app.router.add_post('/start_streaming', self.start_streaming)
        
        async def init_app():
            runner = web.AppRunner(app)
            await runner.setup()
            site = web.TCPSite(runner, '0.0.0.0', 8080)
            await site.start()
            logger.info('HTTP server started on port 8080')
        
        # Start WebSocket server
        async def start_servers():
            await init_app()
            await websockets.serve(self.handle_websocket, '0.0.0.0', 8765)
            logger.info(f'WebSocket server started on port 8765 - ZX Spectrum Emulator ready with {self.output_resolution} scaling!')
        
        # Run the event loop
        loop = asyncio.get_event_loop()
        loop.run_until_complete(start_servers())
        loop.run_forever()

if __name__ == '__main__':
    emulator = SpectrumEmulator()
    emulator.run()
