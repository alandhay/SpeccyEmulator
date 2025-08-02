#!/bin/bash

# ZX Spectrum YouTube Stream Stopper
# This script stops the ZX Spectrum emulator streaming

set -e

echo "🛑 ZX Spectrum YouTube Stream Stopper"
echo "====================================="

# Configuration
CLUSTER_NAME="spectrum-emulator-cluster-dev"
SERVICE_NAME="spectrum-emulator-streaming-service"
REGION="us-east-1"

echo "📋 Configuration:"
echo "   Cluster: $CLUSTER_NAME"
echo "   Service: $SERVICE_NAME"
echo "   Region: $REGION"
echo ""

# Create WebSocket client to stop streaming
cat > /tmp/stop_stream.py << 'EOF'
import asyncio
import websockets
import json

async def stop_streaming():
    uri = "wss://d112s3ps8xh739.cloudfront.net/ws/"
    
    try:
        print("🔌 Connecting to WebSocket server...")
        async with websockets.connect(uri) as websocket:
            print("✅ Connected!")
            
            # Wait for connection message
            response = await websocket.recv()
            data = json.loads(response)
            print(f"📨 Server: {data.get('message', 'Connected')}")
            
            # Send stop streaming command
            print("🛑 Sending stop streaming command...")
            await websocket.send(json.dumps({
                "type": "stop_streaming"
            }))
            
            # Wait for response
            response = await websocket.recv()
            data = json.loads(response)
            print(f"📺 Response: {data.get('message', 'Stream stopped')}")
            
            if data.get('type') == 'streaming_stopped':
                print("✅ SUCCESS: YouTube streaming stopped!")
                return True
            else:
                print(f"⚠️  Unexpected response: {data}")
                return False
                
    except Exception as e:
        print(f"❌ WebSocket connection failed: {e}")
        return False

if __name__ == "__main__":
    result = asyncio.run(stop_streaming())
    exit(0 if result else 1)
EOF

# Try to stop streaming
if python3 /tmp/stop_stream.py 2>/dev/null; then
    echo ""
    echo "✅ STREAM STOPPED SUCCESSFULLY!"
    echo ""
    echo "📺 Your YouTube stream has been stopped"
    echo "   The ZX Spectrum emulator is no longer streaming"
    echo ""
else
    echo ""
    echo "⚠️  Automatic stop failed. Manual options:"
    echo ""
    echo "🌐 Use the web interface:"
    echo "   https://d112s3ps8xh739.cloudfront.net/youtube-stream-control.html"
    echo "   Click 'Connect to Server' then '⏹️ Stop Stream'"
    echo ""
    echo "🔧 Or scale down the ECS service:"
    echo "   aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --desired-count 0 --region $REGION"
    echo ""
fi

echo "📊 Check service status:"
echo "   aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION"
echo ""
