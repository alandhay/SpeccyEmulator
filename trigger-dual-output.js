// Trigger dual output streaming via WebSocket
const WebSocket = require('ws');

const ws = new WebSocket('wss://d112s3ps8xh739.cloudfront.net/ws/');

ws.on('open', function open() {
    console.log('Connected to dual output streaming server');
    
    // Send start streaming command
    ws.send(JSON.stringify({
        type: 'start_streaming'
    }));
    
    console.log('Sent start_streaming command for DUAL OUTPUT mode');
});

ws.on('message', function message(data) {
    const response = JSON.parse(data);
    console.log('Server response:', response);
    
    if (response.type === 'streaming_started' || response.type === 'already_streaming') {
        console.log('✅ DUAL OUTPUT streaming should now be active!');
        console.log('📺 YouTube: Live stream continues');
        console.log('🌐 S3 HLS: Will update with same content');
        ws.close();
    }
});

ws.on('error', function error(err) {
    console.error('WebSocket error:', err);
});

ws.on('close', function close() {
    console.log('WebSocket connection closed');
});
