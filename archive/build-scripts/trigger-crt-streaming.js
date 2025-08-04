#!/usr/bin/env node

// Trigger CRT-style streaming via WebSocket

const WebSocket = require('ws');

const WEBSOCKET_URL = 'wss://d112s3ps8xh739.cloudfront.net/ws/';

console.log('📺 === ZX Spectrum AUTHENTIC CRT 1080p Streaming Trigger === 📺');
console.log('');
console.log('🎬 Connecting to CRT streaming server...');
console.log(`🔗 WebSocket URL: ${WEBSOCKET_URL}`);

const ws = new WebSocket(WEBSOCKET_URL);

ws.on('open', function open() {
    console.log('✅ Connected to CRT streaming server!');
    console.log('');
    
    // Send start streaming command
    console.log('📺 Sending AUTHENTIC CRT streaming start command...');
    ws.send(JSON.stringify({
        type: 'start_streaming',
        mode: 'CRT',
        resolution: '1920x1080',
        effects: ['scanlines', 'proper_aspect_ratio', 'crt_styling']
    }));
    
    // Request status after a moment
    setTimeout(() => {
        console.log('📊 Requesting CRT stream status...');
        ws.send(JSON.stringify({
            type: 'status'
        }));
    }, 2000);
    
    // Close connection after 10 seconds
    setTimeout(() => {
        console.log('');
        console.log('🎉 AUTHENTIC CRT streaming command sent successfully!');
        console.log('📺 Your ZX Spectrum emulator should now be streaming with:');
        console.log('   ✨ Authentic CRT scanlines');
        console.log('   📐 Proper 4:3 aspect ratio (no distortion!)');
        console.log('   🎯 Pixel-perfect integer scaling');
        console.log('   📺 1080p output with retro feel');
        console.log('');
        console.log('🌐 Check your stream at:');
        console.log('   📺 YouTube: Check your YouTube Live dashboard');
        console.log('   🌐 Web: https://d112s3ps8xh739.cloudfront.net');
        console.log('   📱 HLS: https://spectrum-emulator-stream-dev-043309319786.s3.us-east-1.amazonaws.com/hls/stream.m3u8');
        console.log('');
        console.log('🎮 No more distortion - just authentic 80s CRT goodness! ✨');
        ws.close();
        process.exit(0);
    }, 10000);
});

ws.on('message', function message(data) {
    try {
        const msg = JSON.parse(data);
        console.log('📨 Server Response:', msg.type);
        
        if (msg.message) {
            console.log('💬 Message:', msg.message);
        }
        
        if (msg.crt_mode) {
            console.log('📺 CRT Mode:', msg.crt_mode);
        }
        
        if (msg.effects) {
            console.log('✨ Effects:', msg.effects.join(', '));
        }
        
        if (msg.resolution_chain) {
            console.log('📐 Resolution Chain:', msg.resolution_chain);
        }
        
        console.log('');
    } catch (e) {
        console.log('📨 Raw message:', data.toString());
    }
});

ws.on('error', function error(err) {
    console.error('❌ WebSocket error:', err.message);
    console.log('');
    console.log('🔧 Troubleshooting:');
    console.log('   1. Check if the ECS service is running');
    console.log('   2. Verify the new CRT task definition is deployed');
    console.log('   3. Ensure the WebSocket endpoint is accessible');
    console.log('');
    console.log('📊 Check service status:');
    console.log('   aws ecs describe-services --cluster spectrum-emulator-cluster-dev --services spectrum-youtube-streaming');
    process.exit(1);
});

ws.on('close', function close() {
    console.log('🔌 WebSocket connection closed');
});
