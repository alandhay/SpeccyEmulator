#!/usr/bin/env python3
"""
Comprehensive Local Emulator Validation
=======================================

This script validates all components of the local emulator setup before
proceeding to containerization and ECS deployment.
"""

import asyncio
import subprocess
import requests
import time
import sys
import os
from pathlib import Path

class EmulatorValidator:
    def __init__(self):
        self.base_path = Path(__file__).parent.parent
        self.tests_passed = 0
        self.tests_failed = 0
        self.warnings = 0
        
        # Service URLs
        self.health_url = "http://localhost:8080/health"
        self.web_url = "http://localhost:8000"
        self.websocket_url = "ws://localhost:8765"
        self.stream_url = "http://localhost:8000/stream/hls/stream.m3u8"
    
    def log_test(self, test_name, success, message="", warning=False):
        """Log test result"""
        if warning:
            print(f"⚠️  {test_name}: {message}")
            self.warnings += 1
        elif success:
            print(f"✅ {test_name}: {message}")
            self.tests_passed += 1
        else:
            print(f"❌ {test_name}: {message}")
            self.tests_failed += 1
    
    def check_system_dependencies(self):
        """Check required system dependencies"""
        print("\n🔍 Checking System Dependencies")
        print("-" * 40)
        
        dependencies = {
            'python3': 'Python 3 interpreter',
            'fuse-sdl': 'FUSE ZX Spectrum emulator',
            'ffmpeg': 'Video encoding and streaming',
            'xdotool': 'X11 automation tool'
        }
        
        for dep, description in dependencies.items():
            try:
                result = subprocess.run(['which', dep], capture_output=True, check=True)
                path = result.stdout.decode().strip()
                self.log_test(f"{dep} available", True, f"Found at {path}")
            except subprocess.CalledProcessError:
                self.log_test(f"{dep} available", False, f"Missing: {description}")
    
    def check_x11_display(self):
        """Check X11 display availability"""
        print("\n🖥️  Checking X11 Display")
        print("-" * 40)
        
        if not os.environ.get('DISPLAY'):
            self.log_test("DISPLAY variable", False, "DISPLAY environment variable not set")
            return
        
        display = os.environ['DISPLAY']
        self.log_test("DISPLAY variable", True, f"Set to {display}")
        
        try:
            subprocess.run(['xdpyinfo'], capture_output=True, check=True)
            self.log_test("X11 connection", True, f"Can connect to {display}")
        except subprocess.CalledProcessError:
            self.log_test("X11 connection", False, f"Cannot connect to {display}")
    
    def check_file_structure(self):
        """Check required file structure"""
        print("\n📁 Checking File Structure")
        print("-" * 40)
        
        required_files = [
            'server/local_server.py',
            'server/requirements.txt',
            'server/start_local.sh',
            'web/index.html',
            'web/css/spectrum.css',
            'web/js/spectrum-local.js',
            'test-scripts/test_websocket.py'
        ]
        
        for file_path in required_files:
            full_path = self.base_path / file_path
            exists = full_path.exists()
            self.log_test(f"File {file_path}", exists, 
                         f"Found at {full_path}" if exists else f"Missing: {full_path}")
        
        # Check directories
        required_dirs = ['stream/hls', 'logs']
        for dir_path in required_dirs:
            full_path = self.base_path / dir_path
            exists = full_path.exists()
            if not exists:
                try:
                    full_path.mkdir(parents=True, exist_ok=True)
                    self.log_test(f"Directory {dir_path}", True, f"Created at {full_path}")
                except Exception as e:
                    self.log_test(f"Directory {dir_path}", False, f"Cannot create: {e}")
            else:
                self.log_test(f"Directory {dir_path}", True, f"Exists at {full_path}")
    
    def check_python_dependencies(self):
        """Check Python dependencies"""
        print("\n🐍 Checking Python Dependencies")
        print("-" * 40)
        
        required_packages = ['websockets', 'aiohttp', 'asyncio']
        
        for package in required_packages:
            try:
                __import__(package)
                self.log_test(f"Python package {package}", True, "Available")
            except ImportError:
                self.log_test(f"Python package {package}", False, "Not installed")
    
    def wait_for_service(self, url, timeout=30, service_name="Service"):
        """Wait for a service to become available"""
        print(f"⏳ Waiting for {service_name} at {url}...")
        
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                response = requests.get(url, timeout=5)
                if response.status_code == 200:
                    self.log_test(f"{service_name} availability", True, f"Responding at {url}")
                    return True
            except requests.exceptions.RequestException:
                pass
            
            time.sleep(2)
        
        self.log_test(f"{service_name} availability", False, f"Not responding at {url} after {timeout}s")
        return False
    
    def check_health_endpoint(self):
        """Check health endpoint"""
        print("\n❤️  Checking Health Endpoint")
        print("-" * 40)
        
        if not self.wait_for_service(self.health_url, service_name="Health endpoint"):
            return
        
        try:
            response = requests.get(self.health_url, timeout=10)
            if response.status_code == 200:
                data = response.json()
                self.log_test("Health endpoint response", True, "Valid JSON response")
                
                # Check health data
                status = data.get('status')
                if status == 'healthy':
                    self.log_test("Health status", True, "Server reports healthy")
                else:
                    self.log_test("Health status", False, f"Server reports: {status}")
                
                # Check component status
                emulator_running = data.get('emulator_running', False)
                hls_streaming = data.get('hls_streaming', False)
                youtube_streaming = data.get('youtube_streaming', False)
                websocket_clients = data.get('websocket_clients', 0)
                
                self.log_test("Emulator status", emulator_running, 
                             "Running" if emulator_running else "Not running", 
                             warning=not emulator_running)
                
                self.log_test("HLS streaming", hls_streaming,
                             "Active" if hls_streaming else "Not active",
                             warning=not hls_streaming)
                
                if youtube_streaming:
                    self.log_test("YouTube streaming", True, "Active")
                else:
                    self.log_test("YouTube streaming", True, "Not configured (optional)", warning=True)
                
                self.log_test("WebSocket clients", True, f"{websocket_clients} connected")
                
            else:
                self.log_test("Health endpoint response", False, f"HTTP {response.status_code}")
                
        except Exception as e:
            self.log_test("Health endpoint response", False, f"Error: {e}")
    
    def check_web_interface(self):
        """Check web interface"""
        print("\n🌐 Checking Web Interface")
        print("-" * 40)
        
        if not self.wait_for_service(self.web_url, service_name="Web interface"):
            return
        
        try:
            response = requests.get(self.web_url, timeout=10)
            if response.status_code == 200:
                content = response.text
                if 'ZX Spectrum Emulator' in content:
                    self.log_test("Web interface content", True, "Contains expected title")
                else:
                    self.log_test("Web interface content", False, "Missing expected content")
                
                # Check for required resources
                required_resources = ['css/spectrum.css', 'js/spectrum-local.js']
                for resource in required_resources:
                    resource_url = f"{self.web_url}/{resource}"
                    try:
                        res = requests.get(resource_url, timeout=5)
                        self.log_test(f"Resource {resource}", res.status_code == 200,
                                     "Available" if res.status_code == 200 else f"HTTP {res.status_code}")
                    except Exception as e:
                        self.log_test(f"Resource {resource}", False, f"Error: {e}")
            else:
                self.log_test("Web interface response", False, f"HTTP {response.status_code}")
                
        except Exception as e:
            self.log_test("Web interface response", False, f"Error: {e}")
    
    def check_hls_stream(self):
        """Check HLS stream availability"""
        print("\n📺 Checking HLS Stream")
        print("-" * 40)
        
        # Wait a bit for stream to start
        time.sleep(5)
        
        try:
            response = requests.get(self.stream_url, timeout=10)
            if response.status_code == 200:
                content = response.text
                if '#EXTM3U' in content:
                    self.log_test("HLS manifest", True, "Valid M3U8 format")
                    
                    # Check for segments
                    if '.ts' in content:
                        self.log_test("HLS segments", True, "Segments found in manifest")
                    else:
                        self.log_test("HLS segments", False, "No segments in manifest", warning=True)
                else:
                    self.log_test("HLS manifest", False, "Invalid M3U8 format")
            else:
                self.log_test("HLS stream availability", False, f"HTTP {response.status_code}")
                
        except Exception as e:
            self.log_test("HLS stream availability", False, f"Error: {e}")
    
    async def check_websocket(self):
        """Check WebSocket functionality"""
        print("\n🔌 Checking WebSocket")
        print("-" * 40)
        
        # Run the WebSocket test script
        try:
            test_script = self.base_path / 'test-scripts' / 'test_websocket.py'
            if test_script.exists():
                result = subprocess.run([sys.executable, str(test_script)], 
                                      capture_output=True, text=True, timeout=60)
                
                if result.returncode == 0:
                    self.log_test("WebSocket functionality", True, "All WebSocket tests passed")
                else:
                    self.log_test("WebSocket functionality", False, "Some WebSocket tests failed")
                    print("WebSocket test output:")
                    print(result.stdout)
                    if result.stderr:
                        print("Errors:")
                        print(result.stderr)
            else:
                self.log_test("WebSocket test script", False, f"Test script not found: {test_script}")
                
        except subprocess.TimeoutExpired:
            self.log_test("WebSocket functionality", False, "WebSocket tests timed out")
        except Exception as e:
            self.log_test("WebSocket functionality", False, f"Error running tests: {e}")
    
    def print_summary(self):
        """Print validation summary"""
        print("\n" + "=" * 50)
        print("🧪 VALIDATION SUMMARY")
        print("=" * 50)
        print(f"✅ Tests passed: {self.tests_passed}")
        print(f"❌ Tests failed: {self.tests_failed}")
        print(f"⚠️  Warnings: {self.warnings}")
        
        total_tests = self.tests_passed + self.tests_failed
        if total_tests > 0:
            success_rate = (self.tests_passed / total_tests) * 100
            print(f"📊 Success rate: {success_rate:.1f}%")
        
        print("\n" + "=" * 50)
        
        if self.tests_failed == 0:
            print("🎉 ALL VALIDATIONS PASSED!")
            print("✅ Ready for containerization and ECS deployment")
            return True
        else:
            print("❌ SOME VALIDATIONS FAILED!")
            print("🔧 Please fix the issues before proceeding to deployment")
            return False
    
    async def run_all_validations(self):
        """Run all validation checks"""
        print("🧪 Starting Comprehensive Emulator Validation")
        print("=" * 50)
        
        # Pre-flight checks (don't require server to be running)
        self.check_system_dependencies()
        self.check_x11_display()
        self.check_file_structure()
        self.check_python_dependencies()
        
        # Service checks (require server to be running)
        print("\n⚠️  NOTE: The following tests require the local server to be running.")
        print("   Start the server with: ./server/start_local.sh")
        print("   Then run this validation script in another terminal.")
        
        self.check_health_endpoint()
        self.check_web_interface()
        self.check_hls_stream()
        await self.check_websocket()
        
        return self.print_summary()

async def main():
    """Main validation function"""
    validator = EmulatorValidator()
    success = await validator.run_all_validations()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    asyncio.run(main())
