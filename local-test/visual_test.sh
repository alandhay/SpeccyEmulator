#!/bin/bash
# Visual Test - See the emulator display and test keys manually
set -e

echo "👁️  VISUAL TEST: Interactive ZX Spectrum Emulator"
echo "================================================="
echo "GOAL: See the emulator display and test key input manually"

# Check if we're in a graphical environment
if [ -z "$DISPLAY" ]; then
    echo "❌ No DISPLAY environment variable set"
    echo "   This test requires a graphical environment (X11)"
    echo "   If you're using SSH, try: ssh -X username@hostname"
    exit 1
fi

# Check for required tools
echo "📋 Checking dependencies..."

if ! command -v fuse-sdl &> /dev/null; then
    echo "❌ FUSE emulator not found. Installing..."
    sudo apt-get update && sudo apt-get install -y fuse-emulator-sdl
fi

if ! command -v xdotool &> /dev/null; then
    echo "❌ xdotool not found. Installing..."
    sudo apt-get install -y xdotool
fi

echo "✅ Dependencies checked"

# Clean up any existing FUSE processes
echo "🧹 Cleaning up existing FUSE processes..."
pkill -f "fuse-sdl" 2>/dev/null || true
sleep 2

echo ""
echo "🎮 Starting FUSE Emulator (Visible Window)"
echo "=========================================="
echo "The ZX Spectrum emulator will open in a new window."
echo "You should see the classic ZX Spectrum boot screen."
echo ""

# Start FUSE with visible window
fuse-sdl --machine 48 --graphics-filter none &
FUSE_PID=$!
echo "✅ FUSE emulator started with PID: ${FUSE_PID}"

# Wait for window to appear
echo "⏳ Waiting for FUSE window to appear..."
sleep 5

# Find the FUSE window
FUSE_WINDOW=$(xdotool search --name "Fuse" 2>/dev/null | head -1 || echo "")
if [ -z "$FUSE_WINDOW" ]; then
    echo "❌ FUSE window not found"
    echo "   The emulator may not have started properly"
    kill ${FUSE_PID} 2>/dev/null || true
    exit 1
fi

echo "✅ FUSE window found: ${FUSE_WINDOW}"
echo ""

# Focus the window
xdotool windowfocus ${FUSE_WINDOW}
echo "✅ FUSE window focused"

echo ""
echo "🎯 MANUAL TESTING INSTRUCTIONS"
echo "=============================="
echo "1. You should see a ZX Spectrum emulator window"
echo "2. Try typing on your keyboard - keys should appear on screen"
echo "3. Try these classic ZX Spectrum commands:"
echo "   - Type: LOAD \"\" (should show 'LOAD \"\"')"
echo "   - Press ENTER"
echo "   - Type: 10 PRINT \"HELLO WORLD\""
echo "   - Press ENTER"
echo "   - Type: RUN"
echo "   - Press ENTER"
echo ""
echo "4. If keys don't work, we'll test xdotool injection..."
echo ""

# Wait for user to test manually
echo "Press ENTER when you've finished manual testing..."
read -r

echo ""
echo "🤖 AUTOMATED KEY INJECTION TEST"
echo "==============================="
echo "Now testing automated key injection using xdotool..."
echo "Watch the emulator window for changes!"
echo ""

# Test sequence 1: Simple text
echo "Test 1: Sending 'HELLO' via xdotool..."
xdotool windowfocus ${FUSE_WINDOW}
sleep 1

for char in h e l l o; do
    echo "  Sending: $char"
    xdotool key $char
    sleep 0.5
done

echo "✅ 'HELLO' sequence sent"
sleep 2

# Test sequence 2: ENTER key
echo ""
echo "Test 2: Sending ENTER key..."
xdotool windowfocus ${FUSE_WINDOW}
xdotool key Return
echo "✅ ENTER key sent"
sleep 2

# Test sequence 3: Numbers
echo ""
echo "Test 3: Sending numbers '12345'..."
xdotool windowfocus ${FUSE_WINDOW}
for char in 1 2 3 4 5; do
    echo "  Sending: $char"
    xdotool key $char
    sleep 0.3
done
echo "✅ Number sequence sent"
sleep 2

# Test sequence 4: Space and special keys
echo ""
echo "Test 4: Sending SPACE and special characters..."
xdotool windowfocus ${FUSE_WINDOW}
xdotool key space
sleep 0.5
xdotool key quotedbl  # Quote character
sleep 0.5
xdotool key quotedbl
echo "✅ Special characters sent"

echo ""
echo "🔍 OBSERVATION QUESTIONS"
echo "======================="
echo "Please observe the emulator window and answer:"
echo ""
echo "1. Did manual typing work? (y/n)"
read -r MANUAL_WORKS

echo "2. Did the automated 'HELLO' appear? (y/n)"
read -r AUTO_HELLO_WORKS

echo "3. Did the ENTER key work (new line)? (y/n)"
read -r ENTER_WORKS

echo "4. Did the numbers '12345' appear? (y/n)"
read -r NUMBERS_WORK

echo "5. Did the space and quotes work? (y/n)"
read -r SPECIAL_WORKS

echo ""
echo "📋 TEST RESULTS SUMMARY"
echo "======================"
echo "- Manual keyboard input: $([ "$MANUAL_WORKS" = "y" ] && echo "✅ WORKS" || echo "❌ FAILED")"
echo "- Automated 'HELLO': $([ "$AUTO_HELLO_WORKS" = "y" ] && echo "✅ WORKS" || echo "❌ FAILED")"
echo "- ENTER key: $([ "$ENTER_WORKS" = "y" ] && echo "✅ WORKS" || echo "❌ FAILED")"
echo "- Numbers: $([ "$NUMBERS_WORK" = "y" ] && echo "✅ WORKS" || echo "❌ FAILED")"
echo "- Special chars: $([ "$SPECIAL_WORKS" = "y" ] && echo "✅ WORKS" || echo "❌ FAILED")"

echo ""
echo "🎯 CONCLUSIONS"
echo "============="

if [ "$MANUAL_WORKS" = "y" ] && [ "$AUTO_HELLO_WORKS" = "y" ]; then
    echo "🎉 EXCELLENT: Both manual and automated input work!"
    echo "   - The FUSE emulator is properly configured"
    echo "   - xdotool can successfully inject keys"
    echo "   - Your WebSocket server should work with this setup"
elif [ "$AUTO_HELLO_WORKS" = "y" ]; then
    echo "✅ GOOD: Automated input works (xdotool successful)"
    echo "   - xdotool can inject keys into FUSE"
    echo "   - Manual keyboard may have focus issues"
    echo "   - WebSocket server should work"
elif [ "$MANUAL_WORKS" = "y" ]; then
    echo "⚠️  PARTIAL: Manual works but automated doesn't"
    echo "   - FUSE emulator is working"
    echo "   - xdotool may have window focus issues"
    echo "   - Need to debug xdotool window targeting"
else
    echo "❌ PROBLEM: Neither manual nor automated input works"
    echo "   - Check FUSE emulator configuration"
    echo "   - Check X11 display setup"
    echo "   - May need different emulator or input method"
fi

echo ""
echo "🧹 Cleaning up..."
echo "Press ENTER to close the emulator and exit..."
read -r

kill ${FUSE_PID} 2>/dev/null || true
echo "✅ Test completed"
