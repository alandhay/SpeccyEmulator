// AWS Configuration - Direct ALB for WebSocket, CloudFront for static content
window.AWS_CONFIG = {
    cloudfront_domain: 'https://d112s3ps8xh739.cloudfront.net',
    websocket_url: 'ws://spectrum-emulator-alb-dev-1273339161.us-east-1.elb.amazonaws.com/ws/',
    api_base_url: 'https://d112s3ps8xh739.cloudfront.net/api',
    stream_base_url: 'https://d112s3ps8xh739.cloudfront.net/stream',
    environment: 'dev'
};
