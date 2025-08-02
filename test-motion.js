// Test motion by sending key presses to generate activity
const WebSocket = require('ws');

const ws = new WebSocket('wss://d112s3ps8xh739.cloudfront.net/ws/');

ws.on('open', function open() {
    console.log('Connected to streaming server');
    
    // Send some key presses to generate motion/activity
    const keys = ['SPACE', 'ENTER', 'A', 'B', 'C', '1', '2', '3'];
    let keyIndex = 0;
    
    const sendKey = () => {
        if (keyIndex < keys.length) {
            const key = keys[keyIndex];
            console.log(`Sending key: ${key}`);
            
            ws.send(JSON.stringify({
                type: 'key_press',
                key: key
            }));
            
            keyIndex++;
            setTimeout(sendKey, 1000); // Send a key every second
        } else {
            console.log('✅ Motion test complete - this should increase bitrate');
            ws.close();
        }
    };
    
    // Start sending keys after a short delay
    setTimeout(sendKey, 2000);
});

ws.on('message', function message(data) {
    const response = JSON.parse(data);
    console.log('Server response:', response.type, response.message);
});

ws.on('error', function error(err) {
    console.error('WebSocket error:', err);
});

ws.on('close', function close() {
    console.log('WebSocket connection closed');
});
