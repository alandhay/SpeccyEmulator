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
        self.stream_dir = Path('/tmp/stream')
        self.stream_dir.mkdir(exist_ok=True)

    def start_emulator(self):
        try:
            if self.emulator_process:
                logger.info('Emulator already running')
                return True

            logger.info('Starting FUSE ZX Spectrum emulator with centered capture')
            self.emulator_process = subprocess.Popen([
                'fuse-sdl', 
                '--machine', '48', 
                '--graphics-filter', 'none', 
                '--sound', 
                '--no-confirm-actions', 
                '--full-screen'
            ], env={'DISPLAY': ':99'})
            
            time.sleep(5)
            self.start_web_stream()
            logger.info('ZX Spectrum emulator started successfully')
            return True
            
        except Exception as e:
            logger.error(f'Failed to start emulator: {e}')
            self.stop_emulator()
            return False

    def start_web_stream(self):
        try:
            logger.info('Starting web HLS stream with centered capture at +128,96')
            stream_file = self.stream_dir / 'stream.m3u8'
            
            self.web_stream_process = subprocess.Popen([
                'ffmpeg',
                '-f', 'x11grab',
                '-video_size', '256x192',
                '-framerate', '25',
                '-i', ':99.0+128,96',  # Centered capture offset
                '-c:v', 'libx264',
                '-preset', 'ultrafast',
                '-tune', 'zerolatency',
                '-g', '25',
                '-pix_fmt', 'yuv420p',
                '-f', 'hls',
                '-hls_time', '1',
                '-hls_list_size', '3',
                '-hls_flags', 'delete_segments+append_list',
                '-hls_segment_filename', str(self.stream_dir / 'segment_%03d.ts'),
                str(stream_file)
            ])
            
            logger.info('Web HLS streaming started with centered capture')
            return True
            
        except Exception as e:
            logger.error(f'Failed to start web stream: {e}')
            return False

    def stop_emulator(self):
        logger.info('Stopping emulator and streams')
        
        if self.web_stream_process:
            try:
                self.web_stream_process.terminate()
                self.web_stream_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.web_stream_process.kill()
            self.web_stream_process = None

        if self.emulator_process:
            try:
                self.emulator_process.terminate()
                self.emulator_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.emulator_process.kill()
            self.emulator_process = None

        logger.info('All processes stopped')

    async def handle_websocket(self, websocket):
        logger.info('New WebSocket client connected')
        self.connected_clients.add(websocket)
        
        try:
            await websocket.send(json.dumps({
                'type': 'connected',
                'message': 'Connected to ZX Spectrum Emulator Server',
                'emulator_running': self.emulator_process is not None
            }))
            
            async for message in websocket:
                try:
                    data = json.loads(message)
                    await self.handle_message(websocket, data)
                except json.JSONDecodeError:
                    logger.error(f'Invalid JSON received: {message}')
                    
        except websockets.exceptions.ConnectionClosed:
            logger.info('WebSocket client disconnected')
        except Exception as e:
            logger.error(f'WebSocket error: {e}')
        finally:
            self.connected_clients.discard(websocket)

    async def handle_message(self, websocket, data):
        message_type = data.get('type')
        logger.info(f'Received message: {message_type}')

        if message_type == 'start_emulator':
            success = self.start_emulator()
            await websocket.send(json.dumps({
                'type': 'emulator_status',
                'running': success,
                'message': 'Emulator started with centered video' if success else 'Failed to start emulator'
            }))

        elif message_type == 'stop_emulator':
            self.stop_emulator()
            await websocket.send(json.dumps({
                'type': 'emulator_status',
                'running': False,
                'message': 'Emulator stopped'
            }))

        elif message_type == 'key_press':
            key = data.get('key')
            if key:
                logger.info(f'Key pressed: {key}')
                await websocket.send(json.dumps({
                    'type': 'key_response',
                    'key': key,
                    'message': f'Key {key} sent to emulator'
                }))

        elif message_type == 'status':
            await websocket.send(json.dumps({
                'type': 'status_response',
                'emulator_running': self.emulator_process is not None,
                'web_stream_active': self.web_stream_process is not None,
                'connected_clients': len(self.connected_clients)
            }))

        else:
            await websocket.send(json.dumps({
                'type': 'error',
                'message': f'Unknown message type: {message_type}'
            }))

    async def health_check(self, request):
        return web.Response(text='OK', status=200)

    async def serve_stream_file(self, request):
        filename = request.match_info['filename']
        file_path = self.stream_dir / filename
        
        if file_path.exists():
            if filename.endswith('.m3u8'):
                return FileResponse(file_path, headers={
                    'Content-Type': 'application/vnd.apple.mpegurl',
                    'Cache-Control': 'no-cache',
                    'Access-Control-Allow-Origin': '*'
                })
            elif filename.endswith('.ts'):
                return FileResponse(file_path, headers={
                    'Content-Type': 'video/mp2t',
                    'Cache-Control': 'no-cache',
                    'Access-Control-Allow-Origin': '*'
                })
        
        return web.Response(status=404)

    async def start_server(self):
        # Start HTTP server
        app = web.Application()
        app.router.add_get('/health', self.health_check)
        app.router.add_get('/stream/{filename}', self.serve_stream_file)
        
        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, '0.0.0.0', 8080)
        await site.start()
        logger.info('HTTP server started on port 8080')

        # Start WebSocket server
        server = await websockets.serve(self.handle_websocket, '0.0.0.0', 8765)
        logger.info('WebSocket server started on port 8765 - ZX Spectrum Emulator ready with centered video!')

        try:
            await server.wait_closed()
        except KeyboardInterrupt:
            logger.info('Server shutdown requested')
        finally:
            self.cleanup()

    def cleanup(self):
        logger.info('Cleaning up resources')
        self.stop_emulator()

# Create emulator instance
emulator = SpectrumEmulator()

def signal_handler(signum, frame):
    logger.info(f'Received signal {signum}')
    emulator.cleanup()
    exit(0)

# Set up signal handlers
signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)

# Start the server
if __name__ == '__main__':
    asyncio.run(emulator.start_server())
