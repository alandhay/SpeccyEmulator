// Trigger high-quality YouTube streaming via WebSocket
const WebSocket = require('ws');

const ws = new WebSocket('wss://d112s3ps8xh739.cloudfront.net/ws/');

ws.on('open', function open() {
    console.log('Connected to high-quality streaming server');
    
    // Send start streaming command
    ws.send(JSON.stringify({
        type: 'start_streaming'
    }));
    
    console.log('Sent start_streaming command for HIGH QUALITY mode');
});

ws.on('message', function message(data) {
    const response = JSON.parse(data);
    console.log('Server response:', response);
    
    if (response.type === 'streaming_started' || response.type === 'already_streaming') {
        console.log('✅ HIGH QUALITY streaming should now be active!');
        ws.close();
    }
});

ws.on('error', function error(err) {
    console.error('WebSocket error:', err);
});

ws.on('close', function close() {
    console.log('WebSocket connection closed');
});
