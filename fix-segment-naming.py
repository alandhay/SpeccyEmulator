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
import sys
from aiohttp import web
import aiohttp
import boto3
from botocore.exceptions import ClientError
import glob

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class SpectrumEmulator:
    def __init__(self):
        self.clients = set()
        self.emulator_process = None
        self.streaming_process = None
        self.youtube_process = None
        self.upload_thread = None
        self.control_thread = None
        self.running = False
        self.s3_client = None
        self.bucket_name = os.environ.get('STREAM_BUCKET', 'spectrum-emulator-stream-dev-043309319786')
        self.youtube_key = os.environ.get('YOUTUBE_STREAM_KEY', '')
        
        # Initialize S3 client
        try:
            self.s3_client = boto3.client('s3')
            logger.info(f"S3 client initialized for bucket: {self.bucket_name}")
        except Exception as e:
            logger.error(f"Failed to initialize S3 client: {e}")

    async def register_client(self, websocket):
        self.clients.add(websocket)
        logger.info(f"WebSocket client connected. Total clients: {len(self.clients)}")
        
        # Send current status
        status = {
            "type": "connected",
            "emulator_running": self.running,
            "message": "Connected to ZX Spectrum emulator"
        }
        await websocket.send(json.dumps(status))

    async def unregister_client(self, websocket):
        self.clients.discard(websocket)
        logger.info(f"WebSocket client disconnected. Total clients: {len(self.clients)}")

    async def broadcast_message(self, message):
        if self.clients:
            await asyncio.gather(
                *[client.send(json.dumps(message)) for client in self.clients],
                return_exceptions=True
            )

    def start_emulator(self):
        """Start the FUSE ZX Spectrum emulator with video capture"""
        try:
            logger.info("Starting FUSE ZX Spectrum emulator with interactive control...")
            
            # Start virtual display
            subprocess.run(['Xvfb', ':99', '-screen', '0', '512x384x24'], 
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            time.sleep(1)
            
            # Start PulseAudio
            subprocess.run(['pulseaudio', '--start', '--exit-idle-time=-1'], 
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            time.sleep(1)
            
            # Start FUSE emulator
            self.emulator_process = subprocess.Popen([
                'fuse-sdl', '--display', ':99',
                '--graphics-filter', 'none',
                '--sound', '--sound-device', 'pulse',
                '--no-confirm-actions'
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            time.sleep(3)  # Give emulator time to start
            logger.info("FUSE emulator started successfully")
            
            # Start video streaming
            self.start_streaming()
            
            # Start YouTube streaming if key is provided
            if self.youtube_key:
                self.start_youtube_streaming()
            
            # Start S3 upload thread
            self.start_s3_upload()
            
            # Start FUSE control thread
            self.start_fuse_control()
            
            self.running = True
            logger.info("Video streaming started successfully")
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to start emulator: {e}")
            return False

    def start_streaming(self):
        """Start FFmpeg video capture and HLS streaming with CORRECTED segment naming"""
        try:
            # Ensure stream directory exists
            os.makedirs('/tmp/stream', exist_ok=True)
            
            # FIXED: Use hls_segment_filename to specify the correct naming pattern
            # This matches what the upload process expects: stream0.ts, stream1.ts, etc.
            ffmpeg_cmd = [
                'ffmpeg', '-y',
                '-f', 'x11grab',
                '-video_size', '256x192',
                '-framerate', '25',
                '-i', ':99.0+0,0',
                '-f', 'pulse',
                '-i', 'default',
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
                '-hls_segment_filename', '/tmp/stream/stream%d.ts',  # FIXED: Correct naming pattern
                '/tmp/stream/stream.m3u8'
            ]
            
            logger.info("Starting web HLS stream with capture size 256x192 at offset +0,0")
            self.streaming_process = subprocess.Popen(ffmpeg_cmd, 
                                                    stdout=subprocess.DEVNULL, 
                                                    stderr=subprocess.DEVNULL)
            logger.info("Web HLS streaming started with capture at :99.0+0,0")
            
        except Exception as e:
            logger.error(f"Failed to start streaming: {e}")

    def start_youtube_streaming(self):
        """Start YouTube RTMP streaming"""
        try:
            if not self.youtube_key:
                return
                
            youtube_cmd = [
                'ffmpeg', '-y',
                '-f', 'x11grab',
                '-video_size', '256x192',
                '-framerate', '25',
                '-i', ':99.0+0,0',
                '-f', 'pulse',
                '-i', 'default',
                '-c:v', 'libx264',
                '-preset', 'fast',
                '-tune', 'zerolatency',
                '-pix_fmt', 'yuv420p',
                '-s', '854x480',  # YouTube recommended resolution
                '-c:a', 'aac',
                '-b:a', '128k',
                '-b:v', '1000k',
                '-f', 'flv',
                f'rtmp://a.rtmp.youtube.com/live2/{self.youtube_key}'
            ]
            
            logger.info("Starting YouTube RTMP stream")
            self.youtube_process = subprocess.Popen(youtube_cmd,
                                                  stdout=subprocess.DEVNULL,
                                                  stderr=subprocess.DEVNULL)
            logger.info("YouTube RTMP streaming started")
            
        except Exception as e:
            logger.error(f"Failed to start YouTube streaming: {e}")

    def start_s3_upload(self):
        """Start S3 upload thread for HLS segments"""
        def upload_segments():
            logger.info("S3 upload thread started")
            segment_counter = 0
            
            while self.running or self.streaming_process:
                try:
                    # Look for segment files with the correct naming pattern
                    segment_file = f'/tmp/stream/stream{segment_counter}.ts'
                    
                    if os.path.exists(segment_file):
                        # Upload to S3
                        try:
                            with open(segment_file, 'rb') as f:
                                self.s3_client.put_object(
                                    Bucket=self.bucket_name,
                                    Key=f'hls/stream{segment_counter}.ts',
                                    Body=f.read(),
                                    ContentType='video/mp2t'
                                )
                            logger.info(f"Uploaded stream{segment_counter}.ts to S3")
                        except Exception as e:
                            logger.error(f"Failed to upload stream{segment_counter}.ts: {e}")
                    
                    # Also upload the playlist file
                    playlist_file = '/tmp/stream/stream.m3u8'
                    if os.path.exists(playlist_file):
                        try:
                            with open(playlist_file, 'rb') as f:
                                self.s3_client.put_object(
                                    Bucket=self.bucket_name,
                                    Key='hls/stream.m3u8',
                                    Body=f.read(),
                                    ContentType='application/vnd.apple.mpegurl'
                                )
                        except Exception as e:
                            logger.error(f"Failed to upload playlist: {e}")
                    
                    segment_counter += 1
                    time.sleep(2)  # Check every 2 seconds
                    
                except Exception as e:
                    logger.error(f"Error in upload thread: {e}")
                    time.sleep(1)
        
        self.upload_thread = threading.Thread(target=upload_segments, daemon=True)
        self.upload_thread.start()

    def start_fuse_control(self):
        """Start FUSE control thread"""
        def control_loop():
            logger.info("FUSE control loop started")
            # This thread can be used for additional emulator control
            while self.running:
                time.sleep(1)
        
        self.control_thread = threading.Thread(target=control_loop, daemon=True)
        self.control_thread.start()
        logger.info("FUSE control thread started")

    def send_key_to_emulator(self, key, action):
        """Send key press/release to FUSE emulator"""
        try:
            if not self.running:
                return False
                
            # Map web keys to FUSE key codes
            key_mapping = {
                'SPACE': 'space',
                'ENTER': 'Return',
                'SHIFT': 'Shift_L',
                'SYMBOL': 'Alt_L',
                'A': 'a', 'B': 'b', 'C': 'c', 'D': 'd', 'E': 'e', 'F': 'f',
                'G': 'g', 'H': 'h', 'I': 'i', 'J': 'j', 'K': 'k', 'L': 'l',
                'M': 'm', 'N': 'n', 'O': 'o', 'P': 'p', 'Q': 'q', 'R': 'r',
                'S': 's', 'T': 't', 'U': 'u', 'V': 'v', 'W': 'w', 'X': 'x',
                'Y': 'y', 'Z': 'z',
                '0': '0', '1': '1', '2': '2', '3': '3', '4': '4',
                '5': '5', '6': '6', '7': '7', '8': '8', '9': '9'
            }
            
            fuse_key = key_mapping.get(key, key.lower())
            
            # Use xdotool to send key events to the emulator
            if action == 'press':
                subprocess.run(['xdotool', 'keydown', fuse_key], 
                             env={'DISPLAY': ':99'}, check=False)
            else:  # release
                subprocess.run(['xdotool', 'keyup', fuse_key], 
                             env={'DISPLAY': ':99'}, check=False)
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to send key {key} {action}: {e}")
            return False

    async def handle_message(self, websocket, message):
        """Handle incoming WebSocket messages"""
        try:
            data = json.loads(message)
            message_type = data.get('type')
            
            if message_type == 'start_emulator':
                if not self.running:
                    success = self.start_emulator()
                    response = {
                        "type": "emulator_status",
                        "running": success,
                        "message": "Emulator started successfully" if success else "Failed to start emulator"
                    }
                else:
                    response = {
                        "type": "emulator_status", 
                        "running": True,
                        "message": "Emulator already running"
                    }
                await websocket.send(json.dumps(response))
                
            elif message_type == 'key_press':
                key = data.get('key')
                success = self.send_key_to_emulator(key, 'press')
                logger.info(f"Key press: {key} - {'Success' if success else 'Failed'}")
                
            elif message_type == 'key_release':
                key = data.get('key')
                success = self.send_key_to_emulator(key, 'release')
                logger.info(f"Key release: {key} - {'Success' if success else 'Failed'}")
                
            elif message_type == 'status':
                response = {
                    "type": "emulator_status",
                    "running": self.running,
                    "message": "Emulator is running" if self.running else "Emulator is stopped"
                }
                await websocket.send(json.dumps(response))
                
        except json.JSONDecodeError:
            logger.error("Invalid JSON received")
        except Exception as e:
            logger.error(f"Error handling message: {e}")

    def stop_emulator(self):
        """Stop the emulator and all processes"""
        self.running = False
        
        if self.emulator_process:
            self.emulator_process.terminate()
            self.emulator_process = None
            
        if self.streaming_process:
            self.streaming_process.terminate()
            self.streaming_process = None
            
        if self.youtube_process:
            self.youtube_process.terminate()
            self.youtube_process = None

# Global emulator instance
emulator = SpectrumEmulator()

async def websocket_handler(websocket, path):
    """Handle WebSocket connections"""
    logger.info("connection open")
    await emulator.register_client(websocket)
    
    try:
        async for message in websocket:
            await emulator.handle_message(websocket, message)
    except websockets.exceptions.ConnectionClosed:
        pass
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    finally:
        await emulator.unregister_client(websocket)
        logger.info("connection closed")

async def health_handler(request):
    """Health check endpoint"""
    status = {
        "status": "healthy",
        "emulator_running": emulator.running,
        "timestamp": time.time()
    }
    return web.json_response(status)

async def stream_handler(request):
    """Serve HLS stream files"""
    filename = request.match_info.get('filename', 'stream.m3u8')
    filepath = f'/tmp/stream/{filename}'
    
    if os.path.exists(filepath):
        with open(filepath, 'rb') as f:
            content = f.read()
        
        if filename.endswith('.m3u8'):
            content_type = 'application/vnd.apple.mpegurl'
        elif filename.endswith('.ts'):
            content_type = 'video/mp2t'
        else:
            content_type = 'application/octet-stream'
            
        return web.Response(body=content, content_type=content_type)
    else:
        return web.Response(status=404, text="File not found")

def signal_handler(signum, frame):
    """Handle shutdown signals"""
    logger.info("Received shutdown signal")
    emulator.stop_emulator()
    sys.exit(0)

async def main():
    """Main application entry point"""
    # Set up signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Create HTTP server for health checks and stream serving
    app = web.Application()
    app.router.add_get('/health', health_handler)
    app.router.add_get('/stream/{filename}', stream_handler)
    
    # Start HTTP server
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, '0.0.0.0', 8080)
    await site.start()
    logger.info("HTTP server started on port 8080")
    
    # Start WebSocket server
    websocket_server = websockets.serve(websocket_handler, '0.0.0.0', 8765)
    logger.info("WebSocket server started on port 8765 - Ready for streaming control!")
    
    # Keep the server running
    await asyncio.gather(
        websocket_server,
        asyncio.Event().wait()  # Run forever
    )

if __name__ == "__main__":
    asyncio.run(main())
