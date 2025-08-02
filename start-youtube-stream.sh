#!/bin/bash

# ZX Spectrum YouTube Stream Starter
# This script starts the ZX Spectrum emulator streaming to YouTube

set -e

echo "🎮 ZX Spectrum YouTube Stream Starter"
echo "======================================"

# Configuration
CLUSTER_NAME="spectrum-emulator-cluster-dev"
SERVICE_NAME="spectrum-emulator-streaming-service"
REGION="us-east-1"
CLOUDFRONT_URL="https://d112s3ps8xh739.cloudfront.net"
CONTROL_PAGE="$CLOUDFRONT_URL/youtube-stream-control.html"

echo "📋 Configuration:"
echo "   Cluster: $CLUSTER_NAME"
echo "   Service: $SERVICE_NAME"
echo "   Region: $REGION"
echo "   YouTube Key: 0ebh-efdh-9qtq-2eq3-e6hz"
echo ""

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install AWS CLI first."
    exit 1
fi

# Check ECS service status
echo "🔍 Checking ECS service status..."
SERVICE_STATUS=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$REGION" \
    --query 'services[0].status' \
    --output text 2>/dev/null || echo "ERROR")

if [ "$SERVICE_STATUS" != "ACTIVE" ]; then
    echo "❌ ECS service is not active. Status: $SERVICE_STATUS"
    echo "   Please check your AWS infrastructure."
    exit 1
fi

# Check running count
RUNNING_COUNT=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$REGION" \
    --query 'services[0].runningCount' \
    --output text)

echo "✅ ECS service is active with $RUNNING_COUNT running tasks"

# Wait for service to be ready
echo "⏳ Waiting for service to be ready..."
aws ecs wait services-stable \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$REGION"

echo "✅ Service is stable and ready"

# Test the streaming server
echo "🔗 Testing streaming server connection..."
ALB_DNS=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$REGION" \
    --query 'services[0].loadBalancers[0].targetGroupArn' \
    --output text | xargs aws elbv2 describe-target-groups \
    --target-group-arns \
    --region "$REGION" \
    --query 'TargetGroups[0].LoadBalancerArns[0]' \
    --output text | xargs aws elbv2 describe-load-balancers \
    --load-balancer-arns \
    --region "$REGION" \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

echo "   ALB DNS: $ALB_DNS"

# Test health endpoint
if curl -s -f "http://$ALB_DNS/health" > /dev/null; then
    echo "✅ Streaming server is healthy"
else
    echo "⚠️  Health check failed, but continuing..."
fi

# Start the streaming via WebSocket
echo ""
echo "🚀 Starting YouTube Stream..."
echo "   This will send a WebSocket command to start the emulator"

# Create a simple WebSocket client script
cat > /tmp/start_stream.py << 'EOF'
import asyncio
import websockets
import json
import sys

async def start_streaming():
    uri = "wss://d112s3ps8xh739.cloudfront.net/ws/"
    
    try:
        print("🔌 Connecting to WebSocket server...")
        async with websockets.connect(uri) as websocket:
            print("✅ Connected!")
            
            # Wait for connection message
            response = await websocket.recv()
            data = json.loads(response)
            print(f"📨 Server: {data.get('message', 'Connected')}")
            
            # Send start streaming command
            print("🚀 Sending start streaming command...")
            await websocket.send(json.dumps({
                "type": "start_streaming"
            }))
            
            # Wait for response
            response = await websocket.recv()
            data = json.loads(response)
            print(f"📺 Response: {data.get('message', 'Stream started')}")
            
            if data.get('type') == 'streaming_started':
                print("🎉 SUCCESS: ZX Spectrum is now streaming to YouTube!")
                return True
            else:
                print(f"⚠️  Unexpected response: {data}")
                return False
                
    except Exception as e:
        print(f"❌ WebSocket connection failed: {e}")
        print("   You can manually start the stream using the web interface:")
        print(f"   {sys.argv[1] if len(sys.argv) > 1 else 'CONTROL_URL'}")
        return False

if __name__ == "__main__":
    result = asyncio.run(start_streaming())
    sys.exit(0 if result else 1)
EOF

# Try to start streaming programmatically
if python3 /tmp/start_stream.py "$CONTROL_PAGE" 2>/dev/null; then
    echo ""
    echo "🎉 STREAM STARTED SUCCESSFULLY!"
    echo ""
    echo "📺 Your ZX Spectrum emulator is now streaming to YouTube!"
    echo "   YouTube Stream Key: 0ebh-efdh-9qtq-2eq3-e6hz"
    echo "   Check your YouTube Live dashboard to see the stream"
    echo ""
    echo "🎮 Control Options:"
    echo "   Web Interface: $CONTROL_PAGE"
    echo "   Direct WebSocket: wss://d112s3ps8xh739.cloudfront.net/ws/"
    echo ""
    echo "📊 Monitor the stream:"
    echo "   aws logs tail \"/ecs/spectrum-emulator-streaming\" --follow --region us-east-1"
    echo ""
else
    echo ""
    echo "⚠️  Automatic start failed, but you can start manually:"
    echo ""
    echo "🌐 Open this URL in your browser:"
    echo "   $CONTROL_PAGE"
    echo ""
    echo "📋 Manual Steps:"
    echo "   1. Click 'Connect to Server'"
    echo "   2. Click '🚀 Start YouTube Stream'"
    echo "   3. Check your YouTube Live dashboard"
    echo ""
fi

echo "🔧 Troubleshooting:"
echo "   Check logs: aws logs tail \"/ecs/spectrum-emulator-streaming\" --follow --region us-east-1"
echo "   Check service: aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION"
echo ""
echo "🛑 To stop the stream:"
echo "   ./stop-youtube-stream.sh"
echo ""
