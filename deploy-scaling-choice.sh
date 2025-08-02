#!/bin/bash

# Deployment script with scaling options

echo "🎮 === ZX Spectrum 1080p Scaling Options === 🎮"
echo ""
echo "Choose your preferred scaling mode:"
echo ""
echo "1. 📺 AUTHENTIC CRT - Scanlines + retro effects (recommended)"
echo "2. 🎯 PIXEL-PERFECT - Clean integer scaling, no effects"
echo "3. 🚀 ULTRA HD - Maximum quality with advanced filtering"
echo ""

read -p "Enter your choice (1-3): " choice

case $choice in
    1)
        echo ""
        echo "📺 Deploying AUTHENTIC CRT streaming..."
        echo "✨ Features: Scanlines, proper aspect ratio, retro feel"
        ./create-crt-streaming.sh
        TASK_TYPE="CRT"
        ;;
    2)
        echo ""
        echo "🎯 Deploying PIXEL-PERFECT streaming..."
        echo "✨ Features: Crisp pixels, no blur, clean scaling"
        ./create-pixel-perfect-streaming.sh
        TASK_TYPE="PIXEL-PERFECT"
        ;;
    3)
        echo ""
        echo "🚀 Deploying ULTRA HD streaming..."
        echo "✨ Features: Maximum quality, advanced filtering"
        ./create-ultra-hd-streaming.sh
        TASK_TYPE="ULTRA HD"
        ;;
    *)
        echo "❌ Invalid choice. Exiting."
        exit 1
        ;;
esac

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Task definition created successfully!"
    echo ""
    echo "🔄 Updating ECS service..."
    
    aws ecs update-service \
        --cluster spectrum-emulator-cluster-dev \
        --service spectrum-youtube-streaming \
        --task-definition spectrum-emulator-streaming \
        --region us-east-1
    
    if [ $? -eq 0 ]; then
        echo "✅ Service update initiated!"
        echo ""
        echo "⏳ Waiting for deployment to complete..."
        
        # Wait for service to stabilize
        aws ecs wait services-stable \
            --cluster spectrum-emulator-cluster-dev \
            --services spectrum-youtube-streaming \
            --region us-east-1
        
        echo ""
        echo "🎉 $TASK_TYPE streaming deployed successfully!"
        echo ""
        echo "🌐 Your stream is available at:"
        echo "   📺 Web Interface: https://d112s3ps8xh739.cloudfront.net"
        echo "   🎮 YouTube Control: https://d112s3ps8xh739.cloudfront.net/youtube-stream-control.html"
        echo "   📱 HLS Stream: https://spectrum-emulator-stream-dev-043309319786.s3.us-east-1.amazonaws.com/hls/stream.m3u8"
        echo ""
        echo "🎮 No more distortion! Enjoy your crisp 1080p ZX Spectrum streaming! ✨"
    else
        echo "❌ Failed to update service"
        exit 1
    fi
else
    echo "❌ Failed to create task definition"
    exit 1
fi
