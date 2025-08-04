#!/bin/bash

# Create high-quality YouTube streaming task definition

cat > /tmp/hq-streaming-task.json << 'EOF'
{
  "family": "spectrum-emulator-streaming",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "2048",
  "memory": "4096",
  "executionRoleArn": "arn:aws:iam::043309319786:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "spectrum-emulator-streamer",
      "image": "ubuntu:22.04",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        },
        {
          "containerPort": 8765,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "YOUTUBE_RTMP_KEY",
          "value": "0ebh-efdh-9qtq-2eq3-e6hz"
        },
        {
          "name": "TWITCH_RTMP_KEY",
          "value": "DISABLED"
        },
        {
          "name": "DISPLAY",
          "value": ":99"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/spectrum-emulator-streaming",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:8080/health || exit 1"
        ],
        "interval": 30,
        "timeout": 10,
        "retries": 5,
        "startPeriod": 300
      },
      "command": [
        "bash",
        "-c",
        "#!/bin/bash\nset -e\n\necho 'Starting ZX Spectrum HIGH QUALITY YouTube Streaming Setup...'\n\n# Update and install dependencies\napt-get update\napt-get install -y \\\n  python3 python3-pip curl \\\n  xvfb pulseaudio \\\n  ffmpeg \\\n  fuse-emulator-sdl \\\n  wget unzip\n\necho 'Installing Python dependencies...'\npip3 install websockets aiohttp\n\n# Create directories\nmkdir -p /tmp/games /tmp/logs\n\necho 'Downloading test game...'\nwget -O /tmp/games/manic_miner.tzx 'https://archive.org/download/World_of_Spectrum_June_2017_Mirror/World%20of%20Spectrum%20June%202017%20Mirror.zip/World%20of%20Spectrum%20June%202017%20Mirror%2Fgames%2Fm%2FManicMiner.tzx' || echo 'Game download failed, will use built-in ROM'\n\necho 'Starting HIGH RESOLUTION virtual display...'\n# Create 1920x1080 virtual display for crisp streaming\nXvfb :99 -screen 0 1920x1080x24 &\nexport DISPLAY=:99\n\necho 'Starting PulseAudio...'\npulseaudio --start --exit-idle-time=-1\n\n# Create HIGH QUALITY streaming script\ncat > /tmp/start_streaming.sh << 'STREAM_EOF'\n#!/bin/bash\n\necho \"=== ZX Spectrum HIGH QUALITY YouTube Streaming ===\"\necho \"YouTube Key: ${YOUTUBE_RTMP_KEY:0:10}...\"\necho \"Target Resolution: 1920x1080 @ 6Mbps\"\n\n# Function to start FUSE emulator with high-quality scaling\nstart_emulator() {\n    echo \"Starting ZX Spectrum emulator in HIGH QUALITY mode...\"\n    # Start FUSE with maximum scaling and filtering for crisp image\n    fuse --machine 48 --graphics-filter 4x --full-screen &\n    FUSE_PID=$!\n    echo \"FUSE started with PID: $FUSE_PID (4x scaling for HD quality)\"\n    sleep 5\n}\n\n# Function to start HIGH QUALITY FFmpeg streaming to YouTube\nstart_youtube_stream() {\n    local rtmp_key=$1\n    \n    if [ -z \"$rtmp_key\" ] || [ \"$rtmp_key\" = \"YOUR_YOUTUBE_STREAM_KEY\" ]; then\n        echo \"ERROR: No valid YouTube stream key provided!\"\n        return 1\n    fi\n    \n    RTMP_URL=\"rtmp://a.rtmp.youtube.com/live2/$rtmp_key\"\n    \n    echo \"Starting HIGH QUALITY FFmpeg stream to YouTube...\"\n    echo \"Resolution: 1920x1080 @ 60fps\"\n    echo \"Video Bitrate: 6000k (6 Mbps)\"\n    echo \"Audio Bitrate: 192k (High Quality)\"\n    echo \"RTMP URL: rtmp://a.rtmp.youtube.com/live2/[KEY]\"\n    \n    # HIGH QUALITY streaming settings\n    ffmpeg -f x11grab -video_size 1920x1080 -framerate 60 -i :99 \\\n           -f pulse -i default \\\n           -c:v libx264 -preset medium -tune zerolatency \\\n           -b:v 6000k -maxrate 6500k -bufsize 12000k \\\n           -vf \"scale=1920:1080:flags=lanczos\" \\\n           -pix_fmt yuv420p -g 120 -keyint_min 60 \\\n           -profile:v high -level 4.2 \\\n           -c:a aac -b:a 192k -ar 48000 -ac 2 \\\n           -f flv \"$RTMP_URL\" &\n    FFMPEG_PID=$!\n    echo \"HIGH QUALITY FFmpeg started with PID: $FFMPEG_PID - Streaming to YouTube in 1080p!\"\n}\n\n# Start emulator\nstart_emulator\n\n# Start YouTube streaming if key is provided\nif [ ! -z \"$YOUTUBE_RTMP_KEY\" ] && [ \"$YOUTUBE_RTMP_KEY\" != \"YOUR_YOUTUBE_STREAM_KEY\" ] && [ \"$YOUTUBE_RTMP_KEY\" != \"DISABLED\" ]; then\n    echo \"Starting HIGH QUALITY YouTube stream with key: ${YOUTUBE_RTMP_KEY:0:10}...\"\n    start_youtube_stream \"$YOUTUBE_RTMP_KEY\"\nelse\n    echo \"YouTube streaming disabled or no key provided\"\nfi\n\n# Keep script running and monitor processes\necho \"HIGH QUALITY streaming setup complete. Monitoring processes...\"\nwhile true; do\n    sleep 30\n    \n    # Check if FUSE is still running\n    if ! kill -0 $FUSE_PID 2>/dev/null; then\n        echo \"FUSE emulator stopped, restarting...\"\n        start_emulator\n    fi\n    \n    # Check if FFmpeg is still running (if it was started)\n    if [ ! -z \"$FFMPEG_PID\" ] && ! kill -0 $FFMPEG_PID 2>/dev/null; then\n        echo \"FFmpeg stopped, restarting HIGH QUALITY YouTube stream...\"\n        start_youtube_stream \"$YOUTUBE_RTMP_KEY\"\n    fi\ndone\nSTREAM_EOF\n\nchmod +x /tmp/start_streaming.sh\n\n# Create WebSocket server for remote control\ncat > /tmp/emulator_server.py << 'EOF'\nimport asyncio\nimport websockets\nimport json\nimport logging\nimport subprocess\nimport os\nfrom aiohttp import web\n\nlogging.basicConfig(level=logging.INFO)\nlogger = logging.getLogger(__name__)\n\nclass EmulatorServer:\n    def __init__(self):\n        self.clients = set()\n        self.emulator_process = None\n        self.streaming_process = None\n    \n    async def health(self, request):\n        youtube_key = os.environ.get('YOUTUBE_RTMP_KEY', 'Not set')\n        return web.Response(text=f'ZX Spectrum HIGH QUALITY YouTube Streaming Server OK - Key: {youtube_key[:10]}...')\n    \n    async def status(self, request):\n        youtube_key = os.environ.get('YOUTUBE_RTMP_KEY', 'Not set')\n        status = {\n            'emulator_running': self.streaming_process is not None,\n            'streaming_active': self.streaming_process is not None,\n            'display': os.environ.get('DISPLAY', 'Not set'),\n            'youtube_key_configured': youtube_key != 'YOUR_YOUTUBE_STREAM_KEY' and youtube_key != 'Not set',\n            'youtube_key_preview': youtube_key[:10] + '...' if len(youtube_key) > 10 else youtube_key,\n            'quality': 'HIGH QUALITY - 1920x1080 @ 6Mbps',\n            'resolution': '1920x1080',\n            'bitrate': '6000k'\n        }\n        return web.json_response(status)\n    \n    async def websocket_handler(self, websocket):\n        logger.info('Client connected for HIGH QUALITY YouTube streaming control')\n        self.clients.add(websocket)\n        try:\n            youtube_key = os.environ.get('YOUTUBE_RTMP_KEY', 'Not set')\n            await websocket.send(json.dumps({\n                'type': 'connected',\n                'message': 'ZX Spectrum HIGH QUALITY YouTube Streaming Server Ready! 🎬',\n                'streaming_to': 'YouTube Live',\n                'quality': '1920x1080 @ 6Mbps',\n                'youtube_configured': youtube_key != 'YOUR_YOUTUBE_STREAM_KEY',\n                'youtube_key_preview': youtube_key[:10] + '...' if len(youtube_key) > 10 else youtube_key\n            }))\n            \n            async for message in websocket:\n                try:\n                    data = json.loads(message)\n                    await self.handle_message(websocket, data)\n                except json.JSONDecodeError:\n                    await websocket.send(json.dumps({\n                        'type': 'error',\n                        'message': 'Invalid JSON message'\n                    }))\n        except Exception as e:\n            logger.error(f'WebSocket error: {e}')\n        finally:\n            self.clients.discard(websocket)\n    \n    async def handle_message(self, websocket, data):\n        msg_type = data.get('type')\n        \n        if msg_type == 'start_streaming':\n            if not self.streaming_process:\n                logger.info('Starting HIGH QUALITY YouTube streaming process...')\n                self.streaming_process = subprocess.Popen(['/tmp/start_streaming.sh'])\n                await websocket.send(json.dumps({\n                    'type': 'streaming_started',\n                    'message': 'ZX Spectrum emulator started - now streaming to YouTube Live in HIGH QUALITY 1080p! 🔴✨'\n                }))\n            else:\n                await websocket.send(json.dumps({\n                    'type': 'already_streaming',\n                    'message': 'HIGH QUALITY YouTube streaming already active'\n                }))\n        \n        elif msg_type == 'stop_streaming':\n            if self.streaming_process:\n                self.streaming_process.terminate()\n                self.streaming_process = None\n                await websocket.send(json.dumps({\n                    'type': 'streaming_stopped',\n                    'message': 'HIGH QUALITY YouTube streaming stopped'\n                }))\n        \n        elif msg_type == 'status':\n            await websocket.send(json.dumps({\n                'type': 'status_response',\n                'emulator_running': self.streaming_process is not None,\n                'streaming_to': 'YouTube Live',\n                'quality': '1920x1080 @ 6Mbps',\n                'message': 'HIGH QUALITY Status updated'\n            }))\n        \n        else:\n            await websocket.send(json.dumps({\n                'type': 'unknown_command',\n                'message': f'Unknown command: {msg_type}'\n            }))\n    \n    async def start(self):\n        # Start HTTP server\n        app = web.Application()\n        app.router.add_get('/health', self.health)\n        app.router.add_get('/status', self.status)\n        runner = web.AppRunner(app)\n        await runner.setup()\n        site = web.TCPSite(runner, '0.0.0.0', 8080)\n        await site.start()\n        logger.info('HTTP server started on port 8080')\n        \n        # Start WebSocket server\n        server = await websockets.serve(self.websocket_handler, '0.0.0.0', 8765)\n        logger.info('WebSocket server started on port 8765 - Ready for HIGH QUALITY YouTube streaming!')\n        await server.wait_closed()\n\nif __name__ == '__main__':\n    server = EmulatorServer()\n    asyncio.run(server.start())\nEOF\n\necho 'Starting HIGH QUALITY YouTube Streaming Server...'\npython3 /tmp/emulator_server.py\n"
      ]
    }
  ]
}
EOF

echo "High-quality streaming task definition created!"
echo "Key improvements:"
echo "- Resolution: 1920x1080 (Full HD)"
echo "- Frame rate: 60 FPS"
echo "- Video bitrate: 6000k (6 Mbps)"
echo "- Audio bitrate: 192k (High Quality)"
echo "- Better scaling with Lanczos filter"
echo "- H.264 High Profile for better compression"

# Register the new task definition
echo "Registering high-quality task definition..."
aws ecs register-task-definition --cli-input-json file:///tmp/hq-streaming-task.json --region us-east-1
