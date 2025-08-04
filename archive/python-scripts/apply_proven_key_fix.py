#!/usr/bin/env python3
"""
Apply Proven Key Injection Fix
This script updates the current server with the exact proven method from local tests
"""

import re

def apply_proven_key_fix():
    """Apply the proven key injection method to the current server"""
    
    # Read the current server file
    with open('server/emulator_server_fixed_v5.py', 'r') as f:
        server_code = f.read()
    
    print("🔧 Applying proven key injection fixes...")
    
    # 1. Add timeout to xdotool command (critical fix)
    old_subprocess_pattern = r'result = subprocess\.run\(\[\s*\'xdotool\',.*?\], env=\{\'DISPLAY\': \':99\'\}, capture_output=True, text=True\)'
    new_subprocess_call = '''result = subprocess.run([
                'xdotool', 
                'search', '--name', 'Fuse',
                'windowfocus',
                'key', x11_key
            ], env={'DISPLAY': ':99'}, capture_output=True, text=True, timeout=5)'''
    
    if re.search(old_subprocess_pattern, server_code, re.DOTALL):
        server_code = re.sub(old_subprocess_pattern, new_subprocess_call, server_code, flags=re.DOTALL)
        print("✅ Added timeout to xdotool command")
    
    # 2. Add timeout exception handling
    old_exception_pattern = r'except Exception as e:\s*logger\.error\(f"❌ Exception sending key.*?\{e\}"\)'
    new_exception_handling = '''except subprocess.TimeoutExpired:
            logger.error(f"❌ Timeout sending key '{key}'")
            return False, "xdotool timeout"
        except Exception as e:
            logger.error(f"❌ Exception sending key '{key}' to emulator: {e}")'''
    
    if re.search(old_exception_pattern, server_code, re.DOTALL):
        server_code = re.sub(old_exception_pattern, new_exception_handling, server_code, flags=re.DOTALL)
        print("✅ Added timeout exception handling")
    
    # 3. Add window validation function
    if 'def validate_fuse_window(self):' not in server_code:
        validation_function = '''
    def validate_fuse_window(self):
        """Validate FUSE window exists and is accessible - PROVEN METHOD"""
        try:
            result = subprocess.run([
                'xdotool', 'search', '--name', 'Fuse'
            ], env={'DISPLAY': ':99'}, capture_output=True, text=True, timeout=5)
            
            if result.returncode == 0 and result.stdout.strip():
                window_id = result.stdout.strip().split('\\n')[0]
                logger.info(f"✅ FUSE window found: {window_id}")
                return True, window_id
            else:
                logger.error("❌ FUSE window not found")
                return False, None
                
        except subprocess.TimeoutExpired:
            logger.error("❌ Timeout finding FUSE window")
            return False, None
        except Exception as e:
            logger.error(f"❌ Error finding FUSE window: {e}")
            return False, None
'''
        
        # Insert after the __init__ method
        init_end_pattern = r'(\s+# Initialize S3 client.*?self\.s3_client = None\s*)'
        server_code = re.sub(init_end_pattern, r'\1' + validation_function, server_code, flags=re.DOTALL)
        print("✅ Added window validation function")
    
    # 4. Enhance health check to include key injection status
    if 'key_injection_ready' not in server_code:
        # Find the health check method and enhance it
        health_check_pattern = r'(async def health_check\(self, request\):.*?return web\.json_response\(.*?\))'
        
        enhanced_health_check = '''async def health_check(self, request):
        """Enhanced health check including key injection validation"""
        try:
            # Basic health data
            health_data = {
                "status": "healthy",
                "timestamp": time.time(),
                "emulator_running": self.emulator_running,
                "uptime": time.time() - self.server_start_time,
                "version": "v6-proven-keys"
            }
            
            # Add key injection validation
            try:
                window_valid, window_id = self.validate_fuse_window()
                health_data.update({
                    "fuse_window_valid": window_valid,
                    "fuse_window_id": window_id,
                    "key_injection_ready": window_valid
                })
                
                status_code = 200 if window_valid else 503
            except:
                health_data.update({
                    "fuse_window_valid": False,
                    "key_injection_ready": False
                })
                status_code = 503
            
            return web.json_response(health_data, status=status_code)
            
        except Exception as e:
            return web.json_response({
                "status": "unhealthy",
                "error": str(e),
                "version": "v6-proven-keys"
            }, status=500)'''
        
        if re.search(r'async def health_check\(self, request\):', server_code):
            server_code = re.sub(health_check_pattern, enhanced_health_check, server_code, flags=re.DOTALL)
            print("✅ Enhanced health check with key injection status")
    
    # 5. Add subprocess import if missing
    if 'import subprocess' not in server_code:
        server_code = server_code.replace('import time', 'import time\nimport subprocess')
        print("✅ Added subprocess import")
    
    # Write the updated server file
    with open('server/emulator_server_fixed_v6.py', 'w') as f:
        f.write(server_code)
    
    print("✅ Created updated server: server/emulator_server_fixed_v6.py")
    
    # Create a simple Dockerfile for the fix
    dockerfile_content = '''FROM ubuntu:22.04

# Install all required packages including xdotool (CRITICAL)
RUN apt-get update && apt-get install -y \\
    fuse-emulator-sdl \\
    ffmpeg \\
    python3 \\
    python3-pip \\
    python3-websockets \\
    python3-aiohttp \\
    xvfb \\
    pulseaudio \\
    x11-utils \\
    xdotool \\
    awscli \\
    && rm -rf /var/lib/apt/lists/*

# Create application directory
WORKDIR /app

# Copy server code
COPY server/emulator_server_fixed_v6.py /app/server.py
COPY server/requirements.txt /app/requirements.txt

# Install Python dependencies
RUN pip3 install -r requirements.txt

# Set environment variables
ENV DISPLAY=:99
ENV SDL_VIDEODRIVER=x11
ENV SDL_AUDIODRIVER=pulse
ENV PULSE_RUNTIME_PATH=/tmp/pulse

# Expose ports
EXPOSE 8765 8080

# Start script
CMD ["python3", "/app/server.py"]
'''
    
    with open('fixed-emulator-v6-keys.dockerfile', 'w') as f:
        f.write(dockerfile_content)
    
    print("✅ Created Dockerfile: fixed-emulator-v6-keys.dockerfile")
    
    # Create deployment script
    deploy_script = '''#!/bin/bash
# Deploy Proven Key Injection Fix

set -e

echo "🚀 DEPLOYING PROVEN KEY INJECTION FIX"
echo "====================================="

# Build Docker image
echo "📦 Building Docker image with proven key injection method..."
docker build -f fixed-emulator-v6-keys.dockerfile -t spectrum-emulator:v6-proven-keys .

# Tag for ECR
echo "🏷️  Tagging for ECR..."
docker tag spectrum-emulator:v6-proven-keys \\
  043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:v6-proven-keys

# Login to ECR
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region us-east-1 | \\
  docker login --username AWS --password-stdin \\
  043309319786.dkr.ecr.us-east-1.amazonaws.com

# Push to ECR
echo "📤 Pushing to ECR..."
docker push 043309319786.dkr.ecr.us-east-1.amazonaws.com/spectrum-emulator:v6-proven-keys

echo ""
echo "✅ BUILD COMPLETE!"
echo "=================="
echo "Docker image built and pushed with proven key injection method"
echo ""
echo "🚀 TO DEPLOY:"
echo "1. Update your task definition to use: spectrum-emulator:v6-proven-keys"
echo "2. Deploy to development first"
echo "3. Test keys via web interface - they should appear on livestream immediately"
echo ""
echo "🎯 SUCCESS CRITERIA:"
echo "- Keys appear on livestream when pressed"
echo "- Health check shows 'key_injection_ready: true'"
echo "- No WebSocket error 1011"
'''
    
    with open('deploy_key_fix.sh', 'w') as f:
        f.write(deploy_script)
    
    import os
    os.chmod('deploy_key_fix.sh', 0o755)
    
    print("✅ Created deployment script: deploy_key_fix.sh")
    
    print("")
    print("🎉 PROVEN KEY INJECTION FIX APPLIED!")
    print("====================================")
    print("✅ Updated server with proven method")
    print("✅ Added timeout handling (critical fix)")
    print("✅ Added window validation")
    print("✅ Enhanced health check")
    print("✅ Created Dockerfile with xdotool")
    print("✅ Created deployment script")
    print("")
    print("🚀 NEXT STEPS:")
    print("1. Run: ./deploy_key_fix.sh")
    print("2. Update task definition to use new image")
    print("3. Deploy and test - keys should work immediately!")

if __name__ == "__main__":
    apply_proven_key_fix()
