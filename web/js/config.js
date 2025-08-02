// Configuration for ZX Spectrum Emulator
const CONFIG = {
    // WebSocket connection - using new RTMP-enabled task
    WEBSOCKET_URL: 'ws://54.164.181.209:8765',
    
    // Video stream - live emulator output from S3
    STREAM_URL: 'https://spectrum-emulator-stream-dev-043309319786.s3.us-east-1.amazonaws.com/hls/stream.m3u8',
    
    // Connection settings
    RECONNECT_INTERVAL: 3000,
    MAX_RECONNECT_ATTEMPTS: 10,
    
    // Video settings
    VIDEO_AUTOPLAY: true,
    VIDEO_MUTED: true,
    
    // Debug mode
    DEBUG: true
};

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = CONFIG;
}
