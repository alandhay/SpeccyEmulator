// Configuration for ZX Spectrum Emulator
const CONFIG = {
    // WebSocket connection - try CloudFront first, fallback to direct ALB
    WEBSOCKET_URL: 'wss://d112s3ps8xh739.cloudfront.net/ws/',
    WEBSOCKET_FALLBACK_URL: 'ws://spectrum-emulator-alb-dev-1273339161.us-east-1.elb.amazonaws.com/ws/',
    
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
