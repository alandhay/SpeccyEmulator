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
        self.display_size = os.getenv('DISPLAY_SIZE', '1920x1080')  # Full HD virtual display
        self.stream_bucket = os.getenv('STREAM_BUCKET', 'spectrum-emulator-stream-dev-043309319786')
        self.youtube_key = os.getenv('YOUTUBE_STREAM_KEY', '')
        
        # HIGH QUALITY 1080p streaming configuration
        self.output_resolution = '1920x1080'  # Full HD output
        self.framerate = '60'  # Smooth 60 FPS
        self.video_bitrate = '6000k'  # High quality bitrate
        self.max_bitrate = '6500k'
        self.buffer_size = '12000k'
        self.audio_bitrate = '192k'  # High-fidelity audio
        self.audio_sample_rate = '48000'  # Professional audio
        self.emulator_native_size = '256x192'  # ZX Spectrum native resolution
        
        # Initialize S3 client
        try:
            self.s3_client = boto3.client('s3')
            logger.info(f'S3 client initialized for bucket: {self.stream_bucket}')
        except Exception as e:
            logger.error(f'Failed to initialize S3 client: {e}')
            self.s3_client = None
        
        logger.info(f'HIGH QUALITY CONFIG: display={self.display_size}, output={self.output_resolution}, fps={self.framerate}')

    async def handle_websocket(self, websocket, path):
        logger.info(f'WebSocket connection from {websocket.remote_address}')
        self.connected_clients.add(websocket)
        
        try:
            await websocket.send(json.dumps({
                'type': 'connected',
                'emulator_running': self.emulator_process is not None,
                'streaming_quality': 'HIGH_QUALITY_1080p60',
                'resolution': self.output_resolution,
                'framerate': self.framerate
            }))
            
            async for message in websocket:
                try:
                    data = json.loads(message)
                    await self.handle_message(data, websocket)
                except json.JSONDecodeError:
                    logger.error(f'Invalid JSON received: {message}')
                    
        except websockets.exceptions.ConnectionClosed:
            logger.info('WebSocket connection closed')
        finally:
            self.connected_clients.discard(websocket)

    async def handle_message(self, data, websocket):
        message_type = data.get('type')
        
        if message_type == 'start_emulator':
            await self.start_emulator()
            await websocket.send(json.dumps({
                'type': 'emulator_status',
                'running': True,
                'message': 'High-quality 1080p60 emulator started',
                'quality': 'FULL_HD'
            }))
            
        elif message_type == 'key_press':
            key = data.get('key')
            if key and self.emulator_process:
                logger.info(f'Key press: {key}')
                
        elif message_type == 'status':
            await websocket.send(json.dumps({
                'type': 'status',
                'emulator_running': self.emulator_process is not None,
                'streaming_quality': 'HIGH_QUALITY_1080p60',
                'resolution': self.output_resolution,
                'framerate': self.framerate,
                'bitrate': self.video_bitrate
            }))

    async def start_emulator(self):
        if self.emulator_process is not None:
            logger.info('Emulator already running')
            return
            
        try:
            logger.info('Starting ZX Spectrum emulator with 1080p display...')
            
            # Start virtual display at 1920x1080 for high quality
            subprocess.run(['Xvfb', ':99', '-screen', '0', f'{self.display_size}x24', '-ac'], 
                         check=False, timeout=5)
            time.sleep(2)
            
            # Set display environment
            os.environ['DISPLAY'] = ':99'
            os.environ['SDL_VIDEODRIVER'] = 'x11'
            os.environ['SDL_AUDIODRIVER'] = 'pulse'
            
            # Start PulseAudio
            subprocess.Popen(['pulseaudio', '--start', '--exit-idle-time=-1'])
            time.sleep(2)
            
            # Start FUSE emulator with high-quality scaling
            self.emulator_process = subprocess.Popen([
                'fuse-sdl',
                '--machine', '48',
                '--graphics-filter', '4x',  # High-quality 4x scaling
                '--full-screen',
                '--sound',
                '--volume', '100'
            ])
            
            logger.info('Emulator started, initializing high-quality streaming...')
            time.sleep(3)
            
            # Start both streaming processes
            self.start_web_stream_1080p()
            self.start_youtube_stream_1080p()
            self.start_s3_upload()
            
        except Exception as e:
            logger.error(f'Failed to start emulator: {e}')

    def start_web_stream_1080p(self):
        """Start high-quality 1080p web streaming"""
        try:
            logger.info(f'Starting HIGH QUALITY web HLS stream: {self.output_resolution}@{self.framerate}fps')
            stream_file = self.stream_dir / 'stream.m3u8'
            
            # High-quality 1080p streaming with proper ZX Spectrum aspect ratio
            self.web_stream_process = subprocess.Popen([
                'ffmpeg', '-y',
                '-f', 'x11grab',
                '-video_size', self.display_size,
                '-framerate', self.framerate,
                '-i', ':99.0+0,0',
                '-f', 'pulse',
                '-i', 'default',
                '-c:v', 'libx264',
                '-preset', 'medium',  # Balanced quality/performance
                '-tune', 'zerolatency',
                '-profile:v', 'high',  # High profile for better compression
                '-level', '4.2',
                '-g', '120',  # Keyframe every 2 seconds at 60fps
                '-keyint_min', '60',
                '-sc_threshold', '0',
                '-b:v', self.video_bitrate,
                '-maxrate', self.max_bitrate,
                '-bufsize', self.buffer_size,
                '-vf', f'scale={self.output_resolution}:flags=lanczos',  # High-quality Lanczos scaling
                '-pix_fmt', 'yuv420p',
                '-c:a', 'aac',
                '-b:a', self.audio_bitrate,
                '-ar', self.audio_sample_rate,
                '-ac', '2',  # Stereo
                '-f', 'hls',
                '-hls_time', '2',
                '-hls_list_size', '5',
                '-hls_flags', 'delete_segments',
                str(stream_file)
            ])
            logger.info(f'HIGH QUALITY web streaming started: {self.output_resolution}@{self.framerate}fps')
            
        except Exception as e:
            logger.error(f'Failed to start high-quality web stream: {e}')

    def start_web_stream_with_test_pattern_1080p(self):
        """Start high-quality 1080p test pattern"""
        try:
            logger.info(f'Starting HIGH QUALITY test pattern: {self.output_resolution}@{self.framerate}fps')
            stream_file = self.stream_dir / 'stream.m3u8'
            
            # High-quality test pattern with ZX Spectrum colors
            self.web_stream_process = subprocess.Popen([
                'ffmpeg', '-y',
                '-f', 'lavfi',
                '-i', f'testsrc2=size={self.output_resolution}:rate={self.framerate}:duration=0',
                '-f', 'lavfi', 
                '-i', 'sine=frequency=1000:duration=0',
                '-c:v', 'libx264',
                '-preset', 'medium',
                '-tune', 'zerolatency',
                '-profile:v', 'high',
                '-level', '4.2',
                '-g', '120',
                '-keyint_min', '60',
                '-sc_threshold', '0',
                '-b:v', self.video_bitrate,
                '-maxrate', self.max_bitrate,
                '-bufsize', self.buffer_size,
                '-pix_fmt', 'yuv420p',
                '-c:a', 'aac',
                '-b:a', self.audio_bitrate,
                '-ar', self.audio_sample_rate,
                '-ac', '2',
                '-f', 'hls',
                '-hls_time', '2',
                '-hls_list_size', '5',
                '-hls_flags', 'delete_segments',
                str(stream_file)
            ])
            logger.info(f'HIGH QUALITY test pattern started: {self.output_resolution}@{self.framerate}fps')
            
        except Exception as e:
            logger.error(f'Failed to start high-quality test pattern: {e}')

    def start_youtube_stream_1080p(self):
        if not self.youtube_key:
            logger.info('No YouTube stream key provided, skipping YouTube streaming')
            return
            
        try:
            logger.info(f'Starting HIGH QUALITY YouTube RTMP stream: {self.output_resolution}@{self.framerate}fps')
            
            # Use test pattern if emulator failed, otherwise use X11 capture
            if self.emulator_process is None:
                # High-quality test pattern for YouTube
                input_args = [
                    '-f', 'lavfi',
                    '-i', f'testsrc2=size={self.output_resolution}:rate={self.framerate}:duration=0',
                    '-f', 'lavfi', 
                    '-i', 'sine=frequency=1000:duration=0'
                ]
            else:
                # High-quality X11 capture for YouTube
                input_args = [
                    '-f', 'x11grab',
                    '-video_size', self.display_size,
                    '-framerate', self.framerate,
                    '-i', ':99.0+0,0',
                    '-f', 'pulse',
                    '-i', 'default'
                ]
            
            # Build high-quality FFmpeg command
            ffmpeg_cmd = ['ffmpeg', '-y'] + input_args
            
            # Add high-quality scaling if capturing from X11
            if self.emulator_process is not None:
                ffmpeg_cmd.extend([
                    '-vf', f'scale={self.output_resolution}:flags=lanczos'  # High-quality Lanczos scaling
                ])
            
            # Add high-quality encoding settings
            ffmpeg_cmd.extend([
                '-c:v', 'libx264',
                '-preset', 'medium',  # Balanced quality/performance
                '-tune', 'zerolatency',
                '-profile:v', 'high',  # High profile for better compression
                '-level', '4.2',
                '-g', '120',  # Keyframe every 2 seconds at 60fps
                '-keyint_min', '60',
                '-sc_threshold', '0',
                '-b:v', self.video_bitrate,  # 6000k for high quality
                '-maxrate', self.max_bitrate,  # 6500k max
                '-bufsize', self.buffer_size,  # 12MB buffer
                '-pix_fmt', 'yuv420p',
                '-c:a', 'aac',
                '-b:a', self.audio_bitrate,  # 192k high-fidelity audio
                '-ar', self.audio_sample_rate,  # 48kHz professional audio
                '-ac', '2',  # Stereo
                '-f', 'flv',
                f'rtmp://a.rtmp.youtube.com/live2/{self.youtube_key}'
            ])
            
            self.youtube_stream_process = subprocess.Popen(ffmpeg_cmd)
            logger.info(f'HIGH QUALITY YouTube streaming started: {self.output_resolution}@{self.framerate}fps, {self.video_bitrate} bitrate')
            
        except Exception as e:
            logger.error(f'Failed to start high-quality YouTube stream: {e}')

    def start_s3_upload(self):
        if not self.s3_client:
            logger.info('S3 client not available, skipping S3 upload')
            return
            
        try:
            logger.info('Starting S3 upload process for HLS segments')
            
            def upload_segments():
                while True:
                    try:
                        # Upload HLS playlist and segments
                        for file_path in self.stream_dir.glob('*'):
                            if file_path.is_file():
                                key = f'hls/{file_path.name}'
                                self.s3_client.upload_file(
                                    str(file_path), 
                                    self.stream_bucket, 
                                    key,
                                    ExtraArgs={'ContentType': 'application/x-mpegURL' if file_path.suffix == '.m3u8' else 'video/MP2T'}
                                )
                        time.sleep(1)
                    except Exception as e:
                        logger.error(f'S3 upload error: {e}')
                        time.sleep(5)
            
            self.s3_upload_process = threading.Thread(target=upload_segments, daemon=True)
            self.s3_upload_process.start()
            logger.info('S3 upload process started')
            
        except Exception as e:
            logger.error(f'Failed to start S3 upload: {e}')

    async def health_check(self, request):
        """Health check endpoint for load balancer"""
        status = {
            'status': 'healthy',
            'emulator_running': self.emulator_process is not None,
            'web_streaming': self.web_stream_process is not None,
            'youtube_streaming': self.youtube_stream_process is not None,
            'quality': 'HIGH_QUALITY_1080p60',
            'resolution': self.output_resolution,
            'framerate': self.framerate,
            'bitrate': self.video_bitrate,
            'connected_clients': len(self.connected_clients),
            'timestamp': time.time()
        }
        return web.json_response(status)

    def cleanup(self):
        """Clean up all processes"""
        logger.info('Cleaning up processes...')
        
        processes = [
            ('emulator', self.emulator_process),
            ('web_stream', self.web_stream_process),
            ('youtube_stream', self.youtube_stream_process)
        ]
        
        for name, process in processes:
            if process:
                try:
                    process.terminate()
                    process.wait(timeout=5)
                    logger.info(f'{name} process terminated')
                except subprocess.TimeoutExpired:
                    process.kill()
                    logger.info(f'{name} process killed')
                except Exception as e:
                    logger.error(f'Error terminating {name}: {e}')

def signal_handler(signum, frame):
    logger.info(f'Received signal {signum}, shutting down...')
    emulator.cleanup()
    exit(0)

async def main():
    global emulator
    emulator = SpectrumEmulator()
    
    # Set up signal handlers
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    # Start HTTP server for health checks
    app = web.Application()
    app.router.add_get('/health', emulator.health_check)
    
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, '0.0.0.0', 8080)
    await site.start()
    logger.info('Health check server started on port 8080')
    
    # Auto-start emulator and streaming
    logger.info('Auto-starting HIGH QUALITY emulator and streaming...')
    await emulator.start_emulator()
    
    # Start WebSocket server
    logger.info('Starting WebSocket server on port 8765...')
    start_server = websockets.serve(emulator.handle_websocket, '0.0.0.0', 8765)
    
    await start_server
    logger.info('HIGH QUALITY ZX Spectrum Emulator server running!')
    logger.info(f'Quality: {emulator.output_resolution}@{emulator.framerate}fps, {emulator.video_bitrate} bitrate')
    
    # Keep the server running
    try:
        await asyncio.Future()  # Run forever
    except KeyboardInterrupt:
        logger.info('Server stopped by user')
    finally:
        emulator.cleanup()

if __name__ == '__main__':
    asyncio.run(main())
