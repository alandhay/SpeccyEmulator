#!/bin/bash
# Environment Check - Verify all dependencies and configuration

echo "🔍 ENVIRONMENT DIAGNOSTIC"
echo "========================"
echo "Checking all dependencies and configuration for local testing..."

echo ""
echo "📺 Display Configuration"
echo "----------------------"
echo "DISPLAY variable: ${DISPLAY:-'Not set'}"
echo "X11 forwarding: $([ -n "$SSH_CLIENT" ] && echo "SSH session detected" || echo "Local session")"

if [ -n "$DISPLAY" ]; then
    if xset q >/dev/null 2>&1; then
        echo "✅ X11 display is accessible"
    else
        echo "❌ X11 display not accessible"
    fi
else
    echo "⚠️  No DISPLAY set - will need Xvfb for headless testing"
fi

echo ""
echo "🐍 Python Environment"
echo "-------------------"
python3 --version
echo "Python path: $(which python3)"

echo ""
echo "📦 Python Packages"
echo "----------------"
for pkg in websockets aiohttp asyncio; do
    if python3 -c "import $pkg" 2>/dev/null; then
        echo "✅ $pkg: Available"
    else
        echo "❌ $pkg: Missing"
    fi
done

echo ""
echo "🛠️  System Tools"
echo "---------------"
for tool in xdotool Xvfb fuse-sdl convert xwd xwud; do
    if command -v $tool >/dev/null 2>&1; then
        echo "✅ $tool: $(which $tool)"
    else
        echo "❌ $tool: Not found"
    fi
done

echo ""
echo "🎮 Emulator Availability"
echo "----------------------"
if command -v fuse-sdl >/dev/null 2>&1; then
    echo "✅ FUSE SDL: $(which fuse-sdl)"
    fuse-sdl --help 2>&1 | head -3
else
    echo "❌ FUSE SDL: Not available"
fi

if [ -f "/home/ubuntu/workspace/SpeccyEmulator/local-test/zesarux/extracted/ZEsarUX-12.0/zesarux" ]; then
    echo "✅ ZEsarUX: Available (local build)"
else
    echo "⚠️  ZEsarUX: Not found (optional)"
fi

echo ""
echo "🔌 Network Ports"
echo "---------------"
for port in 8765 8080 10000; do
    if netstat -ln 2>/dev/null | grep -q ":$port "; then
        echo "⚠️  Port $port: In use"
    else
        echo "✅ Port $port: Available"
    fi
done

echo ""
echo "📁 Project Structure"
echo "------------------"
echo "Current directory: $(pwd)"
echo "Server files:"
if [ -f "/home/ubuntu/workspace/SpeccyEmulator/server/emulator_server_fixed_v5.py" ]; then
    echo "✅ Latest server: emulator_server_fixed_v5.py"
else
    echo "❌ Server file missing"
fi

echo "Test files:"
ls -la /home/ubuntu/workspace/SpeccyEmulator/local-test/*.sh 2>/dev/null | wc -l | xargs echo "  Test scripts:"

echo ""
echo "🔧 Recommended Next Steps"
echo "========================"

missing_tools=()
if ! command -v xdotool >/dev/null 2>&1; then missing_tools+=("xdotool"); fi
if ! command -v Xvfb >/dev/null 2>&1; then missing_tools+=("xvfb"); fi
if ! command -v fuse-sdl >/dev/null 2>&1; then missing_tools+=("fuse-emulator-sdl"); fi
if ! command -v convert >/dev/null 2>&1; then missing_tools+=("imagemagick"); fi

if [ ${#missing_tools[@]} -gt 0 ]; then
    echo "📦 Install missing tools:"
    echo "   sudo apt-get update && sudo apt-get install -y ${missing_tools[*]}"
    echo ""
fi

missing_python=()
for pkg in websockets aiohttp; do
    if ! python3 -c "import $pkg" 2>/dev/null; then
        missing_python+=("$pkg")
    fi
done

if [ ${#missing_python[@]} -gt 0 ]; then
    echo "🐍 Install missing Python packages:"
    echo "   pip3 install ${missing_python[*]}"
    echo ""
fi

if [ -n "$DISPLAY" ] && xset q >/dev/null 2>&1; then
    echo "🎯 Ready for visual testing:"
    echo "   ./local-test/visual_test.sh"
    echo ""
fi

echo "🧪 Ready for integrated testing:"
echo "   ./local-test/integrated_test.sh"
echo ""

echo "📊 Environment check complete!"
